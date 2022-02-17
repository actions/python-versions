function Invoke-Workflow {
    param (
        [string] $Version,
        [bool] $PublishRelease
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

    $result = [PSCustomObject]@{
        Version = $version
        Conclusion = "failure"
        Url = "Not run"
    }
    # Triggering workflow and verifying that it has been triggered with retries
    while (-not $workflowToCheck) {
        Start-Sleep -seconds 40
        $workflowRuns = (Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs").workflow_runs | Where-Object {$_.status -like "*progress*" -and $_.id -ne $env:GITHUB_RUN_ID}
        $workflowToCheck = $workflowRuns | Where-Object {
            (Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($_.id)/jobs").jobs.steps.name -like "*$version"
        }
        $retries++
        if ($retries -gt 10) {
            Write-Host "Workflow triggered for version '$version' not found or something went wrong with fetching the workflow status"
            return $result
        }
    }
    # Waiting for workflow to complete
    while ($workflowToCheck.status -ne "completed") {
        Start-Sleep -Seconds 120
        $workflowToCheck = Invoke-RestMethod "$env:GITHUB_API_URL/repos/$env:GITHUB_REPOSITORY/actions/runs/$($workflowToCheck.id)"
        Write-Host "Workflow run with Id: $($workflowToCheck.id) for version '$version' - status '$($workflowToCheck.status)'"
    }
    $result.Conclusion = $workflowToCheck.conclusion
    $result.Url = $workflowToCheck.html_url
    if ($workflowToCheck.conclusion -ne "success") {
        Write-Host "Triggered workflow for version '$version' completed unsuccessfully with result '$($workflowToCheck.conclusion)'. Check the logs: $workflowToCheck.html_url"
        return $result
    }
    Write-Host "Triggered workflow for version '$($version)' succeeded; Url: $($workflowToCheck.html_url)"
    return $result
}