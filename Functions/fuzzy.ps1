$env:FZF_DEFAULT_OPTS = '--height ~40% --layout reverse --border'
$FzfDefaultOpts = '--height', '~40%', '--layout', 'reverse', '--border'

function Add-SingleQuotes {
    param (
        [Parameter(ValueFromPipeline)] [String[]] $Items
    )
    process {
        if ($null -eq $Items) {
            ''
        }
        foreach ($item in $Items) {
            if (-not $item) {
                ''
            }
            else {
                $esc = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($item)
                "'$esc'"
            }
        }
    }
}

function Get-FuzzyDirectory {
    param(
        [switch]$IncludeHidden
    )

    $fdArgs = '--type', 'd'
    if ($IncludeHidden) {
        $fdArgs += '-H', '-I'
    }
    $result = (
        fd @fdArgs |
            Resolve-Path -Relative |
            fzf -m --height ~40% --layout reverse --border --header 'xyzzy' |
            Add-SingleQuotes) -join ', '
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
}

Set-PSReadLineKeyHandler -Chord 'ctrl-d' -BriefDescription 'Fuzzy directory search' -ScriptBlock { Get-FuzzyDirectory }
Set-PSReadLineKeyHandler -Chord 'ctrl-alt-d' -BriefDescription 'Fuzzy multiple directory search' -ScriptBlock { Get-FuzzyDirectory -IncludeHidden }

function Get-FuzzyFile {
    param(
        [switch]$IncludeHidden
    )

    $fdArgs = '--type', 'f'
    if ($IncludeHidden) {
        $fdArgs += '-H', '-I'
    }
    $fzfParms = @()
    $result = (fd @fdArgs | Resolve-Path -Relative | fzf @fzfParms | Add-SingleQuotes) -join ', '
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
}

Set-PSReadLineKeyHandler -Chord 'ctrl-f' -ScriptBlock { Get-FuzzyDirectory }
Set-PSReadLineKeyHandler -Chord 'ctrl-alt-f' -ScriptBlock { Get-FuzzyDirectory -IncludeHidden }

function Invoke-FuzzyTabComplete {

}