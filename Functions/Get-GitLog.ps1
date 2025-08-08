class GitLogChange {
    [int]$Add
    [int]$Delete
    [string]$File

    GitLogChange([int]$add, [int]$delete, [string]$file) {
        $this.Add = $add
        $this.Delete = $delete
        $this.File = $file
    }
}

class GitLogEntry {
    [string]$Revision
    [DateTime]$Date
    [string]$Committer
    [string]$Subject
    [GitLogChange[]]$Changes = @()

    GitLogEntry([string]$revision, [DateTime]$date, [string]$committer, [string]$subject) {
        $this.Revision = $revision
        $this.Date = $date
        $this.Committer = $committer
        $this.Subject = $subject
    }
}

function Get-GitLog {
    [CmdletBinding()]
    param (
    )
    
    begin {
    }
    
    process {
        [GitLogEntry]$item = $null
        git log --all -M -C --numstat --date=iso --pretty=format:'--%h--%cd--%cn--%s' | ForEach-Object {
            $line = $_
            if ($line) {
                if ($line.StartsWith('--')) {
                    if ($item) {
                        $item
                    }
                    $parts = $line -split '--'
                    $item = [GitLogEntry]::new($parts[1], [DateTime]($parts[2]), $parts[3], $parts[4])
                }
                else {
                    $parts = $line -split '\s+'
                    $change = [GitLogChange]::new([int]($parts[0]), [int]($parts[1]), $parts[2])
                    $item.Changes += $change
                }
            }
        }
    }
    
    end {
    }
}