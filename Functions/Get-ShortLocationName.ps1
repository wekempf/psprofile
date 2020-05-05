function Get-ShortLocationName {
    $winWidth = $Host.UI.RawUI.WindowSize.Width
    if (-not $winWidth) {
        $winWidth = 80
    }
    $maxWidth = [Math]::Round($winWidth / 3)
    $location = (Get-Location).Path
    $prefix = $HOME
    $sepChar = [System.IO.Path]::DirectorySeparatorChar
    if (-not $prefix.EndsWith($sepChar)) {
        $prefix += $sepChar
    }
    if ($location.StartsWith($prefix)) {
        $location = '~' + $location.Substring($prefix.Length - 1)
    }
    if ($location.Length -ge $maxWidth) {
        $pathParts = Split-PathSegment $location
        $index = 1
        while (($location.Length -ge $maxWidth) -and ($index -lt ($pathParts.Length))) {
            $location = Join-PathSegment (($pathParts[0],"...") + $pathParts[$index..($pathParts.Length - 1)])
            $index += 1
        }
    }
    $location
}