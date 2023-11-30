function Use-PromptTheme {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name
    )
    $locations = @((Resolve-Path $PSScriptRoot/../PoshThemes), $env:POSH_THEMES_PATH)
    $theme = $null
    foreach ($location in $locations) {
        if (Test-Path (Join-Path $location "$Name.omp.json")) {
            $theme = Join-Path $location "$Name.omp.json"
            break
        }
        if (Test-Path (Join-Path $location "$Name.json")) {
            $theme = Join-Path $location "$Name.json"
            break
        }
    }

    if ($theme) {
        oh-my-posh init pwsh --config $theme | Invoke-Expression
    }
}