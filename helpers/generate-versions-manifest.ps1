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
.PARAMETER PlatformMapFile
Optional parameter. Path to the json file with platform map
Structure example:
{
    "macos-1014": [
        {
            "platform": "darwin",
            "platform_version": "10.14"
        }, ...
    ], ...
}
#>

param (
    [Parameter(Mandatory)] [string] $GitHubRepositoryOwner,
    [Parameter(Mandatory)] [string] $GitHubRepositoryName,
    [Parameter(Mandatory)] [string] $GitHubAccessToken,
    [Parameter(Mandatory)] [string] $OutputFile,
    [string] $PlatformMapFile
)

Import-Module (Join-Path $PSScriptRoot "github/github-api.psm1")

if ($PlatformMapFile -and (Test-Path $PlatformMapFile)) {
    $PlatformMap = Get-Content $PlatformMapFile -Raw | ConvertFrom-Json -AsHashtable
} else {
    $PlatformMap = @{}
}

function Get-FileNameWithoutExtension {
    param (
        [Parameter(Mandatory)][string]$Filename
    )

    if ($Filename.EndsWith(".tar.gz")) {
        $Filename = [IO.path]::GetFileNameWithoutExtension($Filename)
    }

    return [IO.path]::GetFileNameWithoutExtension($Filename)
}

function New-AssetItem {
    param (
        [Parameter(Mandatory)][string]$Filename,
        [Parameter(Mandatory)][string]$DownloadUrl,
        [Parameter(Mandatory)][string]$Arch,
        [Parameter(Mandatory)][string]$Platform,
        [string]$PlatformVersion
    )
    $asset = New-Object PSObject

    $asset | Add-Member -Name "filename" -Value $Filename -MemberType NoteProperty
    $asset | Add-Member -Name "arch" -Value $Arch -MemberType NoteProperty
    $asset | Add-Member -Name "platform" -Value $Platform -MemberType NoteProperty
    if ($PlatformVersion) { $asset | Add-Member -Name "platform_version" -Value $PlatformVersion -MemberType NoteProperty }
    $asset | Add-Member -Name "download_url" -Value $DownloadUrl -MemberType NoteProperty

    return $asset
}

function Build-AssetsList {
    param (
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][array]$ReleaseAssets
    )

    
    $assets = @()
    foreach($releaseAsset in $ReleaseAssets) {
        $filename = Get-FileNameWithoutExtension -Filename $releaseAsset.name
        $parts = $filename.Split("-")
        $arch = $parts[-1]
        $buildPlatform = [string]::Join("-", $parts[2..($parts.Length-2)])

        if ($PlatformMap[$buildPlatform]) {
            $PlatformMap[$buildPlatform] | ForEach-Object {
                $assets += New-AssetItem -Filename $releaseAsset.name `
                                         -DownloadUrl $releaseAsset.browser_download_url `
                                         -Arch $arch `
                                         -Platform $_.platform `
                                         -PlatformVersion $_.platform_version
            }

        } else {
            $assets += New-AssetItem -Filename $releaseAsset.name `
                                     -DownloadUrl $releaseAsset.browser_download_url `
                                     -Arch $arch `
                                     -Platform $buildPlatform
        }
    }

    return $assets
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
    return $versionsHash.Values | Sort-Object -Property @{ Expression = { [Version]$_.version }; Descending = $true }
}

$gitHubApi = Get-GitHubApi -AccountName $GitHubRepositoryOwner -ProjectName $GitHubRepositoryName -AccessToken $GitHubAccessToken
$releases = $gitHubApi.GetGitHubReleases()
$versionIndex = Build-VersionsManifest $releases
$versionIndex | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8NoBOM -Force
