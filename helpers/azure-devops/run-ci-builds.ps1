param (
    [Parameter(Mandatory)] [string] $TeamFoundationCollectionUri,
    [Parameter(Mandatory)] [string] $AzureDevOpsProjectName,
    [Parameter(Mandatory)] [string] $AzureDevOpsAccessToken,
    [Parameter(Mandatory)] [string] $SourceBranch,
    [Parameter(Mandatory)] [string] $ToolVersions,
    [Parameter(Mandatory)] [UInt32] $DefinitionId,
    [string] $SourceVersion
)

Import-Module (Join-Path $PSScriptRoot "azure-devops-api.ps1")
Import-Module (Join-Path $PSScriptRoot "build-info.ps1")

function Queue-Builds {
    param (
        [Parameter(Mandatory)] [AzureDevOpsApi] $AzureDevOpsApi,
        [Parameter(Mandatory)] [string] $ToolVersions,
        [Parameter(Mandatory)] [string] $SourceBranch,
        [Parameter(Mandatory)] [string] $SourceVersion,
        [Parameter(Mandatory)] [string] $DefinitionId
    )

    [BuildInfo[]]$queuedBuilds = @()

    $ToolVersions.Split(',') | ForEach-Object { 
        $version = $_.Trim()
        Write-Host "Queue build for $version..."
        $queuedBuild = $AzureDevOpsApi.QueueBuild($version, $SourceBranch, $SourceVersion, $DefinitionId)
        $buildInfo = Get-BuildInfo -AzureDevOpsApi $AzureDevOpsApi -Build $queuedBuild
        Write-Host "Queued build: $($buildInfo.Link)"
        $queuedBuilds += $buildInfo
    }

    return $queuedBuilds
}

function Wait-Builds {
    param (
        [Parameter(Mandatory)] [BuildInfo[]] $Builds
    )

    $timeoutBetweenRefreshSec = 30
    
    do {
        # If build is still running - refresh its status
        foreach($build in $builds) {
            if (!$build.IsFinished()) {
                $build.UpdateBuildInfo()
                
                if ($build.IsFinished()) {
                   Write-Host "The $($build.Name) build was completed: $($build.Link)"
                }
            }
        }
    
        $runningBuildsCount = ($builds | Where-Object { !$_.IsFinished() }).Length

        Start-Sleep -Seconds $timeoutBetweenRefreshSec
    } while($runningBuildsCount -gt 0)
}

function Make-BuildsOutput {
    param (
        [Parameter(Mandatory)] [BuildInfo[]] $Builds
    )

    Write-Host "Builds info:"
    $builds | Format-Table -AutoSize -Property Name,Id,Status,Result,Link | Out-String -Width 10000

    # Return exit code based on status of builds
    $failedBuilds = ($builds | Where-Object { !$_.IsSuccess() })
    if ($failedBuilds.Length -ne 0) {
        Write-Host "##vso[task.logissue type=error;]Builds failed"
        $failedBuilds | ForEach-Object -Process { Write-Host "##vso[task.logissue type=error;]Name: $($_.Name); Link: $($_.Link)" }
        Write-Host "##vso[task.complete result=Failed]"
    } else {
        Write-host "##[section] All builds have been passed successfully"
    }
}

$azureDevOpsApi = Get-AzureDevOpsApi -TeamFoundationCollectionUri $TeamFoundationCollectionUri `
                                     -ProjectName $AzureDevOpsProjectName `
                                     -AccessToken $AzureDevOpsAccessToken

$queuedBuilds = Queue-Builds -AzureDevOpsApi $azureDevOpsApi `
                             -ToolVersions $ToolVersions `
                             -SourceBranch $SourceBranch `
                             -SourceVersion $SourceVersion `
                             -DefinitionId $DefinitionId

Write-Host "Waiting results of builds ..."
Wait-Builds -Builds $queuedBuilds

Make-BuildsOutput -Builds $queuedBuilds
