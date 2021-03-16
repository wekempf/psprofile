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
        Get-ChildItem $_ | ForEach-Object {
            . $_.FullName
        }
    }

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

# Ensure we have scoop installed
if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
    Write-Warning "Cannot find 'scoop'. Installing..."
    Invoke-WebRequest -UseBasicParsing -Uri 'https://get.scoop.sh' | Invoke-Expression
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
if (-not (Test-Path ~/.config)) {
    New-Item -Path ~/.config -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
}
if (-not (Test-Path ~/.config/starship.toml)) {
    if ($IsAdmin) {
        New-Item -Path ~/.config/starship.toml -ItemType SymbolicLink -Value (Join-Path $PSScriptRoot 'dotfiles/.config/starship.toml') | Out-Null
    } else {
        Write-Warning "Unable to create symlink for '$(Join-Path (Resolve-Path ~) .config/starship.toml)'. Open an elevated PowerShell to create the symlink."
    }
}

# Load posh-git
if (-not (Get-Module -Name posh-git -ListAvailable)) {
    Install-Module -Name posh-git -Scope CurrentUser -Repository PSGallery
}
Import-Module posh-git
#$GitPromptSettings.DefaultPromptPath = '$(Get-ShortLocationName)'

# Load oh-my-posh
# if (Get-Module -Name oh-my-posh -ListAvailable) {
#     Import-Module oh-my-posh
#     Set-PoshPrompt -Theme $ProfileDir\PoshThemes\wek-star.json
# }

# Configure Starship as our prompt
if (-not (Get-Command -Name starship -ErrorAction SilentlyContinue)) {
    scoop install starship
}
Invoke-Expression (&starship init powershell)

# Load Z
if (-not (Get-Module -Name Z -ListAvailable)) {
    Install-Module -Name Z -Scope CurrentUser -Repository PSGallery -AllowClobber
}
Import-Module Z

# Load PSColor
# if (Get-Module -Name PSColor -ListAvailable) {
#     Import-Module PSColor
# }

# Configure PSReadline
$PSReadLineOPtions = @{
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    BellStyle = 'visual'
}
Set-PSReadLineOption @PSReadLineOptions
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

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

