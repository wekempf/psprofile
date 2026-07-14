function Push-ProfileLocation {
    Push-Location $ProfileDir
}

Set-Alias -Name ppro -Value Push-ProfileLocation