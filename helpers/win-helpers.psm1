<#
.SYNOPSIS
Unpack *.7z file
#>
function Extract-SevenZipArchive {
    param(
        [Parameter(Mandatory=$true)]
        [String]$ArchivePath,
        [Parameter(Mandatory=$true)]
        [String]$OutputDirectory
    )

    Write-Debug "Extract $ArchivePath to $OutputDirectory"
    7z x $ArchivePath -o"$OutputDirectory" -y | Out-Null
}

function Create-SevenZipArchive {
    param(
        [Parameter(Mandatory=$true)]
        [String]$SourceFolder,
        [Parameter(Mandatory=$true)]
        [String]$ArchivePath,
        [String]$ArchiveType = "zip",
        [String]$CompressionLevel = 5,
        [switch]$IncludeSymlinks
    )

    $ArchiveTypeArguments = @(
        "-t${ArchiveType}",
        "-mx=${CompressionLevel}"
    )
    if ($IncludeSymlinks) {
        $ArchiveTypeArguments += "-snl"
    }
    Push-Location $SourceFolder
    Write-Debug "7z a $ArchiveTypeArgument $ArchivePath @$SourceFolder"
    7z a @ArchiveTypeArguments $ArchivePath $SourceFolder\*
    Pop-Location
}