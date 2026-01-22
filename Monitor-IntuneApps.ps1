<#
.SYNOPSIS
    Monitors Intune apps for updates and security vulnerabilities.

.DESCRIPTION
    This script checks all enabled apps in the monitoring configuration for:
    - New version availability
    - Known CVE vulnerabilities
    Creates findings.json for Power Automate to process if issues are found.

.PARAMETER DryRun
    Runs all checks but doesn't create findings file (for testing).

.PARAMETER TestNotifications
    Creates a test findings file to verify Power Automate integration.

.PARAMETER Force
    Forces check even if already run today.

.EXAMPLE
    .\Monitor-IntuneApps.ps1 -DryRun
    .\Monitor-IntuneApps.ps1
    .\Monitor-IntuneApps.ps1 -TestNotifications
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$TestNotifications,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Script paths
$scriptDir = $PSScriptRoot
$configPath = Join-Path $scriptDir "Config\monitoring-config.json"
$outputPath = Join-Path $scriptDir "Output\findings.json"
$statePath = Join-Path $scriptDir "State\last-run.json"
$logPath = Join-Path $scriptDir "Logs\monitor-$(Get-Date -Format 'yyyy-MM-dd').log"
$pluginsDir = Join-Path $scriptDir "AppPlugins"

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path -Parent $logPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Write to log file
    Add-Content -Path $logPath -Value $logMessage

    # Also write to console with colors
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
    }
    Write-Host $logMessage -ForegroundColor $color
}

# Function to check if app plugin exists
function Get-AppPlugin {
    param([string]$AppName)

    $pluginPath = Join-Path $pluginsDir "$AppName.ps1"
    if (Test-Path $pluginPath) {
        return $pluginPath
    }

    # Try generic plugin
    $genericPlugin = Join-Path $pluginsDir "Generic.ps1"
    if (Test-Path $genericPlugin) {
        return $genericPlugin
    }

    return $null
}

# Function to get latest version using plugin
function Get-LatestVersion {
    param(
        [string]$AppName,
        [string]$DisplayName,
        [string]$CurrentVersion
    )

    try {
        $pluginPath = Get-AppPlugin -AppName $AppName

        if (-not $pluginPath) {
            Write-Log "No plugin found for $AppName" -Level WARNING
            return $null
        }

        Write-Log "Checking $DisplayName using plugin: $(Split-Path -Leaf $pluginPath)"

        # Execute the plugin
        $result = & $pluginPath -CurrentVersion $CurrentVersion

        if ($result -and $result.LatestVersion) {
            return $result
        }

        return $null

    } catch {
        Write-Log "Error checking $AppName : $_" -Level ERROR
        return $null
    }
}

# Function to check for CVEs
function Get-CVEsForApp {
    param(
        [string]$AppName,
        [string]$Version
    )

    # This will be implemented in a separate CVE module
    # For now, return empty array
    # TODO: Implement NVD API integration
    return @()
}

# Function to determine update type
function Get-UpdateType {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion
    )

    try {
        # Parse versions
        $current = [version]::Parse(($CurrentVersion -split '-')[0])
        $latest = [version]::Parse(($LatestVersion -split '-')[0])

        if ($latest.Major -gt $current.Major) {
            return 'Major'
        } elseif ($latest.Minor -gt $current.Minor) {
            return 'Minor'
        } elseif ($latest.Build -gt $current.Build) {
            return 'Patch'
        } else {
            return 'Other'
        }
    } catch {
        # If version parsing fails, default to Minor
        return 'Minor'
    }
}

# Main execution
try {
    Write-Log "=== Starting Intune App Monitor ===" -Level INFO
    Write-Log "Mode: $(if ($DryRun) { 'DRY RUN' } elseif ($TestNotifications) { 'TEST' } else { 'PRODUCTION' })"

    # Check if config exists
    if (-not (Test-Path $configPath)) {
        Write-Log "Configuration file not found: $configPath" -Level ERROR
        Write-Log "Run Import-FromIntuneCSV.ps1 first to create the configuration." -Level ERROR
        exit 1
    }

    # Load configuration
    Write-Log "Loading configuration from $configPath"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Check if monitoring is enabled
    if (-not $config.monitoring.enabled) {
        Write-Log "Monitoring is disabled in configuration. Exiting." -Level WARNING
        exit 0
    }

    # Test Notifications mode
    if ($TestNotifications) {
        Write-Log "Creating test findings for notification testing..." -Level INFO

        $testFindings = @{
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            testMode = $true
            summary = @{
                totalApps = 2
                appsNeedingUpdate = 2
                criticalCVEs = 1
                highCVEs = 0
            }
            findings = @(
                @{
                    app = "Node.js (TEST)"
                    currentVersion = "20.10.0"
                    latestVersion = "20.11.0"
                    updateType = "Minor"
                    downloadUrl = "https://nodejs.org/download/"
                    cves = @(
                        @{
                            id = "CVE-2024-TEST"
                            severity = "CRITICAL"
                            score = 9.8
                            description = "This is a test CVE for notification testing"
                        }
                    )
                },
                @{
                    app = "Visual Studio Code (TEST)"
                    currentVersion = "1.85.0"
                    latestVersion = "1.86.0"
                    updateType = "Minor"
                    downloadUrl = "https://code.visualstudio.com/download"
                    cves = @()
                }
            )
        }

        # Ensure output directory exists
        $outputDir = Split-Path -Parent $outputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Write test findings
        $testFindings | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding UTF8

        Write-Log "Test findings created at: $outputPath" -Level SUCCESS
        Write-Log "Power Automate should now process this test notification." -Level INFO
        exit 0
    }

    # Get enabled apps
    $enabledApps = $config.applications | Where-Object { $_.enabled -eq $true }
    Write-Log "Found $($enabledApps.Count) enabled apps to monitor"

    # Results collection
    $findings = @()
    $checkedApps = 0
    $appsWithUpdates = 0
    $appsWithCVEs = 0

    # Check each app
    foreach ($app in $enabledApps) {
        $checkedApps++
        Write-Log "[$checkedApps/$($enabledApps.Count)] Checking $($app.displayName)..."

        # Get latest version
        $latestInfo = Get-LatestVersion -AppName $app.name -DisplayName $app.displayName -CurrentVersion $app.currentVersion

        if (-not $latestInfo) {
            Write-Log "  Could not determine latest version (plugin may not exist yet)" -Level WARNING
            continue
        }

        $latestVersion = $latestInfo.LatestVersion
        $downloadUrl = $latestInfo.DownloadUrl

        # Check if update is needed
        $needsUpdate = $false
        if ($latestVersion -ne $app.currentVersion) {
            $updateType = Get-UpdateType -CurrentVersion $app.currentVersion -LatestVersion $latestVersion

            # Check thresholds
            if ($updateType -eq 'Major' -and $config.thresholds.notifyOnMajorUpdates) {
                $needsUpdate = $true
            } elseif ($updateType -eq 'Minor' -and $config.thresholds.notifyOnMinorUpdates) {
                $needsUpdate = $true
            } elseif ($updateType -eq 'Patch') {
                $needsUpdate = $false  # Don't notify for patch updates unless it's a security update
            }

            if ($needsUpdate) {
                Write-Log "  UPDATE AVAILABLE: $($app.currentVersion) -> $latestVersion ($updateType)" -Level WARNING
                $appsWithUpdates++
            }
        } else {
            Write-Log "  Up to date: $($app.currentVersion)" -Level SUCCESS
        }

        # Check for CVEs
        $cves = @()
        if ($app.checkCVEs -and $config.thresholds.notifyOnSecurityUpdates) {
            $cves = Get-CVEsForApp -AppName $app.name -Version $app.currentVersion
            if ($cves.Count -gt 0) {
                Write-Log "  SECURITY ALERT: Found $($cves.Count) CVE(s)" -Level ERROR
                $appsWithCVEs++
                $needsUpdate = $true
            }
        }

        # Add to findings if update needed or CVEs found
        if ($needsUpdate -or $cves.Count -gt 0) {
            $findings += @{
                app = $app.displayName
                currentVersion = $app.currentVersion
                latestVersion = $latestVersion
                updateType = if ($latestVersion -ne $app.currentVersion) { $updateType } else { "None" }
                downloadUrl = $downloadUrl
                cves = $cves
            }
        }
    }

    Write-Log "`n=== Monitoring Complete ===" -Level INFO
    Write-Log "Apps checked: $checkedApps"
    Write-Log "Apps with updates: $appsWithUpdates" -Level $(if ($appsWithUpdates -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "Apps with CVEs: $appsWithCVEs" -Level $(if ($appsWithCVEs -gt 0) { 'ERROR' } else { 'INFO' })

    # Create findings file if needed
    if ($findings.Count -gt 0 -and -not $DryRun) {
        Write-Log "`nCreating findings file for Power Automate..." -Level INFO

        # Count critical and high CVEs
        $criticalCVEs = 0
        $highCVEs = 0
        foreach ($finding in $findings) {
            foreach ($cve in $finding.cves) {
                if ($cve.severity -eq 'CRITICAL') { $criticalCVEs++ }
                if ($cve.severity -eq 'HIGH') { $highCVEs++ }
            }
        }

        $findingsData = @{
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
            summary = @{
                totalApps = $checkedApps
                appsNeedingUpdate = $appsWithUpdates
                criticalCVEs = $criticalCVEs
                highCVEs = $highCVEs
            }
            findings = $findings
        }

        # Ensure output directory exists
        $outputDir = Split-Path -Parent $outputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Write findings
        $findingsData | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding UTF8

        Write-Log "Findings file created: $outputPath" -Level SUCCESS
        Write-Log "Power Automate will process this and send notifications." -Level INFO

    } elseif ($findings.Count -gt 0 -and $DryRun) {
        Write-Log "`nDRY RUN: Would have created findings file with $($findings.Count) items" -Level INFO
        Write-Log "Findings:" -Level INFO
        $findings | ForEach-Object {
            Write-Log "  - $($_.app): $($_.currentVersion) -> $($_.latestVersion) (CVEs: $($_.cves.Count))" -Level INFO
        }
    } else {
        Write-Log "`nNo updates or security issues found. Everything is up to date!" -Level SUCCESS
    }

    # Update last run state
    $stateDir = Split-Path -Parent $statePath
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    $state = @{
        lastRun = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        appsChecked = $checkedApps
        updateFound = $appsWithUpdates
        cvesFound = $appsWithCVEs
    }
    $state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8

    Write-Log "`nLog file: $logPath" -Level INFO

} catch {
    Write-Log "Fatal error: $_" -Level ERROR
    Write-Log $_.ScriptStackTrace -Level ERROR
    exit 1
}
