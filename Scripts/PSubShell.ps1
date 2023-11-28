#Requires -PSEdition Core

<#PSScriptInfo

.VERSION 0.3.0

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

.SYNOPSIS
Creates a sub shell configured to use locally installed scripts, modules and packages.
#> 
[CmdletBinding(DefaultParameterSetName = 'EnterShell')]
Param(
    # Executes the specified commands (and any parameters) as though they were
    # typed at the PowerShell command prompt, and then exits, unless the -NoExit
    # parameter is specified.
    [Parameter(ParameterSetName = 'EnterShell', Position = 0)]
    [string]$Command,

    # A hash table of parameters to pass to the command specified by the -Command
    # parameter. This allows for parameter splatting.
    [Parameter(ParameterSetName = 'EnterShell')]
    [hashtable]$Parameters = @{},

    # Does not load the PowerShell profiles.
    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoProfile,

    # Does not exit the shell after running startup commands.
    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoExit,

    # Hides the banner text at startup of interactive sessions.
    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoLogo,

    # Initializes a directory for use with PSubShell.
    [Parameter(ParameterSetName = 'Initialize', Mandatory)]
    [switch]$Initialize,

    # Includes the PSubShell.ps1 script in the initialized directory.
    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$Isolated,

    # Includes an InvokeBuild build.ps1 script in the initialized directory.
    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$InvokeBuild,

    # Applies the configured PSubShell settings to the current shell. This is
    # done automatically when entering the subshell, but can be used to apply
    # changes to the configuration without entering the subshell.
    [Parameter(ParameterSetName = 'Apply', Mandatory)]
    [switch]$Apply,

    # Installs the specified PSResource in the subshell.
    [Parameter(ParameterSetName = 'InstallResource', Mandatory)]
    [string]$InstallResource,

    # The version of the PSResource to install. A range can be specified.
    [Parameter(ParameterSetName = 'InstallResource')]
    [string]$Version,

    # Allow prerelease versions of the PSResource to be installed.
    [Parameter(ParameterSetName = 'InstallResource')]
    [switch]$Prerelease,

    # The repository to use when installing the PSResource.
    [Parameter(ParameterSetName = 'InstallResource')]
    [string]$Repository,

    # Removes the specified PSResource from the subshell.
    [Parameter(ParameterSetName = 'RemoveResource')]
    [string]$RemoveResource,

    # Updates the lockfile with the latest versions of all installed PSResources.
    [Parameter(ParameterSetName = 'Update', Mandatory)]
    [switch]$Update,

    # Adds the specified path to the PATH environment variable of the subshell.
    # The path can be relative to the current directory, or fully qualified, though
    # it's not recommended to use fully qualified paths if the subshell is to be
    # distributed, including committed to version control systems.
    [Parameter(ParameterSetName = 'AddPath', Mandatory)]
    [string[]]$AddPath,

    # Adds the specified path to the PSModulePath environment variable of the
    # subshell. The path can be relative to the current directory, or fully
    # qualified, though it's not recommended to use fully qualified paths if the
    # subshell is to be distributed, including committed to version control
    # systems.
    [Parameter(ParameterSetName = 'AddModulePath', Mandatory)]
    [string[]]$AddModulePath,

    # Adds the specified variable to the subshell. The variable can be a
    # PowerShell variable, or an environment variable. If an environment variable
    # is specified, it must be prefixed with 'env:'.
    [Parameter(ParameterSetName = 'AddVariable')]
    [string]$AddVariable,

    # The value of the variable to add.
    [Parameter(ParameterSetName = 'AddVariable', Position = 1)]
    [string]$Value,

    [Parameter(ParameterSetName = 'DefaultRepository', Mandatory)]
    [string]$DefaultRepository
)

for ($path = Get-Location; $path; $path = Split-Path $path) {
    if ($Initialize -or (Test-Path (Join-Path $path '.psubshell.json'))) {
        $PSubShell = @{
            Path = $path
            ConfigFile = Join-Path $path '.psubshell.json'
            LockFile = Join-Path $path '.psubshell.lock.json'
        }
        $PSubShell.Config = (Get-Content $PSubShell.ConfigFile -ErrorAction SilentlyContinue |
                ConvertFrom-Json -AsHashtable) ?? @{ Resources = @{ } }
        $PSubShell.Locks = (Get-Content $PSubShell.LockFile -ErrorAction SilentlyContinue |
                ConvertFrom-Json -AsHashtable) ?? @{ }
        break
    }
}

if (-not $PSubShell) {
    Write-Error 'No PSubShell initialized.'
    return
}

switch ($PSCmdlet.ParameterSetName) {
    'Initialize' {
        if ((-not $PSBoundParameters.ContainsKey('Isolated')) -and $InvokeBuild) {
            $Isolated = $True
        }
        if ($ISolated) {
            Save-PSResource -Name PSubShell -Path . -IncludeXml -WarningAction SilentlyContinue
            Remove-Item PSubShell_InstalledScriptInfo.xml
        }
        if ($InvokeBuild) {
            $resource = Find-PSResource InvokeBuild -ErrorAction Stop
            $PSubShell.Config.Resources.InvokeBuild = @{ Type = $resource.Type.ToString() }
            $PSubShell.Locks.InvokeBuild = @{ Type = $resource.Type.ToString(); Version = $resource.Version.ToString() }
            if ($Isolated) {
                Set-Content -Path 'build.ps1' -Value @'
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks = '.'
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    ./PSubShell.ps1 -NoProfile -Command "Invoke-Build $Tasks $PSCommandPath" -Parameters $PSBoundParameters
    return
}

task . { Write-Build Green 'Hello world!' }
'@
            }
            else {
                Set-Content -Path 'build.ps1' -Value @'
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks = '.'
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    PSubShell -NoProfile -Command "Invoke-Build $Tasks $PSCommandPath" -Parameters $PSBoundParameters
    return
}

task . { Write-Build Green 'Hello world!' }
'@
            }
        }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
        return
    }
    'EnterShell' {
        if ($global:PSubShellInstance -eq $PSubShell.Path) {
            Write-Error 'Cannot reenter the same PSubShell.'
            return
        }

        $script = Join-Path ([System.IO.Path]::GetTempPath()) "tmp$((New-Guid) -replace '-','').ps1"
        try {
            Set-Content -Path $script -Value @"
`$global:PSubShellInstance = '$($PSubShell.Path)'
Set-Alias -Name PSubShell -Value $($MyInvocation.MyCommand.Path)
$PSCommandPath -Apply
$Command $($Parameters.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" } | Join-String ' ')
"@
            #Get-Content $script
            Invoke-Expression "pwsh -Interactive $(((-not $Command) -or $NoExit) ? '-NoExit' : '') $($NoProfile ? '-NoProfile' : '') $($NoLogo ? '-NoLogo' : '') -File $script"
        }
        finally {
            Remove-Item -Path $script -Force -ErrorAction SilentlyContinue
        }
    }

    'InstallResource' {
        $parms = @{}
        foreach ($parm in $PSBoundParameters.Keys) {
            if ($parm -ne 'InstallResource') {
                if ($PSBoundParameters.$parm -is [switch]) {
                    $parms.Add($parm, [bool]$PSBoundParameters.$parm)
                }
                else {
                    $parms.Add($parm, $PSBoundParameters.$parm)
                }
            }
        }
        $resource = Find-PSResource -Name $InstallResource -ErrorAction SilentlyContinue @parms |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
        if (-not $resource) {
            Write-Error "Unable to find resource '$InstallResource'."
            return
        }
        $type = $resource.Type.ToString()
        if ((-not $type) -or ($type -eq 'None')) {
            $type = 'Package'
        }
        $PSubShell.Config.Resources.$InstallResource = @{
            Type = $type
        } + $parms
        $PSubShell.Locks.$InstallResource = @{
            Type = $type
            Version = $resource.Version.ToString()
        }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'RemoveResource' {
        if ($PSubShell.Config.Resources.$RemoveResource) { $PSubShell.Config.Resources.Remove($RemoveResource) }
        if ($PSubShell.Locks.$RemoveResource) { $PSubShell.Locks.Remove($RemoveResource) }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'Update' {
        foreach ($name in $PSubShell.Config.Resources.Keys) {
            $parms = @{ }
            foreach ($parm in $PSubShell.Config.Resources.$name.Keys) {
                if ($parm -ne 'Type') {
                    Write-Host $parm
                    $parms.Add($parm, $PSubShell.Config.Resources.$name.$parm)
                }
            }
            $resource = Find-PSResource -Name $name -ErrorAction SilentlyContinue @parms |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
            $PSubShell.Locks.$name = @{
                Type = $resource.Type.ToString() ?? 'Package'
                Version = $resource.Version.ToString()
            }
        }
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'AddPath' {
        if (-not $PSubShell.Config.ContainsKey('Path')) {
            $PSubShell.Config.Path = @()
        }
        $fqpWarning = $false
        foreach ($path in @($AddPath)) {
            if ([System.IO.Path]::IsPathFullyQualified($path)) {
                Write-Warning "Adding fully qualified path '$path'."
                $fqpWarning = $true
            }
        }
        if ($fqpWarning) {
            Write-Warning 'Adding fully qualified paths is not recommended.'
        }
        $PSubShell.Config.Path += @($AddPath)
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
    }

    'AddModulePath' {
        if (-not $PSubShell.Config.ContainsKey('ModulePath')) {
            $PSubShell.Config.ModulePath = @()
        }
        $fqpWarning = $false
        foreach ($path in @($AddModulePath)) {
            if ([System.IO.Path]::IsPathFullyQualified($path)) {
                Write-Warning "Adding fully qualified module path '$path'."
                $fqpWarning = $true
            }
        }
        if ($fqpWarning) {
            Write-Warning 'Adding fully qualified paths is not recommended.'
        }
        $PSubShell.Config.ModulePath += @($AddModulePath)
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
    }

    'AddVariable' {
        if (-not $PSubShell.Config.ContainsKey('Variables')) {
            $PSubShell.Config.Variables = @{}
        }
        $PSubShell.Config.Variables.$AddVariable = $Value
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
    }

    'DefaultRepository' {
        $PSubShell.Config.DefaultRepository = $DefaultRepository
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
    }

    'Apply' {
        Write-Host 'Applying PSubShell...'
        $psubshellpath = Join-Path $PSubShell.Path '.psubshell'
        $cpath = @($PSubShell.Config.Path)
        [Array]::Reverse($cpath)
        foreach ($path in $cpath) {
            if (-not ([IO.Path]::IsPathRooted($path))) {
                $path = Join-Path $PSubShell.Path $path
            }
            $path = Join-Path $path '.'
            $path = [IO.Path]::GetFullPath($path)
            $existingPaths = $env:PATH -split [IO.Path]::PathSeparator
            if (-not ($existingPaths -contains $path)) {
                $env:PATH = $path + [IO.Path]::PathSeparator + $env:PATH
            }
        }
        $cpath = @($PSubShell.Config.ModulePath)
        [Array]::Reverse($cpath)
        foreach ($path in $cpath) {
            if (-not ([IO.Path]::IsPathRooted($path))) {
                $path = Join-Path $PSubShell.Path $path
            }
            $path = Join-Path $path '.'
            $path = [IO.Path]::GetFullPath($path)
            $existingPaths = $env:PSModulePath -split [IO.Path]::PathSeparator
            if (-not ($existingPaths -contains $path)) {
                $env:PSModulePath = $path + [IO.Path]::PathSeparator + $env:PSModulePath
            }
        }
        foreach ($key in $PSubShell.Config.Variables.Keys) {
            if ($key.StartsWith('env:', 'InvariantCultureIgnoreCase')) {
                Set-Item -Path $key -Value $PSubShell.Config.Variables.$key
            }
            else {
                Set-Variable -Name $key -Value $PSubShell.Config.Variables.$key -Scope Global
            }
        }
        foreach ($key in $PSubShell.Config.EnvironmentVariables.Keys) {
            Set-Item -Path "env:$key" -Value $PSubShell.Config.EnvironmentVariables.$key
        }
        foreach ($resource in $PSubShell.Locks.Keys) {
            New-Item -Path $psubshellpath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $Repository = $PSubShell.Config.Resources.$resource.Repository ?? $PSubShell.Config.DefaultRepository
            switch ($PSubShell.Locks.$resource.Type) {
                'Script' {
                    $resourcePath = Join-Path $psubshellpath "$resource.ps1"
                    $found = $false
                    if (Test-Path $resourcePath) {
                        $info = Get-PSScriptFileInfo -Path $resourcePath
                        if ($info.Version -eq $PSubShell.Locks.$resource.Version) {
                            $found = $true
                        }
                    }
                    if (-not $found) {
                        Remove-Item -Path $resourcePath -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -Repository:$Repository -IncludeXml -WarningAction SilentlyContinue
                    }
                    Set-Alias -Name $resource -Value $resourcePath -Scope Global
                    Write-Host "Set-Alias -Name $resource -Value $resourcePath"
                }
                'Module' {
                    $resourcePath = Join-Path $psubshellpath $resource -AdditionalChildPath $PSubShell.Locks.$resource.Version
                    if (-not (Test-Path $resourcePath)) {
                        Remove-Item -Path (Join-Path $psubshellpath $resource) -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -IncludeXml -WarningAction SilentlyContinue
                    }
                    Import-Module (Join-Path $psubshellpath $resource) -Force
                }
                'Package' {
                    $resourcePath = Join-Path $psubshellpath $resource -AdditionalChildPath $PSubShell.Locks.$resource.Version
                    if (-not (Test-Path $resourcePath)) {
                        Remove-Item -Path (Join-Path $psubshellpath $resource) -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -IncludeXml -WarningAction SilentlyContinue
                    }
                    $tools = Join-Path $resourcePath 'tools'
                    if (Test-Path $tools) {
                        $env:PATH = (@($tools) + (
                                $env:PATH -split [IO.Path]::PathSeparator |
                                    Where-Object { $_ -ne $tools }
                            )) -join [IO.Path]::PathSeparator
                    }
                }
            }
        }
    }
}
