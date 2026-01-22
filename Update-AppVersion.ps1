<#
.SYNOPSIS
    Updates the version number for an app in the monitoring configuration.

.DESCRIPTION
    Helper script to update app versions after deploying updates to Intune.

.PARAMETER AppName
    The display name of the app (e.g., "PH - Node.js 24.12.0" or just "Node.js").

.PARAMETER NewVersion
    The new version number that was deployed.

.EXAMPLE
    .\Update-AppVersion.ps1 -AppName "Google Chrome" -NewVersion "144.0.7559.97"
    .\Update-AppVersion.ps1 -AppName "PH - Google Chrome" -NewVersion "144.0.7559.97"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$NewVersion
)

$configPath = Join-Path $PSScriptRoot "Config\monitoring-config.json"

try {
    # Load configuration
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Find the app (support both "App Name" and "PH - App Name" formats)
    $app = $config.applications | Where-Object {
        $_.displayName -eq $AppName -or
        $_.displayName -eq "PH - $AppName" -or
        $_.name -eq $AppName
    } | Select-Object -First 1

    if (-not $app) {
        Write-Host "App not found: $AppName" -ForegroundColor Red
        Write-Host "`nAvailable apps:" -ForegroundColor Yellow
        $config.applications | Select-Object displayName | Format-Table -AutoSize
        exit 1
    }

    $oldVersion = $app.currentVersion

    # Update the version
    $app.currentVersion = $NewVersion
    $config.lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")

    # Save configuration
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8

    Write-Host "Version updated successfully!" -ForegroundColor Green
    Write-Host "App: $($app.displayName)" -ForegroundColor Cyan
    Write-Host "Old version: $oldVersion" -ForegroundColor Yellow
    Write-Host "New version: $NewVersion" -ForegroundColor Green

} catch {
    Write-Error "Failed to update version: $_"
    exit 1
}
