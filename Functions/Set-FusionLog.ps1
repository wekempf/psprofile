function Set-FusionLog {
    [CmdletBinding(DefaultParameterSetName = 'Enable')]
    param (
        [Parameter(ParameterSetName = 'Enable')]
        [string]$Path = 'C:\FusionLogs\',

        [Parameter(Mandatory, ParameterSetName = 'Disable')]
        [switch]$Disable,

        [Parameter(ParameterSetName = 'Enable')]
        [switch]$Enable
    )
    
    begin {
        if ($Enable -and (-not $Path.EndsWith('\'))) {
            $Path += '\'
        }
    }
    
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Enable' {
                Write-Verbose "Enabling Fusion logging at path: $Path"
                if (-not (Test-Path -Path $Path)) {
                    Write-Verbose "Creating Fusion log directory at $Path"
                    New-Item -ItemType Directory -Path $Path -Force | Out-Null
                }
                Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name ForceLog -Value 1 -Type DWord
                Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogFailures -Value 1 -Type DWord
                Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogResourceBinds -Value 1 -Type DWord
                Set-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogPath -Value $Path -Type String
            }
            'Disable' {
                Write-Verbose "Disabling Fusion logging."
                Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name ForceLog
                Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogFailures
                Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogResourceBinds
                Remove-ItemProperty -Path HKLM:\Software\Microsoft\Fusion -Name LogPath
            }
        }
    }
    
    end {
        
    }
}