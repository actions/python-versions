<#
.SYNOPSIS
The execute command and print all output to the logs
#>
function Execute-Command {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string] $Command
    )

    Write-Debug "Execute $Command"

    try {
        Invoke-Expression $Command | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Exit code: $LASTEXITCODE"}
    }
    catch {
        $errorMessage = "Error happened during command execution: $Command `n $_"
        Write-Host $errorMessage
        if ($ErrorActionPreference -ne "Continue") {
            # avoid logging Azure DevOps issues in case of $ErrorActionPreference -eq Continue
            Write-Host "##vso[task.logissue type=error;] $errorMessage"
        }
    }
}

<#
.SYNOPSIS
Download file from url and return local path to file
#>
function Download-File {
    param(
        [Parameter(Mandatory=$true)]
        [Uri]$Uri,
        [Parameter(Mandatory=$true)]
        [String]$OutputFolder
    )

    $targetFilename = [IO.Path]::GetFileName($Uri)
    $targetFilepath = Join-Path $OutputFolder $targetFilename

    Write-Debug "Download source from $Uri to $OutFile"
    try {
        (New-Object System.Net.WebClient).DownloadFile($Uri, $targetFilepath)
        return $targetFilepath
    } catch {
        Write-Host "Error during downloading file from '$Uri'"
        "$_"
        exit 1
    }    
}

<#
.SYNOPSIS
Generate file that contains the list of all files in particular directory
#>
function New-ToolStructureDump {
    param(
        [Parameter(Mandatory=$true)]
        [String]$ToolPath,
        [Parameter(Mandatory=$true)]
        [String]$OutputFolder
    )

    $outputFile = Join-Path $OutputFolder "tools_structure.txt"

    $folderContent = Get-ChildItem -Path $ToolPath -Recurse | Sort-Object | Select-Object -Property FullName, Length
    $folderContent | ForEach-Object {
        $relativePath = $_.FullName.Replace($ToolPath, "");
        return "${relativePath}"
    } | Out-File -FilePath $outputFile
}

<#
.SYNOPSIS
Check if it is macOS / Ubuntu platform
#>
function IsNixPlatform {
    param(
        [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()]
        [String]$Platform
    )

    return ($Platform -match "macos") -or ($Platform -match "ubuntu") -or ($Platform -match "linux")
}