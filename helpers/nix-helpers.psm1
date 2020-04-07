<#
.SYNOPSIS
Pack folder to *.zip format
#>
function Pack-Zip {
    param(
        [Parameter(Mandatory=$true)]
        [String]$PathToArchive,
        [Parameter(Mandatory=$true)]
        [String]$ToolZipFile
    )

    Write-Debug "Pack $PathToArchive to $ToolZipFile"
    Push-Location -Path $PathToArchive
    zip -q -r $ToolZipFile * | Out-Null
    Pop-Location
}

<#
.SYNOPSIS
Unpack *.tar file
#>
function Unpack-TarArchive {
    param(
        [Parameter(Mandatory=$true)]
        [String]$ArchivePath,
        [Parameter(Mandatory=$true)]
        [String]$OutputDirectory
    )

    Write-Debug "Unpack $ArchivePath to $OutputDirectory"
    tar -C $OutputDirectory -xzf $ArchivePath

}