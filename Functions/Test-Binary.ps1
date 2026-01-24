function Test-Binary {
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]
        $Path
    )

    process {
        $lines = Get-Content -Path $Path -TotalCount 1024
        foreach ($line in $lines) {
            foreach ($ch in $line.ToCharArray()) {
                if ([char]::IsControl($ch) -and $ch -ne [char]0x0A -and $ch -ne [char]0x0D) {
                    return $true
                }
            }
        }

        return $false
    }
}