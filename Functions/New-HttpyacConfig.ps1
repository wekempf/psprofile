function New-HttpyacConfig {
    [CmdletBinding()]
    param (
        [string]$Path = (Get-Location)
    )

    begin {
        if ($env:HTTP_PROXY -or $env:HTTPS_PROXY -or $env:REQUESTS_CA_BUNDLE) {
            throw "Please run Use-RequestsCert -Remove first"
        }
        $script:stsResult = & aws sts get-caller-identity 2> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Please use steam login first"
        }

        function GetValue($Key, $Account, $Region) {
            $cmd = "aws --region $(if ($region -eq 'e1') { 'us-east-1' } else { 'us-east-2' })"
            $Key = $Key -replace '144', $Account -replace 'e1', $Region
            if ($key.StartsWith("par")) {
                $cmd += " ssm get-parameters --names $Key"
            }
            else {
                $cmd += " secretsmanager get-secret-value --secret-id $Key"
            }
            $response = Invoke-Expression $cmd | ConvertFrom-Json -AsHashtable
            if ($key.StartsWith("par")) {
                $response.Parameters[0].Value
            }
            else {
                $response.SecretString | ConvertFrom-Json -AsHashtable
            }
        }

        function GetOrAdd($Hash, $Key) {
            if (-not $Hash.ContainsKey($Key)) {
                $Hash[$Key] = @{}
            }
            $Hash[$Key]
        }
    
        $script:keys = @{
            'par-001-s-144-e1-00-dev-cognito-token-endpoint' = 'token_url'
        }
        $script:privkeys = @{
            'secret-001-s-144-e1-00-dev-cognito-mfa-integrations-client-secret' = @{
                'token_appclientid' = 'AppClientId'
                'token_credential'  = 'Credential'
            }
        }
        $script:sts = $stsResult | ConvertFrom-Json -AsHashtable
        ($script:part, $script:acct) = $(if ($sts.Arn -match 'arn:aws:sts::.+:assumed-role/role-(\d+)-s-(\d+)') { ($matches[1], $matches[2]) })
        $script:envs = @{
            '144' = 'dev'
            '145' = 'test'
            '146' = 'prod'
        }
        $script:env = $envs[$acct]
        if ($part -eq '500') {
            $env += $part
        }
        Write-Host "Using environment: $env"
    }
    
    process {
        Push-Location $Path
        try {
            New-Item -ItemType Directory -Name 'env' -ErrorAction SilentlyContinue | Out-Null
            Set-Location 'env'
            if (Test-Path 'http-client.env.json') {
                $script:config = Get-Content 'http-client.env.json' | ConvertFrom-Json -AsHashtable
            }
            else {
                $script:config = @{}
            }
            if (Test-Path 'http-client.private.env.json') {
                $script:privconfig = Get-Content 'http-client.private.env.json' | ConvertFrom-Json -AsHashtable
            }
            else {
                $script:privconfig = @{}
            }
            foreach ($region in @('e1', 'e2')) {
                foreach ($key in $keys.GetEnumerator()) {
                    $script:paramValue = GetValue $key.Key $acct $region
                    $configEnv = GetOrAdd $config "$env-$region"
                    $configEnv[$key.Value] = $paramValue
                    if ($region -eq 'e1') {
                        $configEnv = GetOrAdd $config $env
                        $configEnv[$key.Value] = $paramValue
                    }
                }
                foreach ($key in $privkeys.GetEnumerator()) {
                    $script:secretString = GetValue $key.Key $acct $region
                    $configEnv = GetOrAdd $privconfig "$env-$region"
                    foreach ($prop in $key.Value.GetEnumerator()) {
                        $configEnv[$prop.Key] = $secretString[$prop.Value]
                    }
                    if ($region -eq 'e1') {
                        $configEnv = GetOrAdd $privconfig $env
                        foreach ($prop in $key.Value.GetEnumerator()) {
                            $configEnv[$prop.Key] = $secretString[$prop.Value]
                        }
                    }
                }
            }
            $config | ConvertTo-Json | Write-Host
            $privconfig | ConvertTo-Json | Write-Host
        }
        finally {
            Pop-Location
        }
        
    }
    
    end {
        
    }
}