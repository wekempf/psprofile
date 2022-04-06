function Edit-Module {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        $Name
    )
    
    begin {
        if (-not (Get-Command -Name code -ErrorAction SilentlyContinue)) {
            throw "Editing a module project requires Visual Studio Code which cannot be located."
        }
    }
    
    process {
        if (-not $Name) {
            code $ModuleDir
        } else {
            code (Split-Path (Resolve-Path (Get-Module $Name -ListAvailable -ErrorAction Stop).Path))
        }
    }
    
    end {
        
    }
}

Set-Alias -Name mod -Value Edit-Module