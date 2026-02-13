using module "./python-builder.psm1"

class NixPythonBuilder : PythonBuilder {
    <#
    .SYNOPSIS
    Base Python builder class for *Nix systems.

    .DESCRIPTION
    Contains methods that required to build Python artifact for *nix systems. Inherited from base PythonBuilder class.

    .PARAMETER version
    The version of Python that should be built.

    .PARAMETER Platform
    The type of platform for which Python should be built.

    .PARAMETER PlatformVersion
    The version of platform for which Python should be built.

    .PARAMETER InstallationTemplateName
    The name of template that will be used to create installation script for generated Python artifact.

    .PARAMETER InstallationScriptName	
    The name of installation script that will be generated for Python artifact.

    .PARAMETER OutputArtifactName
    The name of archive with Python binaries that will be generated as part of Python artifact. 

    #>

    [string] $InstallationTemplateName
    [string] $InstallationScriptName
    [string] $OutputArtifactName

    NixPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) {
        $this.InstallationTemplateName = "nix-setup-template.sh"	
        $this.InstallationScriptName = "setup.sh"
        $this.OutputArtifactName = "python-$Version-$Platform-$Architecture.tar.gz"
    }

    [uri] GetSourceUri() {
        <#
        .SYNOPSIS
        Get base Python URI and return complete URI for Python sources.
        #>

        $base = $this.GetBaseUri()
        $versionName = $this.GetBaseVersion()
        $nativeVersion = Convert-Version -version $this.Version

        return "${base}/${versionName}/Python-${nativeVersion}.tgz"
    }

    [string] GetPythonBinary() {
        <#
        .SYNOPSIS
        Return name of Python binary.
        #>

        return "python3"
    }

    [string] Download() {
        <#
        .SYNOPSIS
        Download Python sources and extract them at temporary work folder. Returns expanded archive location path.
        #>

        $sourceUri = $this.GetSourceUri()
        Write-Host "Sources URI: $sourceUri"

        $archiveFilepath = Download-File -Uri $sourceUri -OutputFolder $this.WorkFolderLocation
        $expandedSourceLocation = Join-Path -Path $this.TempFolderLocation -ChildPath "SourceCode"
        New-Item -Path $expandedSourceLocation -ItemType Directory

        Extract-TarArchive -ArchivePath $archiveFilepath -OutputDirectory $expandedSourceLocation
        Write-Debug "Done; Sources location: $expandedSourceLocation"

        return $expandedSourceLocation
    }

    [void] CreateInstallationScript() {
        <#
        .SYNOPSIS
        Create Python artifact installation script based on template specified in InstallationTemplateName property.
        #>

        $installationScriptLocation = New-Item -Path $this.WorkFolderLocation -Name $this.InstallationScriptName -ItemType File
        $installationTemplateLocation = Join-Path -Path $this.InstallationTemplatesLocation -ChildPath $this.InstallationTemplateName

        $installationTemplateContent = Get-Content -Path $installationTemplateLocation -Raw

        $variablesToReplace = @{
            "{{__VERSION_FULL__}}" = $this.Version;
            "{{__ARCH__}}" = $this.Architecture;
        }
        $variablesToReplace.keys | ForEach-Object { $installationTemplateContent = $installationTemplateContent.Replace($_, $variablesToReplace[$_]) }

        $installationTemplateContent | Out-File -FilePath $installationScriptLocation

        Write-Debug "Done; Installation script location: $installationScriptLocation)"
    }

    [void] Make() {
        <#
        .SYNOPSIS
        Executes "make" and "make install" commands for configured build sources. Make output will be writen in build_output.txt located in artifact location folder.
        #>

        Write-Debug "make Python $($this.Version)-$($this.Architecture) $($this.Platform)"
        $buildOutputLocation = New-Item -Path $this.WorkFolderLocation -Name "build_output.txt" -ItemType File
        
        ### Skip test_bz2 during PGO profiling to work around libbz2 incompatibility
        ### on Ubuntu 22.04 ARM runners (testDecompressorChunksMaxsize failure).
        if (($this.Architecture -match "arm64") -and ($this.Platform -match "22\.04") -and ($this.Version -ge [semver]"3.15.0-alpha.3")) {
            Execute-Command -Command "make PROFILE_TASK='-m test --pgo --ignore test_bz2 -j0' 2>&1 | tee $buildOutputLocation" -ErrorAction Continue
        } else {
            Execute-Command -Command "make 2>&1 | tee $buildOutputLocation" -ErrorAction Continue
        }        
        Execute-Command -Command "make install" -ErrorAction Continue

        Write-Debug "Done; Make log location: $buildOutputLocation"
    }

    [void] CopyBuildResults() {
        $buildFolder = $this.GetFullPythonToolcacheLocation()
        Move-Item -Path "$buildFolder/*" -Destination $this.WorkFolderLocation
    }

    [void] ArchiveArtifact() {
        $OutputPath = Join-Path $this.ArtifactFolderLocation $this.OutputArtifactName
        Create-TarArchive -SourceFolder $this.WorkFolderLocation -ArchivePath $OutputPath
    }

    [void] Build() {
        <#
        .SYNOPSIS
        Build Python artifact from sources. 
        #>

        Write-Host "Prepare Python Hostedtoolcache location..."
        $this.PreparePythonToolcacheLocation()

        Write-Host "Prepare system environment..."
        $this.PrepareEnvironment()

        Write-Host "Download Python $($this.Version)[$($this.Architecture)] sources..."
        $sourcesLocation = $this.Download()

        Push-Location -Path $sourcesLocation
        Write-Host "Configure for $($this.Platform)..."
        $this.Configure()

        Write-Host "Make for $($this.Platform)..."
        $this.Make()
        Pop-Location

        Write-Host "Generate structure dump"
        New-ToolStructureDump -ToolPath $this.GetFullPythonToolcacheLocation() -OutputFolder $this.WorkFolderLocation

        Write-Host "Copying build results to destination location"
        $this.CopyBuildResults()

        Write-Host "Create installation script..."
        $this.CreateInstallationScript()

        Write-Host "Archive artifact..."
        $this.ArchiveArtifact()
    }
}
