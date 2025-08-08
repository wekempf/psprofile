function Invoke-Solution {
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location)
    )

    function PushLocation {
        param(
            [string]$Path,
            [scriptblock]$ScriptBlock
        )

        Push-Location $Path -ErrorAction Stop
        try {
            & $ScriptBlock
        }
        finally {
            Pop-Location
        }
    }

    $Path = Resolve-Path $Path
    Write-Debug "Path: $Path"
    if (Test-Path $Path -Type Leaf) {
        Write-Debug 'File specified'
        if ($Path -notmatch '\.sln$') {
            Write-Error "The path '$Path' is not a solution file."
            return
        }
        PushLocation (Split-Path $Path -Parent) {
            $script:root = git rev-parse --show-toplevel
        }
    }
    else {
        Write-Debug 'Directory specified'
        PushLocation $Path {
            $script:root = git rev-parse --show-toplevel
        }
    }
    Write-Debug 'Root: $script:root'

    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $dataFile = Join-Path $localAppData 'Invoke-Solution.json'
    Write-Debug "DataFile: $dataFile"
    $data = (Get-Content $dataFile -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable) ?? @{}
    if ($data.ContainsKey($script:root)) {
        Write-Debug "Solution found in cache: $($data[$script:root])"
        & $data[$script:root]
        return
    }
    else {
        PushLocation $script:root {
            $sln = Get-ChildItem -Filter '*.sln' -Recurse -ErrorAction SilentlyContinue
            if (-not $sln) {
                Write-Error "No solution file found in the directory '$script:root'."
                return
            }
            if (@($sln).Count -gt 1) {
                Write-Error "Multiple solution files found in the directory '$script:root'. Please specify a path to the solution file to use for this repo."
                return
            }
            Write-Debug "Solution found: $($sln.FullName)"
            $data[$script:root] = $sln.FullName
            $json = $data | ConvertTo-Json
            Set-Content -Path $dataFile -Value $json -Force -ErrorAction Stop
            & $sln.FullName
            return
        }
    }
}

Set-Alias -Name sln -Value Invoke-Solution