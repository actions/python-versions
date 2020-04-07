using module "./builders/python-builder.psm1"

class WinPythonBuilder : PythonBuilder {
    <#
    .SYNOPSIS
    Base Python builder class for Windows systems.

    .DESCRIPTION
    Contains methods required for build Windows Python artifact. Inherited from base PythonBuilder class.

    .PARAMETER version
    The version of Python that should be built.

    .PARAMETER architecture
    The architecture with which Python should be built.

    .PARAMETER InstallationTemplateName
    The name of installation script template that will be used in generated artifact.

    #>

    [string] $InstallationTemplateName

    WinPythonBuilder(
        [version] $version,
        [string] $architecture
    ) : Base($version, $architecture) {
        $this.InstallationTemplateName = "win-setup-template.ps1"
    }

    [string] GetPythonExtension() {
        <#
        .SYNOPSIS
        Return extension for required version of Python executable. 
        #>

        $extension = if ($this.Version -lt "3.5" -and $this.Version -ge "2.5") { ".msi" } else { ".exe" }

        return $extension
    }

    [string] GetArchitectureExtension() {
        <#
        .SYNOPSIS
        Return architecture suffix for Python executable. 
        #>

        $ArchitectureExtension = ""
        if ($this.Architecture -eq "x64") {
            if ($this.Version -ge "3.5") {
                $ArchitectureExtension = "-amd64"
            } else {
                $ArchitectureExtension = ".amd64"
            }
        }

        return $ArchitectureExtension
    }

    [uri] GetSourceUri() {
        <#
        .SYNOPSIS
        Get base Python URI and return complete URI for Python installation executable.
        #>

        $base = $this.GetBaseUri()
        $architecture = $this.GetArchitectureExtension()
        $extension = $this.GetPythonExtension()

        $uri = "${base}/$($this.Version)/python-$($this.Version)${architecture}${extension}"

        return $uri
    }

    [string] Download() {
        <#
        .SYNOPSIS
        Download Python installation executable into artifact location.
        #>

        $sourceUri = $this.GetSourceUri()

        Write-Host "Sources URI: $sourceUri"
        $sourcesLocation = Download-File -Uri $sourceUri -OutputFolder $this.ArtifactLocation
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
        $installationScriptLocation = New-Item -Path $this.ArtifactLocation -Name $this.InstallationScriptName -ItemType File

        $variablesToReplace = @{
            "{{__ARCHITECTURE__}}" = $this.Architecture;
            "{{__VERSION__}}" = $this.Version;
            "{{__PYTHON_EXEC_NAME__}}" = $pythonExecName
        }

        $variablesToReplace.keys | ForEach-Object { $installationTemplateContent = $installationTemplateContent.Replace($_, $variablesToReplace[$_]) }
        $installationTemplateContent | Out-File -FilePath $installationScriptLocation
        Write-Debug "Done; Installation script location: $installationScriptLocation)"
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
    }
}
