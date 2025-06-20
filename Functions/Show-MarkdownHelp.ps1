function Show-MarkdownHelp {
    param(
        [Parameter(Mandatory = $True)]
        $Name
    )

    $s = Get-MarkdownHelp -Name $Name | ConvertFrom-Markdown -AsVT100EncodedString | Select-Object -ExpandProperty VT100EncodedString
    try {
        $s -split "`n" | Out-Host -Paging
    } catch {
        return
    }
}

Set-Alias -Name phelp -Value Show-MarkdownHelp