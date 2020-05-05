function Update-SampleFile {
    [CmdletBinding()]
    param (
        $Path = (Join-Path (Get-Location) 'Sample.txt')
    )
    
    begin {
        
    }
    
    process {
        $quote = Get-Quote
        if (Test-Path $Path) {
            Add-Content -Path $Path -Value "---`n`n$quote"
        } else {
            Set-Content -Path $Path -Value $quote
        }
    }
    
    end {
        
    }
}