function Split-PathSegment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string]$Path
    )

    begin {
    }

    process {
        $parent = Split-Path $Path
        if (-not $parent) {
            $Path
        }
        else {
            @(Split-PathSegment $parent) + (Split-Path $path -Leaf)
        }
    }

    end {
    }
}