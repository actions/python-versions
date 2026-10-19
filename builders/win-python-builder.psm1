using module "./python-builder.psm1"

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

    .PARAMETER InstallationScriptName
    The name of generated installation script.

    #>

    [string] $InstallationTemplateName
    [string] $InstallationScriptName
    [string] $OutputArtifactName
    [object] $WindowsPackage

    WinPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) {
        if ($this.IsFreeThreaded() -and ($version.Major -lt 3 -or ($version.Major -eq 3 -and $version.Minor -lt 13))) {
            throw "Free-threaded Windows builds require Python 3.13 or later."
        }
        $this.InstallationTemplateName = "win-setup-template.ps1"
        $this.InstallationScriptName = "setup.ps1"
        $this.OutputArtifactName = "python-$Version-$Platform-$Architecture.zip"
    }

    [string] GetPythonExtension() {
        <#
        .SYNOPSIS
        Return extension for the required Python distribution.
        #>

        if ($this.UsesZipPackage()) {
            return ".zip"
        }
        return ".exe"
    }

    [bool] UsesZipPackage() {
        return $this.Version.Major -gt 3 -or ($this.Version.Major -eq 3 -and $this.Version.Minor -ge 16)
    }

    [object] GetWindowsPackage() {
        if ($null -ne $this.WindowsPackage) {
            return $this.WindowsPackage
        }

        $nativeVersion = Convert-Version -version $this.Version
        $manifestUri = "$($this.GetBaseUri())/$($this.GetBaseVersion())/windows-${nativeVersion}.json"
        $manifest = Invoke-RestMethod -Uri $manifestUri -ErrorAction Stop
        $packageArchitecture = switch ($this.GetHardwareArchitecture()) {
            "x86" { "32" }
            "x64" { "64" }
            "arm64" { "arm64" }
            default { throw "Unsupported Windows architecture: $($this.Architecture)" }
        }
        $threadingSuffix = if ($this.IsFreeThreaded()) { "t" } else { "" }
        $packageSuffix = "$($this.Version.Major).$($this.Version.Minor)${threadingSuffix}-${packageArchitecture}"
        $packages = @($manifest.versions | Where-Object { $_.'sort-version' -eq $nativeVersion })
        # The test distribution includes the runtime as well as Lib/test and native test modules.
        $package = @($packages | Where-Object { $_.id -eq "pythontest-${packageSuffix}" })
        if ($package.Count -eq 0) {
            Write-Host "No test distribution for $packageSuffix; selecting the core runtime package."
            $package = @($packages | Where-Object { $_.id -eq "pythoncore-${packageSuffix}" })
        }
        if ($package.Count -ne 1) {
            throw "Expected one Windows package for Python $nativeVersion ($($this.Architecture)); found $($package.Count)."
        }
        if ($package[0].schema -ne 1 -or $package[0].hash.sha256 -notmatch '^[0-9a-fA-F]{64}$') {
            throw "Invalid Windows package metadata for Python $nativeVersion ($($this.Architecture))."
        }
        $packageUri = [uri] $package[0].url
        if (-not $packageUri.IsAbsoluteUri -or $packageUri.Scheme -ne "https" -or -not $packageUri.AbsolutePath.EndsWith(".zip")) {
            throw "Invalid Windows package URL: $packageUri"
        }

        $this.WindowsPackage = $package[0]
        return $this.WindowsPackage
    }

    [string] GetArchitectureExtension() {
        <#
        .SYNOPSIS
        Return architecture suffix for Python executable. 
        #>

        $ArchitectureExtension = ""
        if ($this.GetHardwareArchitecture() -eq "x64") {
            $ArchitectureExtension = "-amd64"
        } elseif ($this.GetHardwareArchitecture() -eq "arm64") {
                $ArchitectureExtension = "-arm64"
        }

        return $ArchitectureExtension
    }

    [uri] GetSourceUri() {
        <#
        .SYNOPSIS
        Return the URI for the Python distribution package.
        #>

        if ($this.UsesZipPackage()) {
            return [uri] $this.GetWindowsPackage().url
        }

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
        Download the Python distribution and verify ZIP package checksums.
        #>

        $sourceUri = $this.GetSourceUri()

        Write-Host "Sources URI: $sourceUri"
        $sourcesLocation = Download-File -Uri $sourceUri -OutputFolder $this.WorkFolderLocation
        if ($this.UsesZipPackage()) {
            $expectedHash = $this.GetWindowsPackage().hash.sha256
            $actualHash = (Get-FileHash -LiteralPath $sourcesLocation -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($actualHash -ne $expectedHash) {
                throw "SHA256 mismatch for $sourceUri. Expected $expectedHash; got $actualHash."
            }
        }
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
            "{{__HARDWARE_ARCHITECTURE__}}" = $this.GetHardwareArchitecture();
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
        Generate a Python artifact from the downloaded distribution package.
        #>

        Write-Host "Download Python $($this.Version) [$($this.Architecture)] package..."
        $this.Download()

        Write-Host "Create installation script..."
        $this.CreateInstallationScript()

        Write-Host "Archive artifact"
        $this.ArchiveArtifact()
    }
}
