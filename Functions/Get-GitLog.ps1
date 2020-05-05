function Get-GitLog {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
    }
    
    process {
        $item = $null
        git log --all -M -C --numstat --date=iso --pretty=format:'--%h--%cd--%cn--%s' | ForEach-Object {
            $line = $_
            if ($line) {
                if ($line.StartsWith('--')) {
                    if ($item) {
                        $item
                    }
                    $parts = $line -split '--'
                    $item = New-Object -TypeName PsObject -Property @{
                        "Revision" = $parts[1]
                        "Date" = [DateTime]($parts[2])
                        "Committer" = $parts[3]
                        "Subject" = $parts[4]
                        "Changes" = @()
                    }
                }
                else {
                    $parts = $line -split '\s+'
                    $change = New-Object -TypeName PsObject -Property @{
                        "Add" = [int]($parts[0])
                        "Delete" = [int]($parts[1])
                        "File" = $parts[2]
                    }
                    $item.Changes += $change
                }
            }
        }
    }
    
    end {
    }
}