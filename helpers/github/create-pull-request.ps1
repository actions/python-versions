<#
.SYNOPSIS
Create commit with all unstaged changes in repository and create pull-request

.PARAMETER RepositoryOwner
Required parameter. The organization which tool repository belongs
.PARAMETER RepositoryName
Optional parameter. The name of tool repository
.PARAMETER AccessToken
Required parameter. PAT Token to authorize
.PARAMETER BranchName
Required parameter. The name of branch where changes will be pushed
.PARAMETER CommitMessage
Required parameter. The commit message to push changes
.PARAMETER PullRequestTitle
Required parameter. The title of pull-request
.PARAMETER PullRequestBody
Required parameter. The description of pull-request
#>
param (
    [Parameter(Mandatory)] [string] $RepositoryOwner,
    [Parameter(Mandatory)] [string] $RepositoryName,
    [Parameter(Mandatory)] [string] $AccessToken,
    [Parameter(Mandatory)] [string] $BranchName,
    [Parameter(Mandatory)] [string] $CommitMessage,
    [Parameter(Mandatory)] [string] $PullRequestTitle,
    [Parameter(Mandatory)] [string] $PullRequestBody
)

Import-Module (Join-Path $PSScriptRoot "github-api.psm1")
Import-Module (Join-Path $PSScriptRoot "git.psm1")

function Update-PullRequest {
    Param (
        [Parameter(Mandatory=$true)]
        [object] $GitHubApi,
        [Parameter(Mandatory=$true)]
        [string] $Title,
        [Parameter(Mandatory=$true)]
        [string] $Body,
        [Parameter(Mandatory=$true)]
        [string] $BranchName,
        [Parameter(Mandatory=$true)]
        [object] $PullRequest
    )

    $updatedPullRequest = $GitHubApi.UpdatePullRequest($Title, $Body, $BranchName, $PullRequest.number)

    if (($updatedPullRequest -eq $null) -or ($updatedPullRequest.html_url -eq $null)) {
        Write-Host "##vso[task.logissue type=error;] Unexpected error occurs while updating pull request."
        exit 1
    }
    Write-host "##[section] Pull request updated: $($updatedPullRequest.html_url)"
}

function Create-PullRequest {
    Param (
        [Parameter(Mandatory=$true)]
        [object] $GitHubApi,
        [Parameter(Mandatory=$true)]
        [string] $Title,
        [Parameter(Mandatory=$true)]
        [string] $Body,
        [Parameter(Mandatory=$true)]
        [string] $BranchName
    )

    $createdPullRequest = $GitHubApi.CreateNewPullRequest($Title, $Body, $BranchName)

    if (($createdPullRequest -eq $null) -or ($createdPullRequest.html_url -eq $null)) {
        Write-Host "##vso[task.logissue type=error;] Unexpected error occurs while creating pull request."
        exit 1
    }

    Write-host "##[section] Pull request created: $($createdPullRequest.html_url)"
}

Write-Host "Configure local git preferences"
Git-ConfigureUser -Name "Service account" -Email "no-reply@microsoft.com"

Write-Host "Create branch: $BranchName"
Git-CreateBranch -Name $BranchName
    
Write-Host "Create commit"
Git-CommitAllChanges -Message $CommitMessage

Write-Host "Push branch: $BranchName"
Git-PushBranch -Name $BranchName -Force $true

$gitHubApi = Get-GitHubApi -AccountName $RepositoryOwner -ProjectName $RepositoryName -AccessToken $AccessToken
$pullRequest = $gitHubApi.GetPullRequest($BranchName, $RepositoryOwner)

if ($pullRequest.Count -gt 0) {
    Write-Host "Update pull request"
    Update-PullRequest -GitHubApi $gitHubApi `
                       -Title $PullRequestTitle `
                       -Body $PullRequestBody `
                       -BranchName $BranchName `
                       -PullRequest $pullRequest[0]
} else {
    Write-Host "Create pull request"
    Create-PullRequest -GitHubApi $gitHubApi `
                       -Title $PullRequestTitle `
                       -Body $PullRequestBody `
                       -BranchName $BranchName
}
