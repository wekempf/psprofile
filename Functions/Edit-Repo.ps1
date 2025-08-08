function Edit-Repo {
    [CmdletBinding(DefaultParameterSetName = 'edit')]
    param(
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'edit')]
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'report')]
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
        [string]$SecretName = 'az-pat',

        [Parameter(ParameterSetName = 'report')]
        [switch]$Report
    )

    if ($UpdateCache) {
        Write-Host "Updating repository cache..."
        if (-not $env:AZURE_DEVOPS_EXT_PAT) {
            $env:AZURE_DEVOPS_EXT_PAT = Get-Secret -Name $SecretName -AsPlainText
        }
        $dataFolder = Join-Path $env:LOCALAPPDATA 'Edit-Repo'
        $dataFile = Join-Path $dataFolder 'repos.cache'
        $repos = az repos list | 
            ConvertFrom-Json | 
            Select-Object -ExpandProperty name | 
            Where-Object { $_ -notlike 'z(deprecated)*' }
        New-Item -Path $dataFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Set-Content -Path $dataFile -Value ($repos -join "`n")
        return
    }

    if ($Report) {
        $path = Resolve-Path "\\wsl.localhost\Ubuntu\home\appuser\repos\$RepositoryName"
        Invoke-Item "$path\coveragereport\index.html" -ErrorAction SilentlyContinue
        Get-ChildItem "$path\StrykerOutput" -ErrorAction SilentlyContinue |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1 |
            ForEach-Object { "$_\reports\mutation-report.html" } |
            Invoke-Item -ErrorAction SilentlyContinue
        Write-Host "Path: $path"
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
