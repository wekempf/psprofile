function Edit-Repo {
    [CmdletBinding(DefaultParameterSetName = 'edit')]
    param(
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'edit')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
                $dataFolder = Join-Path $env:LOCALAPPDATA 'Edit-Repo'
                $dataFile = Join-Path $dataFolder 'repos.cache'
                if (Test-Path $dataFile) {
                    Get-Content -Path $dataFile | `
                        Where-Object { $_ -like "*$wordToComplete*" } | `
                        ForEach-Object { $_ }
                }
                else {
                    $(ubuntu run ls ~/repos) -split "`n" | `
                        Where-Object { $_ -like "*$wordToComplete*" } `
                        ForEach-Object { $_ }
                }
            })]
        [string]$RepositoryName,

        [Parameter(ParameterSetName = 'edit')]
        [string]$ADOProject = 'CRM%20Salesforce',

        [Parameter(Mandatory, ParameterSetName = 'update')]
        [switch]$UpdateCache,

        [Parameter(ParameterSetName = 'update')]
        [string]$SecretName = 'az-pat'
    )

    if ($UpdateCache) {
        Write-Host "Updating repository cache..."
        if (-not $env:AZURE_DEVOPS_EXT_PAT) {
            $env:AZURE_DEVOPS_EXT_PAT = Get-Secret -Name $SecretName -AsPlainText
        }
        $dataFolder = Join-Path $env:LOCALAPPDATA 'Edit-Repo'
        $dataFile = Join-Path $dataFolder 'repos.cache'
        $repos = az repos list | `
            ConvertFrom-Json | `
            Select-Object -ExpandProperty name | `
            Where-Object { $_ -notlike 'z(deprecated)*' }
        New-Item -Path $dataFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Set-Content -Path $dataFile -Value ($repos -join "`n")
        return
    }

    if (-not (ubuntu run "[ -d ~/repos/$RepositoryName ] && echo 'exists'")) {
        Write-Host "Cloning repository $RepositoryName..."
        ubuntu run git clone "https://dev.azure.com/slmbank-vsts/$ADOProject/_git/$RepositoryName" `
            ~/repos/$RepositoryName
        if ($LASTEXITCODE) {
            Write-Error "Failed to clone repository"
            return
        }
    }

    ubuntu run code ~/repos/$RepositoryName
}

Set-Alias -Name er -Value Edit-Repo
