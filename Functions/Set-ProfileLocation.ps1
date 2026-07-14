function Set-ProfileLocation {
    Set-Location $ProfileDir
}

Set-Alias -Name cdpro -Value Set-ProfileLocation