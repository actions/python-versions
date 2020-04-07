<#
.SYNOPSIS
Generate versions manifest based on repository releases

.DESCRIPTION
Versions manifest is needed to find the latest assets for particular version of tool
.PARAMETER GitHubRepositoryOwner
Required parameter. The organization which tool repository belongs
.PARAMETER GitHubRepositoryName
Optional parameter. The name of tool repository
.PARAMETER GitHubAccessToken
Required parameter. PAT Token to overcome GitHub API Rate limit
.PARAMETER OutputFile
Required parameter. File "*.json" where generated results will be saved
#>

param (
    [Parameter(Mandatory)] [string] $GitHubRepositoryOwner,
    [Parameter(Mandatory)] [string] $GitHubRepositoryName,
    [Parameter(Mandatory)] [string] $GitHubAccessToken,
    [Parameter(Mandatory)] [string] $OutputFile
)

Import-Module (Join-Path $PSScriptRoot "github-api.psm1")

function Build-AssetsList {
    param (
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][array]$ReleaseAssets
    )

    return $ReleaseAssets | ForEach-Object {
        $parts = [IO.path]::GetFileNameWithoutExtension($_.name).Split("-")

        return [PSCustomObject]@{
            filename = $_.name
            arch = $parts[-1]
            platform = [string]::Join("-", $parts[2..($parts.Length-2)])
            download_url = $_.browser_download_url
        }
    }
}

function Get-VersionFromRelease {
    param (
        [Parameter(Mandatory)][object]$Release
    )
    # Release name can contain additional information after ':' so filter it
    [string]$releaseName = $Release.name.Split(':')[0]
    [Version]$version = $null
    if (![Version]::TryParse($releaseName, [ref]$version)) {
        throw "Release '$($Release.id)' has invalid title '$($Release.name)'. It can't be parsed as version. ( $($Release.html_url) )"
    }

    return $version
}

function Build-VersionsManifest {
    param (
        [Parameter(Mandatory)][array]$Releases
    )

    $Releases = $Releases | Sort-Object -Property "published_at" -Descending

    $versionsHash = @{}
    foreach ($release in $Releases) {
        if (($release.draft -eq $true) -or ($release.prerelease -eq $true)) {
            continue
        }

        [Version]$version = Get-VersionFromRelease $release
        $versionKey = $version.ToString()

        if ($versionsHash.ContainsKey($versionKey)) {
            continue
        }

        $versionsHash.Add($versionKey, [PSCustomObject]@{
            version = $versionKey
            stable = $true
            release_url = $release.html_url
            files = Build-AssetsList $release.assets
        })
    }

    # Sort versions by descending
    return $versionsHash.Values | Sort-Object -Property "version" -Descending
}

$gitHubApi = Get-GitHubApi -AccountName $GitHubRepositoryOwner -ProjectName $GitHubRepositoryName -AccessToken $GitHubAccessToken
$releases = $gitHubApi.GetGitHubReleases()
$versionIndex = Build-VersionsManifest $releases
$versionIndex | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding utf8 -Force
