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
            Install-Module -Name $_ -Scope CurrentUser -AllowClobber:$AllowClobber
        }
        Import-Module $_
    }
}

# Use $PSScriptRoot (the real location of this script) rather than $profile, so this
# still resolves correctly when $PROFILE is a stub that dot-sources us from elsewhere
# (e.g. when this repo lives outside OneDrive on a machine where OneDrive redirects
# Documents). On machines without that indirection, $PSScriptRoot and $profile's
# directory are the same thing anyway.
Set-Variable -Name ProfileDir -Value $PSScriptRoot
Set-Variable -Name ModuleDir -Value (Join-Path $ProfileDir 'Modules')

# The OS/edition-specific default location Install-Module -Scope CurrentUser writes
# to. On a machine where this repo lives at its "natural" location (no redirection/
# migration performed), this is the same folder as $ModuleDir, so everything below
# is a no-op. On a machine where the profile has been moved out of a redirected
# Documents folder (e.g. to avoid OneDrive sync overhead), this points at the
# original (possibly cloud-synced) location, while $ModuleDir points at the faster
# local copy.
$DefaultModuleDir = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules'
if ($DefaultModuleDir -ne $ModuleDir) {
    # Make sure modules living alongside this profile are discovered/imported from
    # here instead of falling through to (and potentially reinstalling into) the
    # default location.
    if ($env:PSModulePath -notlike "*$ModuleDir*") {
        $env:PSModulePath = "$ModuleDir$([System.IO.Path]::PathSeparator)$env:PSModulePath"
    }

    # Pick up modules that were installed manually (outside this profile) into the
    # default location - e.g. via `Install-Module -Scope CurrentUser` typed directly
    # at a prompt, which always writes there regardless of $env:PSModulePath - by
    # copying them into $ModuleDir. This is a cheap, top-level-only folder-name
    # comparison, so it costs almost nothing when there's nothing new to copy.
    if (Test-Path $DefaultModuleDir) {
        $existingModules = if (Test-Path $ModuleDir) { (Get-ChildItem $ModuleDir -Directory).Name } else { @() }
        Get-ChildItem $DefaultModuleDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $existingModules } |
            ForEach-Object {
                Write-Host -ForegroundColor Blue "Copying module '$($_.Name)' to local profile Modules folder..."
                Copy-Item $_.FullName (Join-Path $ModuleDir $_.Name) -Recurse -Force
            }
    }
}

# Dot source functions
#
# Dot-sourcing ~35 separate files has a real, mostly constant per-file cost
# (observed ~60-200ms/file on this machine, almost certainly EDR scan-on-open
# overhead) that adds up to several seconds total. To avoid that, most files
# are concatenated into a single cached file that gets dot-sourced once, and
# only regenerated when the set of source files or their content changes.
#
# A few files are deliberately excluded from combination because they rely on
# $PSScriptRoot/$PSCommandPath resolving to *their own* file's location (e.g.
# to find a sibling folder, or to re-invoke themselves standalone via a
# scheduled task with -NoProfile). Combining them would silently change that
# to the cache file's location instead. If you add a new Functions file that
# depends on $PSScriptRoot, $PSCommandPath, or $MyInvocation.MyCommand.Path,
# add its name to $script:UncombinableFunctionFiles below.
$script:UncombinableFunctionFiles = @(
    'ConvertTo-ASCIIArt.ps1'
    'Update-WinGet.ps1'
    'Use-PromptTheme.ps1'
)

$FunctionsCacheDir = Join-Path $env:LOCALAPPDATA 'psprofile\cache'
$FunctionsCacheFile = Join-Path $FunctionsCacheDir 'functions-combined.ps1'

$functionFolders = (Join-Path $PSScriptRoot 'Functions'), (Join-Path $PSScriptRoot "${env:COMPUTERNAME}\Functions") |
    Where-Object { Test-Path $_ }

$allFunctionFiles = $functionFolders | ForEach-Object { Get-ChildItem (Join-Path $_ '*.ps1') }
$combinableFiles = $allFunctionFiles | Where-Object { $_.Name -notin $script:UncombinableFunctionFiles }
$uncombinableFiles = $allFunctionFiles | Where-Object { $_.Name -in $script:UncombinableFunctionFiles }

# Cheap signature (name + last-write-time per file) to detect added/removed/modified
# files without reading file contents.
$signature = ($combinableFiles | Sort-Object FullName | ForEach-Object { "$($_.FullName):$($_.LastWriteTimeUtc.Ticks)" }) -join '|'
$cachedSignature = if (Test-Path $FunctionsCacheFile) { (Get-Content $FunctionsCacheFile -TotalCount 1) -replace '^# SIGNATURE: ', '' } else { $null }

if ($signature -ne $cachedSignature) {
    if (-not (Test-Path $FunctionsCacheDir)) {
        New-Item -ItemType Directory -Path $FunctionsCacheDir -Force | Out-Null
    }
    $combined = New-Object System.Text.StringBuilder
    [void]$combined.AppendLine("# SIGNATURE: $signature")
    foreach ($file in $combinableFiles) {
        [void]$combined.AppendLine("# --- $($file.FullName) ---")
        [void]$combined.AppendLine((Get-Content $file.FullName -Raw))
    }
    Set-Content -Path $FunctionsCacheFile -Value $combined.ToString() -NoNewline
}

if ($combinableFiles) {
    . $FunctionsCacheFile
}
foreach ($file in $uncombinableFiles) {
    . $file.FullName
}

# Write banner
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

# Import-RequiredModule Figlet + Write-Figlet costs roughly 1.2-1.4s on this machine
# (almost entirely the module import - Figlet is a compiled .NET module bundling ~150
# font .zip files). The rendered banner only ever changes if the hostname or font
# changes, so the plain (uncolored) ASCII art is cached to a local, non-git,
# machine-specific file and reused on every startup after the first; colors are still
# applied fresh each run based on the current $IsAdmin state.
#
# Write-Figlet writes its colored output directly to the host UI rather than through
# the normal success/output stream, so it can't be captured by piping to Out-String in
# this process - capturing it requires real stdout redirection from a separate
# process. That one-time cost only happens on a cache miss (first run on a machine, or
# after the hostname/font changes).
$FigletFont = 'big'
$FigletCacheDir = Join-Path $env:LOCALAPPDATA 'psprofile\cache'
$FigletCacheFile = Join-Path $FigletCacheDir "figlet-$script:ComputerName-$FigletFont.txt"

if (-not (Test-Path $FigletCacheFile) -or (Get-Item $FigletCacheFile).Length -eq 0) {
    if (-not (Test-Path $FigletCacheDir)) {
        New-Item -ItemType Directory -Path $FigletCacheDir -Force | Out-Null
    }
    # $env:PSModulePath already includes $ModuleDir (set above) and is inherited by
    # this child process, so Figlet resolves by name without a hardcoded version path.
    # Casting the Write-Figlet result to [string] gives the plain rendered text
    # (ToString(), no color codes) directly, avoiding the extra blank separator lines
    # that Out-String/default formatting inserts between rows.
    $genScript = "Import-Module Figlet; [string](Write-Figlet '$script:ComputerName' -Font $FigletFont)"
    & pwsh -NoProfile -Command $genScript *> $FigletCacheFile
}

Get-Content $FigletCacheFile | ForEach-Object {
    Write-Host $_ -ForegroundColor ($IsAdmin ? 'Red' : 'Blue')
}

# Configure environment variables
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

# posh-git's module import costs ~2.3s here - the single largest startup cost
# measured on this machine, bigger than the Figlet import or Functions dot-source
# combined. Its prompt integration isn't used (customprompt.ps1 has its own
# git-status logic), only its git/tgit/gitk tab completion, so instead of importing
# it eagerly every startup, register a lightweight stub completer that imports the
# real module (and pays that cost) only the first time a git command is actually
# tab-completed in a session - which may never happen. Register-ArgumentCompleter
# replaces any existing registration for the same command name, and posh-git
# registers its own real completer for the same commands when it imports, so after
# the first real completion, subsequent ones go straight to posh-git's own
# implementation, not this stub.
# To back this out: replace this block with `Import-RequiredModule posh-git`.
Register-ArgumentCompleter -CommandName git, tgit, gitk, g -Native -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    if (-not (Get-Module posh-git)) {
        Import-Module posh-git
    }
    $padLength = $cursorPosition - $commandAst.Extent.StartOffset
    $textToComplete = $commandAst.ToString().PadRight($padLength, ' ').Substring(0, $padLength)
    Expand-GitCommand $textToComplete
}

# if (Get-Module PowerLocation -ListAvailable) {
#     Import-Module PowerLocation
#     Set-Alias -Name z -Value Set-PowerLocation
# }

. $PSScriptRoot/customprompt.ps1

. (Join-Path $PSScriptRoot psreadlinecfg.ps1)

# Setup our DynamicTitle
#. (Join-Path $PSScriptRoot DynamicTitle.ps1)

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Setup fzf
    Import-RequiredModule PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -PSReadlineChordSetLocation 'Ctrl+l'
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    $_fzf_bat_cmd = 'bat --color=always --line-range :100 {}'
    $_fzf_fd_all_cmd = 'fd -tf -td -tl {0}' -f $env:FD_OPTIONS
    $env:FZF_DEFAULT_OPTS = "--prompt '⯈ ' --height 50% --layout=reverse --border --color=dark --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7"
    $env:FD_OPTIONS = '--hidden --follow'
    $env:FZF_DEFAULT_COMMAND = $_fzf_fd_all_cmd
    $env:FZF_CTRL_T_OPTS = "--preview `"$_fzf_bat_cmd`""
    $env:FZF_CTRL_T_COMMAND = $_fzf_fd_all_cmd

    Set-Alias -Name fe -Value Invoke-FuzzyEdit
    Set-Alias -Name fgs -Value Invoke-FuzzyGitStatus
    Set-Alias -Name fh -Value Invoke-FuzzyHistory
    Set-Alias -Name fkill -Value Invoke-FuzzyKillProcess
    Set-Alias -Name fcd -Value Invoke-FuzzySetLocation
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Setup zoxide. The `zoxide init` output is cached to disk (see Invoke-CachedInit)
    # so most startups just read a file instead of spawning a process - each spawned
    # process on this machine gets EDR-intercepted, adding real latency.
    # To back this out: replace the Invoke-CachedInit call with
    #   Invoke-Expression (& { (zoxide init powershell --cmd z --hook pwd | Out-String) })
    Invoke-CachedInit -Name 'zoxide-init' -SourceCommand zoxide -Generate {
        zoxide init powershell --cmd z --hook pwd | Out-String
    }
    Set-Alias -Name cd -Value z -Option AllScope
    Register-ArgumentCompleter -CommandName z -Native -ScriptBlock {
        param($stringMatch)
        $zquery = zoxide query -l $stringMatch
        $iquery = Get-ChildItem "$stringMatch*" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }
        @($zquery) + @($iquery) | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    $env:_ZO_FZF_OPTS = $env:FZF_DEFAULT_OPTS
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    # Setup bat
    $env:BAT_THEME = 'Nord'
    $env:BAT_STYLE = 'changes,header,numbers'
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Set-Alias -Name cld -Value claude
    function cldy {
        claude --dangerously-skip-permissions $args
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

if (Get-Command -Name dsc -ErrorAction SilentlyContinue) {
    # The `dsc completer` output is cached to disk (see Invoke-CachedInit) so most
    # startups just read a file instead of spawning a process - each spawned process
    # on this machine gets EDR-intercepted, adding real latency.
    # To back this out: replace the Invoke-CachedInit call with
    #   dsc completer powershell | Out-String | Invoke-Expression
    Write-Host -ForegroundColor Blue "Registering argument completer for 'dsc'..."
    Invoke-CachedInit -Name 'dsc-completer' -SourceCommand dsc -Generate {
        dsc completer powershell | Out-String
    }
}

if (Get-Command -Name winget -ErrorAction SilentlyContinue) {
    Write-Host -ForegroundColor Blue "Registering argument completer for 'winget'..."
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
else {
    Write-Information "Command 'winget' not found."
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

if (Get-Command -Name npm -ErrorAction SilentlyContinue) {
    if ($env:PATH -notlike "*npm*") {
        $env:PATH += "; $(npm config get prefix)"
    }
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

# Source ~/.container/profile.ps1 if we're running in a container
if ((Test-Path '/.dockerenv') -and (Test-Path ~/.container/profile.ps1)) {
    . ~/.container/profile.ps1
}

if (Get-Command -Name flightplan -ErrorAction SilentlyContinue) {
    Set-Alias -Name fp -Value flightplan
}

# Display notice if there's profile changes
# git status is fast (local); git fetch runs in a background process (not a PowerShell
# job - Start-Job requires a runspace and fails under ConstrainedLanguage mode, which is
# enforced on some locked-down machines) to avoid blocking startup.
Push-Location $ProfileDir
try {
    if (Get-Command -Name git -ErrorAction SilentlyContinue) {
        if (-not (git status | Select-String 'nothing to commit')) {
            Write-Warning 'Profile changes need to be committed and pushed'
        }
        else {
            try {
                $global:_ProfileGitFetchOutLog = [System.IO.Path]::GetTempFileName()
                $global:_ProfileGitFetchErrLog = [System.IO.Path]::GetTempFileName()
                $global:_ProfileGitFetchProcess = Start-Process -FilePath git -ArgumentList 'fetch' `
                    -WorkingDirectory $ProfileDir -WindowStyle Hidden -PassThru `
                    -RedirectStandardOutput $global:_ProfileGitFetchOutLog -RedirectStandardError $global:_ProfileGitFetchErrLog
            }
            catch {
                Remove-Item $global:_ProfileGitFetchOutLog, $global:_ProfileGitFetchErrLog -Force -ErrorAction SilentlyContinue
                $global:_ProfileGitFetchOutLog = $null
                $global:_ProfileGitFetchErrLog = $null
                $global:_ProfileGitFetchProcess = $null
            }
        }
    }
}
finally {
    Pop-Location
}

# Wrap prompt to display the fetch result once the background process completes
# NOTE: capture the ScriptBlock (not the FunctionInfo) - invoking a FunctionInfo via
# `&` re-resolves "prompt" by name, which after Set-Item below would recurse into the
# wrapper itself and blow the call stack instead of calling the original prompt.
$global:_origPromptFn = (Get-Item Function:\prompt).ScriptBlock
Set-Item Function:\prompt -Value {
    if ($global:_ProfileGitFetchProcess -and $global:_ProfileGitFetchProcess.HasExited) {
        try {
            Push-Location $ProfileDir
            $ahead = [int](git rev-list --count origin..HEAD 2>$null)
            $behind = [int](git rev-list --count HEAD..origin 2>$null)
            if ($ahead -gt 0) {
                Write-Warning 'Local profile changes need to be pushed'
            }
            elseif ($behind -gt 0) {
                Write-Warning 'Remote profile changes need to be merged'
            }
        }
        finally {
            Pop-Location
            Remove-Item $global:_ProfileGitFetchOutLog, $global:_ProfileGitFetchErrLog -Force -ErrorAction SilentlyContinue
            $global:_ProfileGitFetchProcess = $null
            $global:_ProfileGitFetchOutLog = $null
            $global:_ProfileGitFetchErrLog = $null
        }
    }
    & $global:_origPromptFn
}

# Copilot aliases
if (Get-Command -Name copilot -ErrorAction SilentlyContinue) {
    function co { copilot --model claude-sonnet-4.5 @args }
    function coy { copilot --model claude-sonnet-4.5 --allow-all-tools @args }
    function coh { copilot --model claude-haiku-4.5 @args }
    function cohy { copilot --model claude-haiku-4.5 --allow-all-tools @args }
    function cog { copilot --model gpt-5 @args }
    function cogy { copilot --model gpt-5 --allow-all-tools @args }
}

function pd { Set-Location $ProfileDir }
function ep { code $ProfileDir }