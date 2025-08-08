function Set-NewLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]$Path
    )
    
    New-Item -ItemType Directory -Path $Path -ErrorAction SilentlyContinue | Out-Null
    Set-Location -Path $Path
}

Set-Alias -Name mcd -Value Set-NewLocation