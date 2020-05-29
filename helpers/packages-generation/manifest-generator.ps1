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
.PARAMETER ConfigurationFile
Path to the json file with parsing configuration
#>

param (
    [Parameter(Mandatory)] [string] $GitHubRepositoryOwner,
    [Parameter(Mandatory)] [string] $GitHubRepositoryName,
    [Parameter(Mandatory)] [string] $GitHubAccessToken,
    [Parameter(Mandatory)] [string] $OutputFile,
    [Parameter(Mandatory)] [string] $ConfigurationFile
)

Import-Module (Join-Path $PSScriptRoot "../github/github-api.psm1")
Import-Module (Join-Path $PSScriptRoot "manifest-utils.psm1") -Force

$configuration = Read-ConfigurationFile -Filepath $ConfigurationFile

$gitHubApi = Get-GitHubApi -AccountName $GitHubRepositoryOwner -ProjectName $GitHubRepositoryName -AccessToken $GitHubAccessToken
$releases = $gitHubApi.GetReleases()
$versionIndex = Build-VersionsManifest -Releases $releases -Configuration $configuration
$versionIndex | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8NoBOM -Force
