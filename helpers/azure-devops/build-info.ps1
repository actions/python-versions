Import-Module (Join-Path $PSScriptRoot "azure-devops-api.ps1")

class BuildInfo
{
    [AzureDevOpsApi] $AzureDevOpsApi
    [String] $Name
    [UInt32] $Id
    [String] $Status
    [String] $Result
    [String] $Link

    BuildInfo([AzureDevOpsApi] $AzureDevOpsApi, [object] $Build)
    {
        $this.AzureDevOpsApi = $AzureDevOpsApi
        $this.Id = $Build.id
        $this.Name = $Build.buildNumber
        $this.Link = $Build._links.web.href
        $this.Status = $Build.status
        $this.Result = $Build.result
    }

    [boolean] IsFinished() {
        return ($this.Status -eq "completed") -or ($this.Status -eq "cancelling")
    }

    [boolean] IsSuccess() {
        return $this.Result -eq "succeeded"
    }

    [void] UpdateBuildInfo() {
        $buildInfo = $this.AzureDevOpsApi.GetBuildInfo($this.Id)
        $this.Status = $buildInfo.status
        $this.Result = $buildInfo.result
    }
}

function Get-BuildInfo {
    param (
        [AzureDevOpsApi] $AzureDevOpsApi,
        [object] $Build
    )

    return [BuildInfo]::New($AzureDevOpsApi, $Build)
}