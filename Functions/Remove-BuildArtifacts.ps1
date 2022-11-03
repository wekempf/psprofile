function Remove-BuildArtifacts {
    if (Test-Path pyproject.toml) {
        $dirs = @(
            '.buildtools',
            '.mypy_cache',
            '.pytest_cache',
            '.venv',
            '.build',
            '.modules'
        )
        Remove-Item $dirs -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem bin,obj -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Set-Alias -Name clean -Value Remove-BuildArtifacts