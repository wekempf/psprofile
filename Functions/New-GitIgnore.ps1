#requires -Version 3

function New-GitIgnore {
    param(
        [Parameter(Mandatory=$true)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $templates = Invoke-WebRequest 'https://www.toptal.com/developers/gitignore/api/list' |
                Select-Object -ExpandProperty Content
            return $templates.Split() -join ',' -split ',' | Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string[]]$Template,
        [switch]$PassThru
    )

    $params = ($Template | ForEach-Object { [uri]::EscapeDataString($_) }) -join ','
    $content = Invoke-WebRequest -Uri "https://www.toptal.com/developers/gitignore/api/$params" |
        Select-Object -ExpandProperty Content
    if ($PassThru) {
        $content
    }
    else {
        $content | Out-File -FilePath $(Join-Path -Path $pwd -ChildPath ".gitignore") -Encoding ascii
    }
}

Set-Alias -Name gig -Value New-GitIgnore