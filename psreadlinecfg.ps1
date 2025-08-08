# Configure PSReadline
$PSReadLineOPtions = @{
    ExtraPromptLineCount          = 1
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    BellStyle                     = 'visual'
    PredictionSource              = 'History'
}
Set-PSReadLineOption @PSReadLineOptions
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key 'Alt+9' `
    -BriefDescription ParenthesizeSelection `
    -LongDescription 'Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis' `
    -ScriptBlock {
    param($key, $arg)

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}
Set-PSReadLineKeyHandler -Chord "Ctrl+'", "Ctrl+Shift+`"" `
    -BriefDescription SmartInsertQuote `
    -Description 'Insert paired quotes if not already on a quote' `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $keyChar = $key.KeyChar
    if ($key.Key -eq 'Oem7') {
        if ($key.Modifiers -eq 'Control') {
            $keyChar = "`'"
        }
        elseif ($key.Modifiers -eq 'Shift', 'Control') {
            $keyChar = '"'
        }
    }

    if ($line[$cursor] -eq $key.KeyChar) {
        # Just move the cursor
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        # Insert matching quotes, move cursor to be in between the quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$keyChar" * 2)
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor - 1)
    }
}
Set-PSReadLineKeyHandler -Chord Alt+c `
    -BriefDescription CopyCurrentPathToClipboard `
    -LongDescription 'Copy the current path to the clipboard' `
    -ScriptBlock {
    param($key, $arg)

    Set-Clipboard $pwd.Path
}
Set-PSReadLineKeyHandler -Chord Alt+v `
    -BriefDescription PasteAsHereString `
    -LongDescription 'Paste the clipboard text as a here string' `
    -ScriptBlock {
    param($key, $arg)

    $clipboardText = Get-Clipboard
    if ($clipboardText) {
        # Remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = $clipboardText.TrimEnd() -join "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}
Set-PSReadLineKeyHandler -Chord Alt+r `
    -BriefDescription ResolveAliases `
    -LongDescription 'Replace all aliases with the full command' `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $startAdjustment = 0
    foreach ($token in $tokens) {
        if ($token.TokenFlags -band [System.Management.Automation.Language.TokenFlags]::CommandName) {
            $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
            if ($alias -ne $null) {
                $resolvedCommand = $alias.ResolvedCommandName
                if ($resolvedCommand -ne $null) {
                    $extent = $token.Extent
                    $length = $extent.EndOffset - $extent.StartOffset
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                        $extent.StartOffset + $startAdjustment,
                        $length,
                        $resolvedCommand)

                    # Our copy of the tokens won't have been updated, so we need to
                    # adjust by the difference in length
                    $startAdjustment += ($resolvedCommand.Length - $length)
                }
            }
        }
    }
}
