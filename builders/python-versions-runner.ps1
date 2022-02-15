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
    [array] $Versions,
    [Parameter (Mandatory=$false, HelpMessage="Whether to publish release for built version")]
    [switch] $PublishRelease
)

function Invoke-Workflow {
    param (
        $Version
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

    while ($workflowToCheck.status -ne "completed") {
        while (!$workflowToCheck) {
            Start-Sleep -seconds 40
            $workflowRuns = (Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs").workflow_runs | Where-Object {$_.status -like "*progress*" -and $_.id -ne $env:GITHUB_RUN_ID}
            $workflowToCheck = $workflowRuns | Where-Object {
                ((Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($_.id)/jobs").jobs.steps.name -like "*$version").Count -gt 0
            }
            $retries ++
            if ($retries -gt 10) {
                Write-Host "No workflow triggered for version $version or something went wrong with fetching its status"
                $result = [PSCustomObject]@{
                    Version = $version;
                    Conclusion = "failure";
                    Url = "Not run"
                }
                return $result
                break
            }
        }

        Start-Sleep -Seconds 120
        $workflowToCheck = Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($workflowToCheck.id)"
        Write-Host "Workflow run with Id: $($workflowToCheck.id) for version '$($version)' - status '$($workflowToCheck.status)'"
    }
    $result = [PSCustomObject]@{
        Version = $version;
        Conclusion = $workflowToCheck.conclusion;
        Url = $workflowToCheck.html_url
    }
    if ($workflowToCheck.conclusion -ne "success") {
        Write-Host "Triggered workflow for version '$($version)' completed with result '$($workflowToCheck.conclusion)'. Check logs: $($workflowToCheck.html_url)"
        return $result
        break
    }
    Write-Host "Triggered workflow for version '$($version)' succeeded; Url: $($workflowToCheck.html_url)"
    return $result
}

$summary = $Versions | ForEach-Object -Parallel {Invoke-Workflow -Version $_ }
Write-Host "Results of triggered workflows:"
Write-Host $summary
if ($result.Conclusion -contains "failure" -or $summary.Conclusion -contains "cancelled") {
    exit 1
}