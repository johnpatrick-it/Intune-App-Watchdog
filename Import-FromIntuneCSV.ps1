<#
.SYNOPSIS
    Imports Intune apps from CSV export and generates monitoring configuration.

.DESCRIPTION
    This script reads an Intune apps CSV export, filters apps with "PH -" prefix,
    and generates the monitoring-config.json file for the monitoring system.

.PARAMETER CSVPath
    Path to the Intune apps CSV export file.

.PARAMETER OutputPath
    Path where the monitoring-config.json will be created.
    Defaults to .\Config\monitoring-config.json

.EXAMPLE
    .\Import-FromIntuneCSV.ps1 -CSVPath "C:\Users\ext_patrickh\Downloads\Client apps_2026-01-22T09_44_01.299Z.csv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\Config\monitoring-config.json"
)

# Function to normalize app names for plugin mapping
function Get-NormalizedAppName {
    param([string]$DisplayName)

    # Remove "PH -" prefix
    $name = $DisplayName -replace '^PH - ', ''

    # Map common app names to plugin names
    $mappings = @{
        'Visual Studio Code' = 'VSCode'
        'Node.js*' = 'NodeJS'
        'SQL Server Manager Studio*' = 'SSMS'
        'Memurai*' = 'Memurai'
        'Google Chrome' = 'Chrome'
        'Mozilla Firefox' = 'Firefox'
        'Git' = 'Git'
        'Docker Desktop' = 'Docker'
        '7-Zip' = '7Zip'
        'Python*' = 'Python'
        'Adobe Acrobat Reader' = 'AdobeReader'
        'Notepad++' = 'NotepadPlusPlus'
        'WinRAR' = 'WinRAR'
        'VLC media player' = 'VLC'
        'MongoDB*' = 'MongoDB'
        'Zoom*' = 'Zoom'
        'Microsoft Teams' = 'Teams'
        'Microsoft 365 Apps*' = 'Office365'
        'Power BI*' = 'PowerBI'
        'Azure CLI' = 'AzureCLI'
        'AWS CLI*' = 'AWSCLI'
        'GitHub Desktop' = 'GitHubDesktop'
        'WinSCP' = 'WinSCP'
        'PuTTY' = 'PuTTY'
        'FileZilla' = 'FileZilla'
    }

    # Check for wildcard matches
    foreach ($key in $mappings.Keys) {
        if ($key -like '*`*') {
            $pattern = $key -replace '\*', '.*'
            if ($name -match "^$pattern") {
                return $mappings[$key]
            }
        } elseif ($name -eq $key) {
            return $mappings[$key]
        }
    }

    # Default: use the name as-is but sanitize it
    return ($name -replace '[^a-zA-Z0-9]', '')
}

# Function to determine if CVE checking should be enabled
function Should-CheckCVEs {
    param([string]$AppName)

    # Enable CVE checking for common apps with known security importance
    $cveEnabledApps = @(
        'NodeJS', 'Chrome', 'Firefox', 'Git', 'Docker', 'Python',
        'AdobeReader', 'MongoDB', 'Zoom', 'Teams', 'VSCode',
        'Java', 'Office365', 'SSMS', 'PowerBI', 'AWSCLI', 'AzureCLI'
    )

    return $cveEnabledApps -contains $AppName
}

try {
    Write-Host "Importing Intune apps from CSV..." -ForegroundColor Cyan
    Write-Host "CSV Path: $CSVPath" -ForegroundColor Gray

    # Check if CSV exists
    if (-not (Test-Path $CSVPath)) {
        throw "CSV file not found: $CSVPath"
    }

    # Read CSV and filter for PH- apps
    $apps = Import-Csv -Path $CSVPath | Where-Object { $_.Name -like 'PH -*' }

    Write-Host "Found $($apps.Count) apps with 'PH -' prefix" -ForegroundColor Green

    # Build the applications array
    $applications = @()
    $skipped = @()

    foreach ($app in $apps) {
        $displayName = $app.Name
        $version = $app.Version.Trim()
        $platform = $app.Platform
        $assigned = $app.Assigned

        # Skip if not Windows or not assigned
        if ($platform -ne 'Windows' -or $assigned -ne 'Yes') {
            $skipped += [PSCustomObject]@{
                Name = $displayName
                Reason = if ($platform -ne 'Windows') { "Non-Windows ($platform)" } else { "Not assigned" }
            }
            continue
        }

        # Skip if no version available
        if ([string]::IsNullOrWhiteSpace($version)) {
            $skipped += [PSCustomObject]@{
                Name = $displayName
                Reason = "No version information"
            }
            continue
        }

        # Get normalized app name for plugin
        $appName = Get-NormalizedAppName -DisplayName $displayName
        $checkCVEs = Should-CheckCVEs -AppName $appName

        $applications += [PSCustomObject]@{
            name = $appName
            displayName = $displayName
            currentVersion = $version
            enabled = $true
            checkCVEs = $checkCVEs
            platform = $platform
            type = $app.Type
        }
    }

    Write-Host "`nProcessed:" -ForegroundColor Cyan
    Write-Host "  - Imported: $($applications.Count) apps" -ForegroundColor Green
    Write-Host "  - Skipped: $($skipped.Count) apps" -ForegroundColor Yellow

    if ($skipped.Count -gt 0) {
        Write-Host "`nSkipped apps:" -ForegroundColor Yellow
        $skipped | Format-Table -AutoSize | Out-String | Write-Host
    }

    # Create the configuration object
    $config = @{
        lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        applications = $applications
        thresholds = @{
            notifyOnMinorUpdates = $false
            notifyOnMajorUpdates = $true
            notifyOnSecurityUpdates = $true
        }
        monitoring = @{
            enabled = $true
            checkIntervalHours = 24
            maxConcurrentChecks = 5
        }
        notifications = @{
            email = @{
                enabled = $true
                # Email settings configured in Power Automate
            }
            teams = @{
                enabled = $true
                # Teams settings configured in Power Automate
            }
        }
    }

    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # Write to JSON file
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

    Write-Host "`nConfiguration file created successfully!" -ForegroundColor Green
    Write-Host "Location: $OutputPath" -ForegroundColor Gray

    # Display summary of imported apps
    Write-Host "`nImported Applications:" -ForegroundColor Cyan
    $applications | Select-Object displayName, currentVersion, checkCVEs |
        Format-Table -AutoSize | Out-String | Write-Host

    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review the generated config file: $OutputPath" -ForegroundColor White
    Write-Host "  2. Edit the config to enable/disable specific apps if needed" -ForegroundColor White
    Write-Host "  3. Run the monitoring script: .\Monitor-IntuneApps.ps1 -DryRun" -ForegroundColor White

} catch {
    Write-Error "Failed to import CSV: $_"
    exit 1
}
