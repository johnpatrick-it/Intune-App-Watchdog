<#
.SYNOPSIS
    Generic plugin for apps without specific version checking logic.

.DESCRIPTION
    Returns the current version as latest (no update check performed).
    This is a fallback plugin for apps that don't have specific plugins yet.

.PARAMETER CurrentVersion
    The currently deployed version.

.OUTPUTS
    Hashtable with LatestVersion and DownloadUrl
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CurrentVersion
)

try {
    Write-Warning "Using generic plugin - no version check performed. Consider creating a specific plugin."

    return @{
        LatestVersion = $CurrentVersion
        DownloadUrl = "https://example.com/manual-check-required"
        ReleaseNotes = "Manual check required - no plugin available"
    }

} catch {
    Write-Error "Generic plugin failed: $_"
    return $null
}
