function Connect-Aws {
    [CmdletBinding(DefaultParameterSetName = 'Account')]
    param (
        [Parameter(ParameterSetName = 'Account', Position = 0, Mandatory)]
        [int]$Account,

        [Parameter(ParameterSetName = 'Account')]
        [switch]$Default,

        [Parameter(ParameterSetName = 'Last', Mandatory)]
        [switch]$Last,

        [Parameter(ParameterSetName = 'Profile', Mandatory)]
        [string]$ProfileName,

        [Parameter(ParameterSetName = 'Role', Mandatory)]
        [switch]$Roles
    )

    if (-not (Get-Command steam)) {
        Write-Error "The 'steam' command is not available. Please install the 'steam' command."
        return
    }

    switch ($PSCmdlet.ParameterSetName) {
        'Account' {
            $cmd = "steam login --account $Account"
            if ($Default) {
                $cmd += " --default"
            }
            Invoke-Expression $cmd
        }

        'Last' {
            & steam login --last
        }

        'Profile' {
            & steam --profile $Profile
        }

        'Role' {
            & steam login --roles
        }
    }
}

function Disconnect-Aws {
    Remove-Item ~/.aws/credentials
}

function Get-AwsIdentity {
    [CmdletBinding()]
    param()

    if (Test-Path ~/.aws/credentials) {
        $credsContent = Get-Content ~/.aws/credentials
        $expirationText = $credsContent | Select-String 'aws_session_expiration'
        $expiration = [DateTimeOffset]($expirationText -split '=')[1].Trim().Substring(0, 25)
        if ([DateTimeOffset]::UtcNow -lt $expiration) {
            $identityLastWriteTime = (Get-Item ~/.aws/identity.json -ErrorAction SilentlyContinue).LastWriteTime ?? [DateTime]::MinValue
            $credsLastWriteTime = (Get-Item ~/.aws/credentials -ErrorAction SilentlyContinue).LastWriteTime
            if ($identityLastWriteTime -lt $credsLastWriteTime) {
                $cmds = @(
                    "Remove-Item env:/HTTP_PROXY -ErrorAction SilentlyContinue",
                    "Remove-Item env:/HTTPS_PROXY -ErrorAction SilentlyContinue",
                    "aws sts get-caller-identity > ~/.aws/identity.json"
                    "if (`$LASTEXITCODE -ne 0) { Remove-Item ~/.aws/identity.json }"
                )
                $cmd = $cmds -join '; '
                & (Get-Process -Id $pid).Path -NoProfile -Command $cmd
            }
            if (Test-Path ~/.aws/identity.json) {
                $identity = Get-Content ~/.aws/identity.json | ConvertFrom-Json -AsHashtable
                if ($identity.Arn -match 'arn:aws:sts::(\d+):assumed-role/role-(\d+)-s-(\d+)-(.+)-.+-.+-(.+)/(.+)') {
                    @{
                        AwsAccount  = $Matches[1]
                        Partition   = $Matches[2]
                        Account     = $Matches[3]
                        Region      = $Matches[4]
                        Environment = $Matches[5]
                        User        = $Matches[6]
                    }
                }
            }
        }
    }
}
