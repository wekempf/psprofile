function Invoke-WithEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [hashtable]$Environment,

        [Parameter(Mandatory, Position = 1)]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    $originalEnv = @{}
    foreach ($key in $Environment.Keys) {
        $originalEnv[$key] = [System.Environment]::GetEnvironmentVariable($key)
        [System.Environment]::SetEnvironmentVariable($key, $Environment[$key])
    }

    try {
        & $Command @Arguments
    }
    finally {
        foreach ($key in $originalEnv.Keys) {
            [System.Environment]::SetEnvironmentVariable($key, $originalEnv[$key])
        }
    }
}