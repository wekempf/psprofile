function Set-SimplePrompt([switch]$Off) {
    if ($Off) {
        Remove-Variable -Name SimplePrompt -Scope Global -ErrorAction SilentlyContinue
    }
    else {
        Set-Variable -Name SimplePrompt -Value $true -Scope Global
    }
}
Set-Alias -Name ssp -Value Set-SimplePrompt

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
        
function prompt {
    $oldDollarQuestion = $global:?
    #$oldLastExitCode = $global:LASTEXITCODE

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

            for ($n = 1; $n -lt $parts.Length - 1; $n++) {
                if ($parts[$n].Length -le 3) {
                    continue
                }
                $parts[$n] = '...'
                $path = $parts -join $sep
                if ($path.Length -le $MaxLength) {
                    break
                }
            }
        }
        return $path
    }

    function Format-TimeSpan {
        param([TimeSpan]$TimeSpan)
        
        $parts = @()
        if ($TimeSpan.Days -gt 0) { $parts += "$($TimeSpan.Days)d" }
        if ($TimeSpan.Hours -gt 0) { $parts += "$($TimeSpan.Hours)h" }
        if ($TimeSpan.Minutes -gt 0) { $parts += "$($TimeSpan.Minutes)m" }
        if ($TimeSpan.Seconds -gt 0) { $parts += "$($TimeSpan.Seconds)s" }
        if ($TimeSpan.Milliseconds -gt 0 -and $TimeSpan.TotalSeconds -lt 60) { 
            $parts += "$($TimeSpan.Milliseconds)ms" 
        }
        
        return $parts -join ' '
    }
    
    if ($env:TERM_PROGRAM -ne 'vscode') {
        $sixel = "`eP0;1q`"1;1;26;20#1;2;89;91;91#2;2;71;77;83#3;2;60;64;77#4;2;50;61;75#5;2;33;42;56#6;2;16;24;36#7;2;13;19;30#8;2;8;14;20#9;2;5;8;11#10;2;2;2;3#1???oE???Ooo_#7?ow[[CC#4!5AC`$#3!4?O?!13A!5?G`$#2!4?GA???G#8!5?__ww{{[CS#2q`$#5!4?_C#4??g#9!12?_wG`$#6!5?w{{CCK[{KC!8?_-#5???O@!4?_!4?_W!6?O@`$#1??wB!6?``b}{W#9?ow{}NFF`$#6???_}~^NDAO#8???@fNFB@#10ow#4_A`$???G!5?@#2AS@A!9?[@`$#3???C#7??_oy[KG?@A!7?G`$#3!14?C-#5??C??C?O??CAK!5?C??G`$#3?_@???O?@???@!5?G??O`$#1?E!4?KMEBB@?!5K#2???_N`$?W!7?C#9_oo_aBBB@?_`$#6??GJ@OA??G???POOO!4?C`$#7??os}B@@O???A!4?O`$#4??A??G??G#10!6?___a~^@`$#8!5?!4_oWK?A@???O??A-#2?@#3@@#4!16@#3@#2@`e\`e[3C "
    }
    else {
        $sixel = ''
    }
    try {
        if ($global:SimplePrompt) {
            return "PS> "
        }
    
        $path = "$($IsAdmin ? $PSStyle.Foreground.Red : $PSStyle.Foreground.Cyan)$(Get-ShortPath 15)$($PSStyle.Reset)"
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $branch = (git rev-parse --abbrev-ref HEAD 2>$null)
            if ($branch) {
                $dirty = (git status --porcelain 2>$null) ? " `u{2728}" : ''
                $gitstatus = " $($PSStyle.Foreground.Yellow)($branch$dirty)$($PSStyle.Reset)"
            }
            else {
                $gitstatus = ''
            }
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
        #if (($oldLastExitCode -ne 0) -or ($oldDollarQuestion -eq $false)) {
        if ($oldDollarQuestion -eq $false) {
            $failure = "$($PSStyle.Foreground.Red)`u{1F4A5}$($PSStyle.Reset)"
        }
        else {
            $failure = ''
        }
        $arrow = "$($IsAdmin ? $PSStyle.Foreground.Red : $PSStyle.Foreground.Blue)$([char]0x2192)$($PSStyle.Reset)"
        $history = Get-History | Select-Object -Last 1
        if ($history -and $history.Duration.TotalMilliseconds -gt 500) {
            $duration = "`u{1F550} $($PSStyle.Foreground.Green)($(Format-TimeSpan $history.Duration))$($PSStyle.Reset)"
        }
        else {
            $duration = ''
        }
    
        # Full prompt
        $prompt = "$path$gitStatus$awsIdentity"
        $prompt = (Get-ContentLength $prompt) -gt ($Host.UI.RawUI.WindowSize.Width / 2) ? "$prompt`n$arrow " : "$prompt $arrow "
        $lastStatus = "$((@($duration, $failure) | Where-Object { $_ }) -join ' ')"
        $lastStatus = $lastStatus ? "`n$lastStatus`n" : ''
        "$lastStatus$sixel$prompt"
    }
    finally {
        $global:LASTEXITCODE = $oldLastExitCode
    }
}