<#
.SYNOPSIS
    Checks for latest Visual Studio Code version.

.DESCRIPTION
    Queries the GitHub API to get the latest VS Code release.

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
    # Query GitHub API for latest release
    $apiUrl = "https://api.github.com/repos/microsoft/vscode/releases/latest"

    $headers = @{
        'User-Agent' = 'Intune-App-Monitor'
        'Accept' = 'application/vnd.github.v3+json'
    }

    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop

    $latestVersion = $response.tag_name -replace '^v', ''

    return @{
        LatestVersion = $latestVersion
        DownloadUrl = "https://code.visualstudio.com/download"
        ReleaseNotes = $response.html_url
    }

} catch {
    Write-Error "Failed to check VS Code version: $_"
    return $null
}
