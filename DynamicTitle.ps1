# https://mdgrs.hashnode.dev/building-your-own-terminal-status-bar-in-powershell
Import-RequiredModule DynamicTitle

$promptCallback = Start-DTJobPromptCallback {
    (Get-Location).Path
}

Start-DTTitle {
    param($promptCallback)
    $currentDir = Get-DTJobLatestOutput $promptCallback
    if (-not $currentDir) {
        return
    }

    Set-Location $currentDir
    $branch = git branch --show-current
    if ($LASTEXITCODE -ne 0) {
        return '📂 {0}' -f $currentDir
    }
    
    if (-not $branch) {
        $branch = '❔'
    }

    $gitStatusLines = git --no-optional-locks status -s
    $modifiedCount = 0
    $unversionedCount = 0
    foreach ($line in $gitStatusLines) {
        $type = $line.Substring(0, 2)
        if (($type -eq ' M') -or ($type -eq ' R')) {
            $modifiedCount++
        }
        elseif ($type -eq '??') {
            $unversionedCount++
        }        
    }
    $currentDirName = Split-Path $currentDir -Leaf
    '📂 {0} 🌿 [{1}] ✏️ {2} ❔ {3}' -f $currentDirName, $branch, $modifiedCount, $unversionedCount
} -ArgumentList $promptCallback