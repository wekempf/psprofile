#Requires -PSEdition Core

<#PSScriptInfo

.VERSION 0.2.0

.GUID dbd31207-825d-4cdc-8e52-7c575e0ca5d9

.AUTHOR William E. Kempf

.COMPANYNAME

.COPYRIGHT Copyright (c) 2023 William E. Kempf. All rights reserved.

.TAGS InvokeBuild shell dependencies

.LICENSEURI https://github.com/wekempf/PSubShell/blob/main/LICENSE

.PROJECTURI https://github.com/wekempf/PSubShell/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#> 



<# 

.DESCRIPTION 
 Creates a sub shell configured to use locally installed scripts, modules and packages. 

#> 
[CmdletBinding(DefaultParameterSetName = 'EnterShell')]
Param(
    [Parameter(ParameterSetName = 'EnterShell', Position = 0)]
    [object]$Command,

    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$Initialize,

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoProfile,

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoExit,

    [Parameter(ParameterSetName = 'Update')]
    [switch]$Update,

    [Parameter(ParameterSetName = 'AddModule')]
    [switch]$AddModule,

    [Parameter(ParameterSetName = 'RemoveModule')]
    [switch]$RemoveModule,

    [Parameter(ParameterSetName = 'AddScript')]
    [switch]$AddScript,

    [Parameter(ParameterSetName = 'RemoveScript')]
    [switch]$RemoveScript,

    [Parameter(ParameterSetName = 'AddPackage')]
    [switch]$AddPackage,

    [Parameter(ParameterSetName = 'RemovePackage')]
    [switch]$RemovePackage,

    [Parameter(ParameterSetName = 'AddModule', Position = 1, Mandatory)]
    [Parameter(ParameterSetName = 'RemoveModule', Position = 1, Mandatory)]
    [Parameter(ParameterSetName = 'AddScript', Position = 1, Mandatory)]
    [Parameter(ParameterSetName = 'RemoveScript', Position = 1, Mandatory)]
    [Parameter(ParameterSetName = 'AddPackage', Position = 1, Mandatory)]
    [Parameter(ParameterSetName = 'RemovePackage', Position = 1, Mandatory)]
    [string]$Name,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddScript')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [string]$MinimumVersion,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddScript')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [string]$MaximumVersion,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddScript')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [string]$RequiredVersion,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddScript')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [string[]]$Repository,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [Parameter(ParameterSetName = 'AddScript')]
    [switch]$AllowPrerelease,

    [Parameter(ParameterSetName = 'AddModule')]
    [Parameter(ParameterSetName = 'AddScript')]
    [Parameter(ParameterSetName = 'AddPackage')]
    [switch]$AcceptLicense,

    [Parameter(ParameterSetName = 'CreateBuildScript')]
    [switch]$CreateBuildScript,

    [Parameter(ParameterSetName = 'CreateBuildScript', Position = 1)]
    [string]$Path = (Join-Path $PSScriptRoot 'build.ps1'),

    [Parameter(ParameterSetName = 'CreateBuildScript')]
    [switch]$Force
)

$PSubShellPath = Join-Path $PSScriptRoot '.psubshell'
$PSubShellLockFile = Join-Path $PSScriptRoot '.psubshell.lock.json'
if (Test-Path $PSubShellLockFile) {
    $PSubShellVersions = Get-Content $PSubShellLockFile -ErrorAction SilentlyContinue |
        ConvertFrom-Json -AsHashtable
}
else {
    $PSubShellVersions = @{}
}

function *GetParameters([hashtable]$Given, [string[]]$Include, [string[]]$Exclude) {
    $parms = @{}
    foreach ($kv in $Given.GetEnumerator()) {
        if ((-not $Include) -or ($Include -contains $kv.Key)) {
            if ((-not $Exclude) -or (-not ($Exclude -contains $kv.Key))) {
                $parms.Add($kv.Key, $kv.Value)
            }
        }
    }
    $parms
}

switch ($PSCmdlet.ParameterSetName) {
    'EnterShell' {
        if ($PSubShellInstance -eq $PSubShellPath) {
            Write-Error 'Cannot enter PSubShell from within PSubShell.'
            return
        }
        $pssubshellscript = Join-Path ([IO.Path]::GetTempPath()) ((Get-Item .).Name + '.ps1')
        Set-Content $pssubshellscript @"
Set-Variable -Name Old -Value `$ErrorActionPreference -Scope Global
`$ErrorActionPreference = 'SilentlyContinue'
$PSCommandPath -Initialize
$Command
`$PSubShell='$PSubShellPath'
`$ErrorActionPreference = `$Old
Remove-Variable -Name Old -Scope Global
"@
        Invoke-Expression "pwsh -Interactive $(((-not $Command) -or $NoExit) ? '-NoExit' : '') $($NoProfile ? '-NoProfile' : '') -File $pssubshellscript"
    }

    'Initialize' {
        Write-Host 'Initializing PSubShell...'

        $modules = $PSubShellVersions.modules ?? @{}
        foreach ($kv in $modules.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $parms = *GetParameters $version -Exclude 'Version', 'MinimumVersion', 'MaximumVersion'
            $parms.RequiredVersion = $version.Version
            $module = Get-Module -Name $name -ListAvailable -ErrorAction SilentlyContinue |
                Where-Object { $_.Version -eq $version.Version }
            if (-not $module) {
                $module = Join-Path $PSubShellPath $name -AdditionalChildPath $version.Version, "$name.psd1"
                if (-not (Test-Path $module)) {
                    New-Item -ItemType Directory -Path $PSubShellPath -Force | Out-Null
                    Save-Module $name -Path $PSubShellPath -RequiredVersion $version.Version @parms
                }
            }
            Import-Module $module -Force
        }

        $scripts = $PSubShellVersions.scripts ?? @{}
        foreach ($kv in $scripts.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $script = Join-Path $PSubShellPath "$name.ps1"
            $info = Test-ScriptFileInfo -Path $script -ErrorAction SilentlyContinue
            if ((-not $info) -or ($info.Version -ne $version.Version)) {
                $parms = *GetParameters $version -Exclude 'Version', 'MinimumVersion', 'MaximumVersion'
                $parms.RequiredVersion = $version.Version
                Save-Script $name -Path $PSubShellPath -Force @parms
            }
            Set-Alias -Name $name -Value $script -Scope Global
            Write-Host "$(Get-Alias -Name $name)"
        }

        $packages = $PSubShellVersions.packages ?? @{}
        foreach ($kv in $packages.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $package = Join-Path $PSubShellPath $name -AdditionalChildPath $version.Version
            if (-not (Test-Path $package)) {
                $parms = *GetParameters $version -Exclude 'Version', 'MinimumVersion', 'MaximumVersion'
                $parms.RequiredVersion = $version.Version
                Save-Package $name -Path $PSubShellPath -RequiredVersion $version.Version @parms | Out-Null
                $nupkg = (Join-Path $PSubShellPath "$name.$($version.Version).nupkg")
                Expand-Archive $nupkg $package -Force | Out-Null
                Remove-Item $nupkg -Force
            }
            $tools = Join-Path $package 'tools'
            if (Test-Path $tools) {
                $env:PATH = "$tools$([IO.Path]::PathSeparator)$env:PATH"
            }
        }
    }

    'AddModule' {
        $parms = *GetParameters $PSBoundParameters -Exclude 'AddModule'
        $module = Find-Module -ErrorAction Stop @parms
        $parms.Version = $module.Version
        $parms.Remove('Name')
        if (-not $PSubShellVersions.modules) {
            $PSubShellVersions.modules = @{}
        }
        $PSubShellVersions.modules.$Name = $parms
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'RemoveModule' {
        $PSubShellVersions.modules.Remove($Name)
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'AddScript' {
        $parms = *GetParameters $PSBoundParameters -Exclude 'AddScript'
        $script = Find-Script -ErrorAction Stop @parms
        $parms.Version = $script.Version
        $parms.Remove('Name')
        if (-not $PSubShellVersions.scripts) {
            $PSubShellVersions.scripts = @{}
        }
        $PSubShellVersions.scripts.$Name = $parms
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'RemoveScript' {
        $PSubShellVersions.scripts.Remove($Name)
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'AddPackage' {
        $parms = *GetParameters $PSBoundParameters -Exclude 'AddPackage'
        $package = Find-Package -ErrorAction Stop @parms
        $parms.Version = $package.Version
        $parms.Remove('Name')
        if (-not $PSubShellVersions.packages) {
            $PSubShellVersions.packages = @{}
        }
        $PSubShellVersions.packages.$Name = $parms
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'RemovePackage' {
        $PSubShellVersions.packages.Remove($Name)
        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'Update' {
        $modules = $PSubShellVersions.modules ?? @{}
        foreach ($kv in $modules.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $parms = *GetParameters $version -Exclude 'Version'
            $module = Find-Module $name -ErrorAction SilentlyContinue @parms
            $PSubShellVersions.modules.$name.Version = $module.Version
        }

        $scripts = $PSubShellVersions.scripts ?? @{}
        foreach ($kv in $scripts.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $parms = *GetParameters $version -Exclude 'Version'
            $script = Find-Script $name -ErrorAction SilentlyContinue @parms
            $PSubShellVersions.scripts.$name.Version = $script.Version
        }

        $packages = $PSubShellVersions.packages ?? @{}
        foreach ($kv in $packages.GetEnumerator()) {
            $name = $kv.Key
            $version = $kv.Value
            $parms = *GetParameters $version -Exclude 'Version'
            $package = Find-Package $name -ErrorAction SilentlyContinue @parms
            $PSubShellVersions.packages.$name.Version = $package.Version
        }

        ConvertTo-Json $PSubShellVersions | Set-Content $PSubShellLockFile
    }

    'CreateBuildScript' {
        if ((-not $Force) -and (Test-Path $Path)) {
            Write-Error "File '$Path' already exists. Use -Force to overwrite."
            return
        }

        Set-Content -Path $Path -Value @"
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    $c = "Invoke-Build $($Tasks -join ',') -File $($MyInvocation.MyCommand.Path)"
    foreach ($kv in $PSBoundParameters) {
        $c += " $($kv.Key) $($kv.Value)"
    }
    ./PSubShell.ps1 -NoProfile -Command $c
    return
}

task . { Write-Build Green 'Hello world!' }
"@        
    }
}
