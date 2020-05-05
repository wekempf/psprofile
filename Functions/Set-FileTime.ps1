function Set-FileTime {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string[]]$Path
    )

    begin {
    }

    process {
        $Path | ForEach-Object {
            $file = $_
            if (Test-Path $file) {
                Set-ItemProperty -Path $file -Name LastWriteTime -Value (Get-Date) | Out-Null
            }
            else {
                New-Item -Path $file -ItemType File | Out-Null
            }
        }
    }

    end {
    }
}

Set-Alias -Name touch -Value Set-FileTime