# Detect elevation
$IsAdmin = & {
    $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $prp.IsInRole($adm)
}

# Dot source functions
(Join-Path $PSScriptRoot 'Functions'),(Join-Path $PSScriptRoot "${env:COMPUTERNAME}\Functions") |
    Where-Object { Test-Path $_ } |
    ForEach-Object {
        Get-ChildItem (Join-Path $_ '*.ps1') | ForEach-Object {
            . $_.FullName
        }
    }

# Write banner
Write-Host (ConvertTo-ASCIIArt -Text $env:COMPUTERNAME -Cache) -ForegroundColor ($IsAdmin ? 'Red' : 'Blue')

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
if (Test-Path ~\bin) {
    Add-Path ~\bin
}

# Create SymLinks for dotfiles
foreach ($dotfile in (Get-ChildItem -File -Path (Join-Path $PSScriptRoot 'dotfiles'))) {
    $destination = Join-Path ~ (Split-Path -Leaf $dotfile)
    if (-not (Test-Path $destination -PathType Leaf)) {
        if ($IsAdmin) {
            Write-Host -ForegroundColor Blue "Linking dotfile '$destination'..."
            New-Item -Path $destination -ItemType SymbolicLink -Value $dotfile | Out-Null
        } else {
            Write-Warning "Unable to create symlink for '$destination'. Open an elevated PowerShell to create the symlink."
        }
    }
}

function Import-RequiredModule {
    param(
        [string[]]$Name
    )

    $Name | ForEach-Object {
        if (-not (Get-Module -Name $_ -ListAvailable)) {
            Install-Module -Name $_ -Scope CurrentUser -Repository PSGallery
        }
        Import-Module $_
    }
}

Import-RequiredModule posh-git,oh-my-posh,Z

# Setup oh-my-posh
oh-my-posh --init --shell pwsh --config ~/wekempf.omp.json | Invoke-Expression

# Configure PSReadline
$PSReadLineOPtions = @{
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    BellStyle = 'visual'
}
Set-PSReadLineOption @PSReadLineOptions
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Ctrl+Shift+L `
    -BriefDescription CopyPathToClipboard `
    -LongDescription "Copies the current path to the clipboard" `
    -ScriptBlock { (Resolve-Path -LiteralPath $pwd).ProviderPath.Trim() | clip }
Set-PSReadLineKeyHandler -Key 'Alt+(' `
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
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
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
} else {
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
} else {
    Write-Information "Command 'nuke' not found."
}

# Hopefully temporary fix for "dotnet new" slowness (https://github.com/dotnet/templating/issues/2093)
$env:DOTNET_NEW_LOCAL_SEARCH_FILE_ONLY = 1

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