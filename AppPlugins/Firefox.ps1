<#
.SYNOPSIS
    Checks for latest Mozilla Firefox version.

.DESCRIPTION
    Queries Mozilla product details API to get the latest Firefox version.

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
    # Mozilla product details API
    $apiUrl = "https://product-details.mozilla.org/1.0/firefox_versions.json"

    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop

    # Get latest stable version
    $latestVersion = $response.LATEST_FIREFOX_VERSION

    return @{
        LatestVersion = $latestVersion
        DownloadUrl = "https://www.mozilla.org/en-US/firefox/new/"
        ReleaseNotes = "https://www.mozilla.org/en-US/firefox/releases/"
    }

} catch {
    Write-Error "Failed to check Firefox version: $_"
    return $null
}
