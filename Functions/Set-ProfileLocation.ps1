function Set-ProfileLocation {
    Set-Location (Split-Path ($Profile.CurrentUserAllHosts))
}

Set-Alias -Name cdpro -Value Set-ProfileLocation