Set-Variable -Name ProfileDir -Value (Split-Path $Profile.CurrentUserCurrentHost)
if (Test-Path $ProfileDir) {
    Write-Warning "Profile directory already exists. Doing nothing."
} else {
    if (Get-Command git) {
        New-Item $ProfileDir -ItemType Directory -Force | Out-Null
        Set-Location $ProfileDir
        git clone https://github.com/wekempf/psprofile.git .
        Write-Host "PowerShell Profile created. Restart PowerShell."
    } else {
        Write-Warning "Git is not installed. Doing nothing."
    }
}