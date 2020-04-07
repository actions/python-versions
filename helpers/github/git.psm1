<#
.SYNOPSIS
Configure git credentials to use with commits
#>
function Git-ConfigureUser {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [string] $Email
    )

    git config --global user.name $Name | Out-Host
    git config --global user.email $Email | Out-Host

    if ($LASTEXITCODE -ne 0) {
        Write-Host "##vso[task.logissue type=error;] Unexpected failure occurs while configuring git preferences."
        exit 1
    }
}

<#
.SYNOPSIS
Create new branch
#>
function Git-CreateBranch {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    git checkout -b $Name | Out-Host

    if ($LASTEXITCODE -ne 0) {
        Write-Host "##vso[task.logissue type=error;] Unexpected failure occurs while creating new branch: $Name."
        exit 1
    }
}

<#
.SYNOPSIS
Commit all staged and unstaged changes
#>
function Git-CommitAllChanges {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Message
    )

    git add -A | Out-Host
    git commit -m "$Message" | Out-Host

    if ($LASTEXITCODE -ne 0) {
        Write-Host "##vso[task.logissue type=error;] Unexpected failure occurs while commiting changes."
        exit 1
    }
}

<#
.SYNOPSIS
Push branch to remote repository
#>
function Git-PushBranch {
    Param (
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [boolean] $Force
    )

    if ($Force) {
        git push --set-upstream origin $Name --force | Out-Host
    } else {
        git push --set-upstream origin $Name | Out-Host
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "##vso[task.logissue type=error;] Unexpected failure occurs while pushing changes."
        exit 1
    }
}