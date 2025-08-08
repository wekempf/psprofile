function Push-ProfileLocation {
    Push-Location (Split-Path ($Profile.CurrentUserAllHosts))
}

Set-Alias -Name ppro -Value Push-ProfileLocation