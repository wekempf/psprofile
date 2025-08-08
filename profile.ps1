# Detect elevation
$IsAdmin = & {
    if ($IsWindows) {
        $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $prp = New-Object System.Security.Principal.WindowsPrincipal($wid)
        $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
        $prp.IsInRole($adm)
    }
    elseif ($IsLinux) {
        (id) -like 'uid=0*'
    }
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
if ($IsWindows) {
    $script:ComputerName = $env:COMPUTERNAME
}
elseif ($IsLinux) {
    if (Get-Command hostname -ErrorAction SilentlyContinue) {
        $script:ComputerName = (hostname)
    }
    else {
        $script:ComputerName = Get-Content /etc/hostname
    }
}
Write-Figlet $script:ComputerName -Font big -Foreground ($IsAdmin ? 'Red' : 'Blue')

# Configure environment variables
Set-Variable -Name ProfileDir -Value (Split-Path $profile)
Set-Variable -Name ModuleDir -Value (Join-Path $ProfileDir 'Modules')
if (Get-Command -Name code -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'code'
}
else {
    if ($IsWindows) {
        $env:EDITOR = 'notepad'
    }
}

# If we have a bin folder add it to the path
if (Test-Path ~/bin) {
    Add-Path ~/bin
}

# If we have a scripts folder add it to the path
if (Test-Path $PSScriptRoot/scripts) {
    Add-Path $PSScriptRoot/scripts
}

# If we have a ~/.git_commands folder at it to the path
if (Test-Path ~/.git_commands) {
    Add-Path ~/.git_commands
}

# Create SymLinks for dotfiles
if ($IsWindows) {
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
}

Import-RequiredModule posh-git

if (Get-Module PowerLocation -ListAvailable) {
    Import-Module PowerLocation
    Set-Alias -Name z -Value Set-PowerLocation
}

. $PSScriptRoot/customprompt.ps1

. (Join-Path $PSScriptRoot psreadlinecfg.ps1)

# Setup our DynamicTitle
#. (Join-Path $PSScriptRoot DynamicTitle.ps1)

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    function _fzf_item_preview {
        param($file)
        if (Test-Path $file -PathType Container) {
            return "tree -C $file"
        }
        if ($file -match '\.(png|jpg|jpeg|gif)$') {
            return "imgcat $file"
        }
        elseif ($file -match '\.(ps1|sh|py|js|ts|java|c|cpp|cs)$') {
            return "bat --style=numbers,changes,header --color=always --theme=Dracula --line-range :100 $file"
        }
        else {
            return "cat $file"
        }
    }
    # Setup fzf
    Import-RequiredModule PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -PSReadlineChordSetLocation 'Ctrl+l'
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    $_fzf_bat_cmd = 'bat --style=numbers,changes,header --color=always --theme=Dracula --line-range :100 {}'
    $_fzf_fd_all_cmd = 'fd -tf -td -tl {0}' -f $env:FD_OPTIONS
    $env:FZF_DEFAULT_OPTS = "--prompt '⯈ ' --height 50% --layout=reverse --border --color=dark --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7"
    $env:FD_OPTIONS = '--hidden --follow'
    $env:FZF_DEFAULT_COMMAND = $_fzf_fd_all_cmd
    $env:FZF_CTRL_T_OPTS = "--preview `"$_fzf_bat_cmd`""
    $env:FZF_CTRL_T_COMMAND = $_fzf_fd_all_cmd
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Setup zoxide
    Invoke-Expression (& { (zoxide init powershell --hook pwd | Out-String) })
    $env:_ZO_FZF_OPTS = $env:FZF_DEFAULT_OPTS
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

# Set an alias for invoking build.ps1 scripts in the current location
Set-Alias -Name b -Value './build.ps1'

if ($IsLinux) {
    Set-Alias -Name ls -Value Get-ChildItem
}

# Display notice if there's profile changes
Push-Location $ProfileDir
try {
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        if (-not (git status | Select-String 'nothing to commit')) {
            Write-Warning 'Profile changes need to be committed and pushed'
        }
        else {
            git fetch
            if ((git rev-list --count origin..HEAD) -gt 0) {
                Write-Warning 'Local profile changes need to be pushed'
            }
            elseif ((git rev-list --count HEAD..origin) -gt 0) {
                Write-Warning 'Remote profile changes need to be merged'
            }
        }
    }
}
finally {
    Pop-Location
}
