function Get-Encoding {
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string]
        $Path
    )

    process {
        $bom = Get-Content -Path $currFile -Encoding Byte -TotalCount 4
    
        if ($bom[0] -eq 0x2b -and $bom[1] -eq 0x2f -and $bom[2] -eq 0x76) {
            return [Text.Encoding]::UTF7
        }
        elseif ($bom[0] -eq 0xff -and $bom[1] -eq 0xfe) {
            return [Text.Encoding]::Unicode
        }
        elseif ($bom[0] -eq 0xfe -and $bom[1] -eq 0xff) {
            return [Text.Encoding]::BigEndianUnicode
        }
        elseif ($bom[0] -eq 0x00 -and $bom[1] -eq 0x00 -and $bom[2] -eq 0xfe -and $bom[3] -eq 0xff) {
            return [Text.Encoding]::UTF32
        }
        elseif ($bom[0] -eq 0xef -and $bom[1] -eq 0xbb -and $bom[2] -eq 0xbf)  {
            return [Text.Encoding]::UTF8
        }
        else {
            return [Text.Encoding]::ASCII
        }
    }
}