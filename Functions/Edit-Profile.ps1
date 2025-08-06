function Edit-Profile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [ValidateSet('All', 'Current')]
        $User = 'Current',

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [Alias('Host')]
        [ValidateSet('All', 'Current')]
        $PowershellHost = 'All',

        [Parameter(Mandatory = $true, ParameterSetName = 'Project')]
        [switch]$Project
    )
    
    if ($Project) {
        if (-not (Get-Command -Name code -ErrorAction SilentlyContinue)) {
            throw "Editing the profile project requires Visual Studio Code which cannot be located."
        }

        code (Split-Path ($Profile.CurrentUserAllHosts))
    } else {
        $editor = $env:Editor
        if (-not $editor) {
            $editor = 'notepad'
        }
        if (-not (Get-Command -Name $editor -ErrorAction SilentlyContinue)) {
            throw "Unable to locate editor '$editor'."
        }

        if ($User -eq 'Current') {
            $which = 'CurrentUser'
        } else {
            $which = 'AllUsers'
        }
        if ($PowershellHost -eq 'Current') {
            $which += 'CurrentHost'
        } else {
            $which += 'AllHosts'
        }
        $path = $Profile.$which

        Invoke-Expression "$editor '$path'"
    }
}

Set-Alias -Name pro -Value Edit-Profile
function prop { Edit-Profile -Project }