function Update-WinGet {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$SkipFile = "~/.winget-skip",
        [string[]]$Skip = @(),
        [switch]$IncludeInvalidVersions
    )
    
    if (-not (Get-Module Microsoft.WinGet.Client -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-Module Microsoft.WinGet.Client -Scope CurrentUser
    }
    Import-Module Microsoft.WinGet.Client

    if (Test-Path $SkipFile) {
        $Skip += Get-Content $SkipFile
    }

    $Skipped = @()

    Get-WinGetPackage |
    Where-Object { $_.IsUpdateAvailable } |
    Where-Object { -not (($Skip -contains $_.Id) -or ($Skip -contains $_.Name)) } |
    ForEach-Object {
        $Name = $_.Name
        $Id = $_.Id
        $Version = $_.InstalledVersion
        try {
            [version]$Version | Out-Null
            $HasValidVersion = $True
        }
        catch {
            $HasValidVersion = $False
        }

        if ($HasValidVersion -or $IncludeInvalidVersions) {
            if ($PSCmdLet.ShouldProcess("$Name ($Id)", "Update-WinGetPackage")) {
                Write-Verbose "Udating $Name"
    
                $_ |
                Update-WingetPackage |
                Select-Object -Property @{Name = 'Name'; Expression = { $Name } }, @{Name = 'Id'; Expression = { $Id } }, @{Name = 'ErrorCode'; Expression = { $_.InstallerErrorCode } }, Status, @{Name = 'ExtendedCode'; Expression = { $_.ExtendedErrorCode } }, @{Name = 'Reboot'; Expression = { $_.RebootRequired } }
            }
        }
        else {
            $Skipped += "$Name ($Id)"
        }
    }

    if ($Skipped.Count -gt 0) {
        Write-Warning "Skipped $($Skipped.Count) packages because they have invalid versions:"
        Write-Warning "Run again with -IncludeInvalidVersions to update them."
        $Skipped | ForEach-Object { Write-Warning "  $_" }
    }
}
Set-Alias -Name udwg -Value Update-WinGet