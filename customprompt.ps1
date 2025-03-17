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
    if ($env:TERM_PROGRAM -ne 'vscode') {
        $sixel = "`eP0;1q`"1;1;26;20#1;2;89;91;91#2;2;71;77;83#3;2;60;64;77#4;2;50;61;75#5;2;33;42;56#6;2;16;24;36#7;2;13;19;30#8;2;8;14;20#9;2;5;8;11#10;2;2;2;3#1???oE???Ooo_#7?ow[[CC#4!5AC`$#3!4?O?!13A!5?G`$#2!4?GA???G#8!5?__ww{{[CS#2q`$#5!4?_C#4??g#9!12?_wG`$#6!5?w{{CCK[{KC!8?_-#5???O@!4?_!4?_W!6?O@`$#1??wB!6?``b}{W#9?ow{}NFF`$#6???_}~^NDAO#8???@fNFB@#10ow#4_A`$???G!5?@#2AS@A!9?[@`$#3???C#7??_oy[KG?@A!7?G`$#3!14?C-#5??C??C?O??CAK!5?C??G`$#3?_@???O?@???@!5?G??O`$#1?E!4?KMEBB@?!5K#2???_N`$?W!7?C#9_oo_aBBB@?_`$#6??GJ@OA??G???POOO!4?C`$#7??os}B@@O???A!4?O`$#4??A??G??G#10!6?___a~^@`$#8!5?!4_oWK?A@???O??A-#2?@#3@@#4!16@#3@#2@`e\`e[3C "
    }
    else {
        $sixel = ''
    }
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
        (Get-ContentLength $prompt) -gt ($Host.UI.RawUI.WindowSize.Width / 2) ? "$sixel$prompt`n$arrow " : "$sixel$prompt $arrow "
    }
    finally {
        $global:LASTEXITCODE = $oldLastExitCode
    }
}