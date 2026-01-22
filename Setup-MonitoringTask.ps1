<#
.SYNOPSIS
    Creates a Windows scheduled task to run the monitoring script daily.

.DESCRIPTION
    Sets up a scheduled task that runs Monitor-IntuneApps.ps1 every day at 8:00 AM.
    The task will run whether you're logged in or not, and will wake the computer if needed.

.PARAMETER RunTime
    Time to run the task daily (default: 08:00 AM).

.EXAMPLE
    .\Setup-MonitoringTask.ps1
    .\Setup-MonitoringTask.ps1 -RunTime "09:00"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RunTime = "08:00"
)

# Requires administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires administrator privileges. Please run as Administrator."
    exit 1
}

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir "Monitor-IntuneApps.ps1"
$taskName = "Intune App Monitor - Daily Check"

try {
    Write-Host "Setting up scheduled task..." -ForegroundColor Cyan

    # Check if script exists
    if (-not (Test-Path $scriptPath)) {
        throw "Monitor script not found: $scriptPath"
    }

    # Remove existing task if it exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "Removing existing task..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    # Create the action
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" `
        -WorkingDirectory $scriptDir

    # Create the trigger (daily at specified time)
    $trigger = New-ScheduledTaskTrigger -Daily -At $RunTime

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -WakeToRun `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable

    # Create the principal (run as current user)
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Limited

    # Register the task
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Monitors Intune apps for updates and security vulnerabilities daily" | Out-Null

    Write-Host "`nScheduled task created successfully!" -ForegroundColor Green
    Write-Host "Task name: $taskName" -ForegroundColor Cyan
    Write-Host "Run time: Daily at $RunTime" -ForegroundColor Cyan
    Write-Host "Script: $scriptPath" -ForegroundColor Cyan

    Write-Host "`nTesting the task..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $taskName

    Start-Sleep -Seconds 3

    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Last run: $($taskInfo.LastRunTime)" -ForegroundColor Cyan
    Write-Host "Last result: $($taskInfo.LastTaskResult)" -ForegroundColor $(if ($taskInfo.LastTaskResult -eq 0) { 'Green' } else { 'Red' })

    Write-Host "`nYou can manage this task in Task Scheduler:" -ForegroundColor Cyan
    Write-Host "  - Run: taskschd.msc" -ForegroundColor White
    Write-Host "  - Or disable auto-run: Unregister-ScheduledTask -TaskName '$taskName'" -ForegroundColor White

} catch {
    Write-Error "Failed to create scheduled task: $_"
    exit 1
}
