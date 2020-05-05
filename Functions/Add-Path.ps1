function Add-Path {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $True)]
        [string[]]$Path,

        [Parameter(Mandatory = $False, ParameterSetName='name')]
        [string]$Name = 'env:Path',

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ParameterSetName='pathspec')]
        [string]$Pathspec,

        [switch]$Front
    )

    begin {
        $Path = $Path | ForEach-Object { Resolve-Path $_ }
        if ($PSCmdlet.ParameterSetName -eq 'name') {
            $isEnv = $Name.StartsWith('env:', 'CurrentCultureIgnoreCase')
            if ($isEnv) {
                $Name = $Name.Substring(4)
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'name') {
            if ($isEnv) {
                $pathspec = (Get-Item "env:$Name").Value
            }
            else {
                $pathspec = Get-Variable -Name $Name
            }
        }
        $paths = $Pathspec -split ';' | Where-Object { $_ -and -not ($Path -contains $_) }
        if ($Front) {
            $paths = $Path + $paths
        }
        else {
            $paths += $Path
        }
        $Pathspec = ($paths | Where-Object { Test-Path $_ } | Select-Object -Unique) -join ';'
        if ($PSCmdlet.ParameterSetName -eq 'name') {
            if ($isEnv) {
                Set-Item "env:$Name" $pathspec
            }
            else {
                Set-Variable -Name $Name -Value $pathspec
            }
        }
        else {
            $Pathspec
        }
    }

    end {
    }
}