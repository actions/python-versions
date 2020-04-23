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

    Write-Debug "tar -C $OutputDirectory -xzf $ArchivePath"
    tar -C $OutputDirectory -xzf $ArchivePath
}

function Create-TarArchive {
    param(
        [Parameter(Mandatory=$true)]
        [String]$SourceFolder,
        [Parameter(Mandatory=$true)]
        [String]$ArchivePath,
        [string]$CompressionType = "gz"
    )

    $CompressionTypeArgument = If ([string]::IsNullOrWhiteSpace($CompressionType)) { "" } else { "--${CompressionType}" }

    Push-Location $SourceFolder
    Write-Debug "tar -c $CompressionTypeArgument -f $ArchivePath ."
    tar -c $CompressionTypeArgument -f $ArchivePath .
    Pop-Location
}