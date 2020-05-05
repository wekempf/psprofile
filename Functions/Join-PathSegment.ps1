function Join-PathSegment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string[]]$Segment
    )

    begin {
    }

    process {
        $result = $Segment[0]
        $Segment[1..($Segment.Length-1)] | ForEach-Object { $result = Join-Path $result $_ }
        $result
    }

    end {
    }
}