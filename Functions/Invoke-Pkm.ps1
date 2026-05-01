function Register-PkmVault {
    param(
        [string]$Name,
        [string]$VaultPath,
        [string]$Alias = $Name.ToLower()
    )

    $scriptFile = Join-Path (Resolve-Path $VaultPath) 'Invoke-Pkm.ps1'
    if (-not (Test-Path $scriptFile)) { return }

    . $scriptFile   # defines Invoke-Pkm / alias pkm in local scope

    $funcName = "Invoke-$Name"
    Set-Item "function:Global:$funcName" (Get-Item 'function:\Invoke-Pkm').ScriptBlock
    Set-Alias -Name $Alias -Value $funcName -Scope Global
}

Register-PkmVault -Name 'Pkm' -VaultPath '~/pkm'
# Register-PkmVault -Name 'WorkPkm' -VaultPath '~/work-pkm' -Alias 'wpkm'
