<#
.SYNOPSIS
Pester extension that allows to run command and validate exit code
.EXAMPLE
"python file.py" | Should -ReturnZeroExitCode
#>
function ShouldReturnZeroExitCode {
    Param(
        [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
        [String]$ActualValue,
        [switch]$Negate
    )

    Write-Host "Run command '${ActualValue}'"
    Invoke-Expression -Command $ActualValue | ForEach-Object { Write-Host $_ }
    $actualExitCode = $LASTEXITCODE

    [bool]$succeeded = $actualExitCode -eq 0
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        $failureMessage = "Command '${ActualValue}' has finished with exit code ${actualExitCode}"
    }

    return New-Object PSObject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name ReturnZeroExitCode `
                    -Test  $function:ShouldReturnZeroExitCode
