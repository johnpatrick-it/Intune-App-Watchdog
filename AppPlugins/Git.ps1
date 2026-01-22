<#
.SYNOPSIS
    Checks for latest Git for Windows version.

.DESCRIPTION
    Queries the GitHub API for the latest Git for Windows release.

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
    # Git for Windows GitHub API
    $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"

    $headers = @{
        'User-Agent' = 'Intune-App-Monitor'
        'Accept' = 'application/vnd.github.v3+json'
    }

    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop

    # Extract version from tag (e.g., "v2.43.0.windows.1" -> "2.43.0")
    if ($response.tag_name -match 'v?(\d+\.\d+\.\d+)') {
        $latestVersion = $Matches[1]

        return @{
            LatestVersion = $latestVersion
            DownloadUrl = "https://git-scm.com/download/win"
            ReleaseNotes = $response.html_url
        }
    }

    return $null

} catch {
    Write-Error "Failed to check Git version: $_"
    return $null
}
