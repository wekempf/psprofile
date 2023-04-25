# Detect elevation
$IsAdmin = & {
    $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $prp.IsInRole($adm)
}

function Import-RequiredModule {
    param(
        [string[]]$Name,
        [switch]$AllowClobber
    )

    $Name | ForEach-Object {
        if (-not (Get-Module -Name $_ -ListAvailable)) {
            Install-Module -Name $_ -Scope CurrentUser -AllowClobber:$AllowClobber # -Repository PSGallery
        }
        Import-Module $_
    }
}

# Dot source functions
(Join-Path $PSScriptRoot 'Functions'), (Join-Path $PSScriptRoot "${env:COMPUTERNAME}\Functions") |
Where-Object { Test-Path $_ } |
ForEach-Object {
    Get-ChildItem (Join-Path $_ '*.ps1') | ForEach-Object {
        . $_.FullName
    }
}

# Write banner
Import-RequiredModule Figlet -AllowClobber
Write-Figlet $env:COMPUTERNAME -Font big -Foreground ($IsAdmin ? 'Red' : 'Blue')

# Configure environment variables
Set-Variable -Name ProfileDir -Value (Split-Path $profile)
Set-Variable -Name ModuleDir -Value (Join-Path $ProfileDir 'Modules')
if (Get-Command -Name code -ErrorAction SilentlyContinue) {
    $env:Editor = 'code'
}
else {
    $env:Editor = "notepad"
}

# If we have a bin folder add it to the path
if (Test-Path ~/bin) {
    Add-Path ~/bin
}

# If we have a ~/.git_commands folder at it to the path
if (Test-Path ~/.git_commands) {
    Add-Path ~/.git_commands
}

# Create SymLinks for dotfiles
foreach ($dotfile in (Get-ChildItem -File -Path (Join-Path $PSScriptRoot 'dotfiles'))) {
    $destination = Join-Path ~ (Split-Path -Leaf $dotfile)
    if (-not (Test-Path $destination -PathType Leaf)) {
        if ($IsAdmin) {
            Write-Host -ForegroundColor Blue "Linking dotfile '$destination'..."
            New-Item -Path $destination -ItemType SymbolicLink -Value $dotfile | Out-Null
        }
        else {
            Write-Warning "Unable to create symlink for '$destination'. Open an elevated PowerShell to create the symlink."
        }
    }
}
foreach ($dotfolder in (Get-ChildItem -Directory -Path (Join-Path $PSScriptRoot 'dotfiles'))) {
    $destination = Join-Path ~ (Split-Path -Leaf $dotfolder)
    if (-not (Test-Path $destination -PathType Container)) {
        if ($IsAdmin) {
            Write-Host -ForegroundColor Blue "Linking dotfolder '$destination'..."
            New-Item -Path $destination -ItemType SymbolicLink -Value $dotfolder | Out-Null
        }
        else {
            Write-Warning "Unable to create symlink for folder '$destination'. Open an elevated PowerShell to create the symlink."
        }
    }
}

Import-RequiredModule posh-git, oh-my-posh, Z

# Setup oh-my-posh
oh-my-posh --init --shell pwsh --config ~/wekempf.omp.json | Invoke-Expression

# Setup our DynamicTitle
. (Join-Path $PSScriptRoot DynamicTitle.ps1)

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
    -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
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
Set-PSReadlineKeyHandler -Chord "Ctrl+'", "Ctrl+Shift+`"" `
    -BriefDescription SmartInsertQuote `
    -Description "Insert paired quotes if not already on a quote" `
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
Set-PSReadlineKeyHandler -Chord Alt+c `
    -BriefDescription CopyCurrentPathToClipboard `
    -LongDescription "Copy the current path to the clipboard" `
    -ScriptBlock {
    param($key, $arg)

    Set-Clipboard $pwd.Path
}
Set-PSReadlineKeyHandler -Chord Alt+v `
    -BriefDescription PasteAsHereString `
    -LongDescription "Paste the clipboard text as a here string" `
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
Set-PSReadlineKeyHandler -Chord Alt+v `
    -BriefDescription PasteAsHereString `
    -LongDescription "Paste the clipboard text as a here string" `
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
Set-PSReadlineKeyHandler -Chord Alt+r `
    -BriefDescription ResolveAliases `
    -LongDescription "Replace all aliases with the full command" `
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

# PowerShell parameter completion shim for the dotnet CLI 
if (Get-Command -Name dotnet -ErrorAction SilentlyContinue) {
    Write-Host -ForegroundColor Blue "Registering argument completer for 'dotnet'..."
    Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
else {
    Write-Information "Command 'dotnet' not found."
}

# PowerShell parameter completion shim for the nuke CLI 
if (Get-Command -Name nuke -ErrorAction SilentlyContinue) {
    Write-Host -ForegroundColor Blue "Registering argument completer for 'nuke'..."
    Register-ArgumentCompleter -Native -CommandName nuke -ScriptBlock {
        param($commandName, $wordToComplete, $cursorPosition)
        nuke :complete "$wordToComplete" | ForEach-Object {
            if (-not $_.StartsWith('NUKE Global Tool')) {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        }
    }
}
else {
    Write-Information "Command 'nuke' not found."
}

# Hopefully temporary fix for "dotnet new" slowness (https://github.com/dotnet/templating/issues/2093)
#$env:DOTNET_NEW_LOCAL_SEARCH_FILE_ONLY = 1

# Invoke machine specific profile
@(Join-Path $PSScriptRoot "machine\${env:COMPUTERNAME}\$($MyInvocation.MyCommand.Name)") |
Where-Object { Test-Path $_ } |
ForEach-Object { . $_ }

# Display notice if there's profile changes
Push-Location $ProfileDir
try {
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        if (-not (git status | Select-String 'nothing to commit')) {
            Write-Warning "Profile changes need to be committed and pushed"
        }
        else {
            git fetch
            if ((git rev-list --count origin..HEAD) -gt 0) {
                Write-Warning "Local profile changes need to be pushed"
            }
            elseif ((git rev-list --count HEAD..origin) -gt 0) {
                Write-Warning "Remote profile changes need to be merged"
            }
        }
    }
}
finally {
    Pop-Location
}