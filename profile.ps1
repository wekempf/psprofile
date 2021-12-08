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

# Ensure we have scoop installed
if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
    $scoopDir = "~/scoop/shims"
    if (Test-Path $scoopDir) {
        Add-Path (Resolve-Path $scoopDir)
    } else {
        if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
            Write-Warning "Cannot find 'scoop'. Installing..."
            Invoke-WebRequest -UseBasicParsing -Uri 'https://get.scoop.sh' | Invoke-Expression
            if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
                Add-Path (Resolve-Path $scoopDir)
            }
        }
    }
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
if (-not (Get-Module -Name oh-my-posh -ListAvailable)) {
    Install-Module -Name oh-my-posh -Scope CurrentUser -Repository PSGallery
}
Import-Module oh-my-posh
oh-my-posh --init --shell pwsh --config ~/wekempf.omp.json | Invoke-Expression

# Configure Starship as our prompt
# if (-not (Get-Command -Name starship -ErrorAction SilentlyContinue)) {
#     scoop install starship
# }
# Invoke-Expression (&starship init powershell)

# Load Z
if (-not (Get-Module -Name Z -ListAvailable)) {
    Install-Module -Name Z -Scope CurrentUser -Repository PSGallery -AllowClobber
}
Import-Module Z

if (Get-Module -Name AWS.Tools.Common -ListAvailable) {
    Import-Module -Name AWS.Tools.Common
}

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