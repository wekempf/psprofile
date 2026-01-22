function Edit-Notes {
    [CmdletBinding()]
    param ()
    
    Push-Location ~
    try {
        if (-not (Test-Path 'Notes')) {
            git clone https://github.com/wekempf/notes.git Notes
        }
        code 'Notes'
    }
    finally {
        Pop-Location
    }
}

Set-Alias -Name 'Notes' -Value Edit-Notes