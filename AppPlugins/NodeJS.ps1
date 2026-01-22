<#
.SYNOPSIS
    Checks for latest Node.js version.

.DESCRIPTION
    Queries the official Node.js API to get the latest version information.

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
    # Determine the major version from current version
    $majorVersion = ($CurrentVersion -split '\.')[0]

    # Query Node.js API for all versions
    $allVersionsUrl = "https://nodejs.org/dist/index.json"
    $response = Invoke-RestMethod -Uri $allVersionsUrl -ErrorAction Stop

    # Find the latest version for the same major version line
    $latestForMajor = $response |
        Where-Object { $_.version -match "^v$majorVersion\." } |
        Select-Object -First 1

    if ($latestForMajor) {
        $latestVersion = $latestForMajor.version -replace '^v', ''

        return @{
            LatestVersion = $latestVersion
            DownloadUrl = "https://nodejs.org/en/download/"
            ReleaseNotes = "https://github.com/nodejs/node/blob/main/doc/changelogs/CHANGELOG_V$majorVersion.md"
        }
    }

    # If no version found for the major line, get the absolute latest
    $latest = $response | Select-Object -First 1
    $latestVersion = $latest.version -replace '^v', ''

    return @{
        LatestVersion = $latestVersion
        DownloadUrl = "https://nodejs.org/en/download/"
        ReleaseNotes = "https://nodejs.org/en/blog/"
    }

} catch {
    Write-Error "Failed to check Node.js version: $_"
    return $null
}
