#requires -version 5.1

<#
font list at https://artii.herokuapp.com/fonts_list
font names are case-sensitive

invoke-restmethod https://artii.herokuapp.com/fonts_list

#>

Function ConvertTo-ASCIIArt {
    [cmdletbinding()]
    [alias("cart")]
    [outputtype([System.String])]
    Param(
        [Parameter(Position = 0, Mandatory, HelpMessage = "Enter a short string of text to convert", ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$Text,
        [Parameter(Position = 1,HelpMessage = "Specify a font from https://artii.herokuapp.com/fonts_list. Font names are case-sensitive")]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            (Invoke-WebRequest https://artii.herokuapp.com/fonts_list).Content.Split() |
                Where-Object { $_ -like "$wordToComplete*" }
        })]
        [string]$Font = "big",
        [switch]$Cache
    )

    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN] Starting $($myinvocation.mycommand)"
    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Processing $text with font $Font"
        $cacheDir = "$PSScriptRoot/ascii-cache"
        $fileName = "$($text -replace '[^\w]','_').art"
        $filePath = Join-Path $cacheDir $Font $fileName
        if (Test-Path $filePath) {
            Write-Verbose 'Returning cached art...'
            Get-Content $filePath | Out-String
        }
        else {
            Write-Verbose 'Getting art...'
            $encoded = [uri]::EscapeDataString($Text)
            $url = "http://artii.herokuapp.com/make?text=$encoded&font=$Font"
            try {
                $art = Invoke-Restmethod -Uri $url -DisableKeepAlive -ErrorAction Stop
                if ($Cache) {
                    Write-Verbose 'Caching art...'
                    New-Item -Path (Join-Path $cacheDir $Font) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                    Set-Content -Path $filePath -Value $art
                }
                $art
            }
            catch {
                throw $_
            }
        }
    } #process
    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
    } #end
}