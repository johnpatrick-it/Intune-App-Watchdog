<#
.SYNOPSIS
    Checks for latest Google Chrome version.

.DESCRIPTION
    Queries the Chrome update API to get the latest stable version.

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
    # Chrome version API endpoint
    $apiUrl = "https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions"

    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop

    if ($response.versions -and $response.versions.Count -gt 0) {
        $latestVersion = $response.versions[0].version

        return @{
            LatestVersion = $latestVersion
            DownloadUrl = "https://www.google.com/chrome/browser/desktop/"
            ReleaseNotes = "https://chromereleases.googleblog.com/"
        }
    }

    return $null

} catch {
    Write-Error "Failed to check Chrome version: $_"
    return $null
}
