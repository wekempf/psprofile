function Use-AzPat {
    param (
        $SecretName = 'az-pat'
    )
    $env:AZURE_DEVOPS_EXT_PAT = Get-Secret -Name $SecretName -AsPlainText
}