function Set-SimplePrompt([switch]$Off) {
    if ($Off) {
        Remove-Variable -Name SimplePrompt -Scope Global -ErrorAction SilentlyContinue
    }
    else {
        Set-Variable -Name SimplePrompt -Value $true -Scope Global
    }
}
Set-Alias -Name ssp -Value Set-SimplePrompt

# Customize the git status display
$GitPromptSettings.FileAddedText = "`u{1F4BE} "
$GitPromptSettings.FileModifiedText = "`u{270F} "
$GitPromptSettings.FileRemovedText = "`u{1F5D1} "
$GitPromptSettings.WorkingColor.ForegroundColor = 'Cyan'

function prompt {
    $oldDollarQuestion = $global:?
    $oldLastExitCode = $global:LASTEXITCODE
    try {
        if ($global:SimplePrompt) {
            return "PS> "
        }
    
        function Get-ContentLength([string]$Text) {
            [System.Management.Automation.Internal.StringDecorated]::new($Text).ContentLength
        }
    
        function Get-ShortPath([int]$MaxLength) {
            $path = $PWD.Path
            if ($path.StartsWith($HOME)) {
                $path = "~" + $path.Substring($HOME.Length)
            }
            if ($path.Length -gt $MaxLength) {
                $sep = [IO.Path]::DirectorySeparatorChar
                $altSep = [IO.Path]::AltDirectorySeparatorChar
                $parts = $path.Split([char[]]($sep, $altSep))
    
                for ($n = $parts.Length - 1; $n -gt 2; $n--) {
                    $path = $parts[0] + $sep + "..." + $sep + ($parts[($n * -1)..-1] -join $sep)
                    if ($path.Length -le $MaxLength) {
                        break
                    }
                }
            }
            return $path
        }
    
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
        
        # Prompt segments
        $user = "$($IsAdmin ? $PSStyle.Foreground.Red : $PSStyle.Foreground.Blue)$($IsLinux ? $env:LOGNAME : $env:USERNAME)$($PSStyle.Reset)"
        $path = "$($PSStyle.Foreground.Cyan)$(Get-ShortPath 15)$($PSStyle.Reset)"
        if (Get-Command Get-GitStatus -ErrorAction SilentlyContinue) {
            $gitStatus = Write-VcsStatus
        }
        else {
            $gitStatus = ''
        }
        try {
            $awsIdentity = Get-AwsIdentity    
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        if ($awsIdentity) {
            $awsIdentity = " $($PSStyle.Foreground.Yellow)`u{2601}$($PSStyle.Reset)  $($awsIdentity.Environment)"
        }
        else {
            $awsIdentity = ''
        }
        if (($oldLastExitCode -ne 0) -or ($oldDollarQuestion -eq $false)) {
            $failure = " $($PSStyle.Foreground.Red)`u{1F4A5}$($PSStyle.Reset)"
        }
        else {
            $failure = ''
        }
        $arrow = "$($IsAdmin ? $PSStyle.Foreground.Red : $PSStyle.Foreground.Blue)$([char]0x2192)$($PSStyle.Reset)"
    
        # Full prompt
        $prompt = "$user $path$gitStatus$awsIdentity$failure"
        (Get-ContentLength $prompt) -gt ($Host.UI.RawUI.WindowSize.Width / 2) ? "$prompt`n$arrow " : "$prompt $arrow "
    }
    finally {
        $global:LASTEXITCODE = $oldLastExitCode
    }
}