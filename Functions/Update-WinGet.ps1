function Update-WinGet {
    <#
    .SYNOPSIS
    Update installed packages using WinGet.

    .DESCRIPTION
    Update-WinGet automates the process of updating installed packages using WinGet. It can be configured to run automatically at specified intervals or days of the week.

    .PARAMETER AutoUpdate
    Automatically update packages without prompting for confirmation.
    
    .PARAMETER Edit
    Edit the configuration file for package updates. If the configuration file does not exist, it will be created.

    .PARAMETER At
    Specify the time at which the task should run. This parameter is used with the Daily and Weekly parameters.

    .PARAMETER Daily
    Schedule the task to run daily. The At parameter must be specified to set the time of day.

    .PARAMETER Weekly
    Schedule the task to run weekly. The At parameter must be specified to set the time of day.

    .PARAMETER DaysInterval
    Specify the number of days between each run of the task. This parameter is used with the Daily parameter.

    .PARAMETER DaysOfWeek
    Specify the days of the week on which the task should run. This parameter is used with the Weekly parameter.

    .PARAMETER WeeksInterval
    Specify the number of weeks between each run of the task. This parameter is used with the Weekly parameter.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'Default')]
        [switch]$AutoUpdate,

        [Parameter(ParameterSetName = 'Edit')]
        [switch]$Edit,

        [Parameter(Mandatory, ParameterSetName = 'Daily')]
        [Parameter(Mandatory, ParameterSetName = 'Weekly')]
        [DateTime]$At,

        [Parameter(ParameterSetName = 'Daily')]
        [switch]$Daily,

        [Parameter(ParameterSetName = 'Weekly')]
        [switch]$Weekly,

        [Parameter(ParameterSetName = 'Daily')]
        [int]$DaysInterval,

        [Parameter(Mandatory, ParameterSetName = 'Weekly')]
        [DayOfWeek[]]$DaysOfWeek,

        [Parameter(ParameterSetName = 'Weekly')]
        [int]$WeeksInterval
    )

    $cfgFile = "$HOME/.update-winget.txt"
    if ($Edit) {
        if (-not (Test-Path $cfgFile)) {
            Write-Host -ForegroundColor Yellow "No configuration file found. Creating one."
            New-Item -Path $cfgFile -ItemType File -Force
        }
        $editor = $env:EDITOR ?? 'notepad'
        if (-not (Get-Command $editor -ErrorAction SilentlyContinue)) {
            Write-Host -ForegroundColor Red "Editor '$editor' not found. Please set the EDITOR environment variable."
            return
        }
        & $editor (Resolve-Path $cfgFile)
        return
    }

    if ($Daily -or $Weekly) {
        $trigger = New-ScheduledTaskTrigger @PSBoundParameters
        $action = New-ScheduledTaskAction -Execute (Get-Process -Id $pid).Path -Argument "-NoProfile -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& '$PSCommandPath' -AutoUpdate`""
        Unregister-ScheduledTask -TaskName 'Update-WinGet' -Confirm:$false -ErrorAction SilentlyContinue
        Register-ScheduledTask -TaskName 'Update-WinGet' -Trigger $trigger -Action $action | Out-Null
        return
    }
    
    if (-not (Get-Module Microsoft.WinGet.Client -ListAvailable -ErrorAction SilentlyContinue)) {
        Install-PSResource Microsoft.WinGet.Client -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
    $updateCfg = @{}
    if (Test-Path $cfgFile) {
        foreach ($line in Get-Content $cfgFile) {
            $id = $line.Trim().Substring(1)
            $updateCfg[$id] = $line.Trim().Substring(0, 1) -eq "+"
        }
    }

    $packages = Get-WinGetPackage | Where-Object { $_.IsUpdateAvailable }
    foreach ($package in $packages) {
        $name = $package.Name
        $id = $package.Id
        if ($updateCfg.ContainsKey($id)) {
            if ($updateCfg[$id]) {
                Write-Host -ForegroundColor Green "Updating $id"
                Update-WinGetPackage -Id $id
            } else {
                Write-Host -ForegroundColor Yellow "Skipping $id"
            }
        } elseif (-not $AutoUpdate) {
            $title = 'Confirm Update'
            $message = "Update available for `e[36m$name ($id)`e[0m. Update and add to white list?"
            $choices = @(
                [System.Management.Automation.Host.ChoiceDescription]::new('&Always', 'Update and add to white list.')
                [System.Management.Automation.Host.ChoiceDescription]::new('Ne&ver', 'Do not update and add to black list.')
                [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Update without adding to white list.')
                [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Do not update or add to black list.')
            )
            $decision = $Host.UI.PromptForChoice($title, $message, $choices, 0)
            if ($decision -eq 0) {
                Write-Host -ForegroundColor Green "Updating $id and configuring to always auto-update"
                Add-Content $cfgFile "+$id"
                Update-WinGetPackage -Id $id
            } elseif ($decision -eq 1) {
                Write-Host -ForegroundColor Yellow "Skipping $id and configuring to never auto-update"
                Add-Content $cfgFile "-$id"
            } elseif ($decision -eq 2) {
                Write-Host -ForegroundColor Green "Updating $id"
                Update-WinGetPackage -Id $id
            } else {
                Write-Host -ForegroundColor Yellow "Skipping $id"
            }
        }
    }
}
Set-Alias -Name wu -Value Update-WinGet
