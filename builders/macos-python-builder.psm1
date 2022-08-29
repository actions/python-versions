using module "./python-builder.psm1"

class macOSPythonBuilder : PythonBuilder {
    <#
    .SYNOPSIS
    MacOS Python builder class.

    .DESCRIPTION
    Contains methods that required to build macOS Python artifact from sources. Inherited from base NixPythonBuilder.
    
    While python.org provides precompiled binaries for macOS, switching to them risks breaking existing customers.
    If we wanted to start using the official binaries instead of building from source, we should avoid changing previous versions
    so we remain backwards compatible.

    .PARAMETER platform
    The full name of platform for which Python should be built.

    .PARAMETER version
    The version of Python that should be built.

    #>

    [string] $InstallationTemplateName
    [string] $InstallationScriptName
    [string] $OutputArtifactName

    macOSPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) {
        $this.InstallationTemplateName = "macos-setup-template.ps1"
        $this.InstallationScriptName = "setup.sh"
        $this.OutputArtifactName = "python-$Version-$Platform-$Architecture.zip"
    }

    [string] GetPythonExtension() {
        <#
        .SYNOPSIS
        Return extension for required version of Python package. 
        #>

        $extension = ".pkg"

        return $extension
    }

    [string] GetArchitectureExtension() {
        <#
        .SYNOPSIS
        Return architecture suffix for Python package. 
        #>

        $ArchitectureExtension = "-macos11"

        return $ArchitectureExtension
    }

    [uri] GetSourceUri() {
        <#
        .SYNOPSIS
        Get base Python URI and return complete URI for Python installation executable.
        #>

        $base = $this.GetBaseUri()
        $versionName = $this.GetBaseVersion()
        $nativeVersion = Convert-Version -version $this.Version
        $architecture = $this.GetArchitectureExtension()
        $extension = $this.GetPythonExtension()

        $uri = "${base}/${versionName}/python-${nativeVersion}${architecture}${extension}"

        return $uri
    }

    [string] Download() {
        <#
        .SYNOPSIS
        Download Python installation executable into artifact location.
        #>

        $sourceUri = $this.GetSourceUri()

        Write-Host "Sources URI: $sourceUri"
        $sourcesLocation = Download-File -Uri $sourceUri -OutputFolder $this.WorkFolderLocation
        Write-Debug "Done; Sources location: $sourcesLocation"

        return $sourcesLocation
    }

    [void] CreateInstallationScript() {
        <#
        .SYNOPSIS
        Create Python artifact installation script based on specified template.
        #>

        $sourceUri = $this.GetSourceUri()
        $pythonExecName = [IO.path]::GetFileName($sourceUri.AbsoluteUri)
        $installationTemplateLocation = Join-Path -Path $this.InstallationTemplatesLocation -ChildPath $this.InstallationTemplateName
        $installationTemplateContent = Get-Content -Path $installationTemplateLocation -Raw
        $installationScriptLocation = New-Item -Path $this.WorkFolderLocation -Name $this.InstallationScriptName -ItemType File

        $variablesToReplace = @{
            "{{__ARCHITECTURE__}}" = $this.Architecture;
            "{{__VERSION__}}" = $this.Version;
            "{{__PYTHON_EXEC_NAME__}}" = $pythonExecName
        }

        $variablesToReplace.keys | ForEach-Object { $installationTemplateContent = $installationTemplateContent.Replace($_, $variablesToReplace[$_]) }
        $installationTemplateContent | Out-File -FilePath $installationScriptLocation
        Write-Debug "Done; Installation script location: $installationScriptLocation)"
    }

    [void] ArchiveArtifact() {
        $OutputPath = Join-Path $this.ArtifactFolderLocation $this.OutputArtifactName
        Create-SevenZipArchive -SourceFolder $this.WorkFolderLocation -ArchivePath $OutputPath
    }

    [void] Build() {
        <#
        .SYNOPSIS
        Generates Python artifact from downloaded Python installation executable.
        #>

        Write-Host "Download Python $($this.Version) [$($this.Architecture)] executable..."
        $this.Download()

        Write-Host "Create installation script..."
        $this.CreateInstallationScript()

        Write-Host "Archive artifact"
        $this.ArchiveArtifact()
    }
}
