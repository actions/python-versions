function Create-SevenZipArchive {
    param(
        [Parameter(Mandatory=$true)]
        [String]$SourceFolder,
        [Parameter(Mandatory=$true)]
        [String]$ArchivePath,
        [String]$ArchiveType = "zip",
        [String]$CompressionLevel = 5
    )

    $ArchiveTypeArgument = "-t${ArchiveType}"
    $CompressionLevelArgument = "-mx=${CompressionLevel}"
    
    Push-Location $SourceFolder
    Write-Debug "7z a $ArchiveTypeArgument $CompressionLevelArgument $ArchivePath @$SourceFolder"
    7z a $ArchiveTypeArgument $CompressionLevelArgument $ArchivePath $SourceFolder\*
    Pop-Location
}