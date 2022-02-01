<#
.SYNOPSIS
Generate Python artifact.

.DESCRIPTION
Script that triggering and fetching the result of the "Build python package" workflow with provided python version

.PARAMETER Version
Required parameter. Python version to trigger build for.

.PARAMETER PublishRelease
Switch parameter. Whether to publish release for built version.

#>

param(
    [Parameter (Mandatory=$true, HelpMessage="Python version to trigger build for")]
    [string] $Version,
    [Parameter (Mandatory=$false, HelpMessage="Whether to publish release for built version")]
    [switch] $PublishRelease
)

$payload = @{
    "ref" = "main"
    "inputs" = @{
        "VERSION" = "$Version"
        "PUBLISH_RELEASES" = "$PublishRelease"
    }
} | ConvertTo-Json
$headers = @{
    Authorization="Bearer $env:PERSONAL_TOKEN"
}

Invoke-RestMethod -uri "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/workflows/python-builder.yml/dispatches" -method POST -headers $headers -body $payload

while (!$workflowToCheck) {
    Start-Sleep -seconds 40
    $workflowRuns = (Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs").workflow_runs | Where-Object {$_.status -like "*progress*" -and $_.id -ne $env:GITHUB_RUN_ID}
    $workflowToCheck = $workflowRuns | Where-Object {
        ((Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($_.id)/jobs").jobs.steps.name -like "*$Version").Count -gt 0
    }
    $retries ++
    if ($retries -gt 10) {
        Write-Host "No workflow triggered or something went wrong with fetching its status"
        exit 1
    }
}

Write-Host "Triggered workflow with Id: $($workflowToCheck.id) , Url: $($workflowToCheck.url)"

while ($workflowToCheck.status -ne "completed") {
    Start-Sleep -Seconds 120
    $workflowToCheck = Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($workflowToCheck.id)"
    Write-Host "Workflow run with Id: $($workflowToCheck.id) - status '$($workflowToCheck.status)'"
}

if ($workflowToCheck.conclusion -ne "success") {
    Write-Host "Triggered workflow completed with result '$($workflowToCheck.conclusion)'. Check logs: $($workflowToCheck.logs_url)"
    exit 1
}

Write-Host "Triggered workflow succeeded; Url: $($workflowToCheck.url)"