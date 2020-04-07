<#
.SYNOPSIS
The module that contains a bunch of methods to interact with GitHub API V3
#>
class GitHubApi
{
    [string] $BaseUrl
    [string] $RepoOwner
    [object] $AuthHeader

    GitHubApi(
        [string] $AccountName,
        [string] $ProjectName,
        [string] $AccessToken
    ) {
        $this.BaseUrl = $this.BuildBaseUrl($AccountName, $ProjectName)
        $this.AuthHeader = $this.BuildAuth($AccessToken)
    }

    [object] hidden BuildAuth([string]$AccessToken) {
        if ([string]::IsNullOrEmpty($AccessToken)) {
            return $null
        }
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("'':${AccessToken}"))
        return @{
            Authorization = "Basic ${base64AuthInfo}"
        }
    }

    [string] hidden BuildBaseUrl([string]$RepositoryOwner, [string]$RepositoryName) {
        return "https://api.github.com/repos/$RepositoryOwner/$RepositoryName"
    }

    [object] CreateNewPullRequest([string]$Title, [string]$Body, [string]$BranchName){
        $requestBody = @{
            title = $Title
            body = $Body
            head = $BranchName
            base = "master"
        } | ConvertTo-Json

        $url = "pulls"
        return $this.InvokeRestMethod($url, 'Post', $null, $requestBody)
    }

    [object] GetPullRequest([string]$BranchName, [string]$RepositoryOwner){
        $url = "pulls"
        return $this.InvokeRestMethod($url, 'GET', "head=${RepositoryOwner}:$BranchName&base=master", $null)
    }

    [object] UpdatePullRequest([string]$Title, [string]$Body, [string]$BranchName, [string]$PullRequestNumber){
        $requestBody = @{
            title = $Title
            body = $Body
            head = $BranchName
            base = "master"
        } | ConvertTo-Json

        $url = "pulls/$PullRequestNumber"
        return $this.InvokeRestMethod($url, 'Post', $null, $requestBody)
    }

    [object] GetGitHubReleases(){
        $url = "releases"
        return $this.InvokeRestMethod($url, 'GET', $null, $null)
    }

    [string] hidden BuildUrl([string]$Url, [string]$RequestParams) {
        if ([string]::IsNullOrEmpty($RequestParams)) {
            return "$($this.BaseUrl)/$($Url)"
        } else {
            return "$($this.BaseUrl)/$($Url)?$($RequestParams)"
        }
    }

    [object] hidden InvokeRestMethod(
        [string] $Url,
        [string] $Method,
        [string] $RequestParams,
        [string] $Body
    ) {
        $requestUrl = $this.BuildUrl($Url, $RequestParams)
        $params = @{
            Method = $Method
            ContentType = "application/json"
            Uri = $requestUrl
            Headers = @{}
        }
        if ($this.AuthHeader) {
            $params.Headers += $this.AuthHeader
        }
        if (![string]::IsNullOrEmpty($Body)) {
            $params.Body = $Body
        }

        return Invoke-RestMethod @params
    }

}

function Get-GitHubApi {
    param (
        [string] $AccountName,
        [string] $ProjectName,
        [string] $AccessToken
    )

    return [GitHubApi]::New($AccountName, $ProjectName, $AccessToken)
}