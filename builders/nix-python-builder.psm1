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

        $archiveFilepath = Download-File -Uri $sourceUri -OutputFolder $this.TempFolderLocation
        $expandedSourceLocation = Join-Path -Path $this.TempFolderLocation -ChildPath "SourceCode"
        New-Item -Path $expandedSourceLocation -ItemType Directory

        Extract-TarArchive -ArchivePath $archiveFilepath -OutputDirectory $expandedSourceLocation
        Write-Debug "Done; Sources location: $expandedSourceLocation"

        return $expandedSourceLocation
    }

    [string] BuildLibmpdec() {
        <#
        .SYNOPSIS
        Build a static libmpdec for the _decimal module. Returns installation location path.
        #>

        $mpdecimalVersion = "4.0.1"
        $mpdecimalSha256 = "96d33abb4bb0070c7be0fed4246cd38416188325f820468214471938545b1ac8"
        $mpdecimalUri = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-${mpdecimalVersion}.tar.gz"
        Write-Host "libmpdec sources URI: $mpdecimalUri"

        $archiveFilepath = Download-File -Uri $mpdecimalUri -OutputFolder $this.TempFolderLocation
        $actualSha256 = (Get-FileHash -Path $archiveFilepath -Algorithm SHA256).Hash
        if ($actualSha256 -ne $mpdecimalSha256) {
            Write-Host "SHA256 mismatch for ${archiveFilepath}: expected $mpdecimalSha256, got $actualSha256"
            exit 1
        }

        $sourceLocation = Join-Path -Path $this.TempFolderLocation -ChildPath "mpdecimal-source"
        $installLocation = Join-Path -Path $this.TempFolderLocation -ChildPath "mpdecimal"
        New-Item -Path $sourceLocation -ItemType Directory
        Extract-TarArchive -ArchivePath $archiveFilepath -OutputDirectory $sourceLocation

        Push-Location -Path $sourceLocation
        ### _decimal is a shared extension module, so the static library has to be position independent.
        ### -O3 and -fvisibility=hidden match how CPython compiled its bundled libmpdec in the 3.14 builds:
        ### libmpdec's symbols stay private to _decimal, and big-number arithmetic doesn't get slower.
        Execute-Command -Command "./configure --prefix=$installLocation --disable-cxx --disable-shared CFLAGS='-fPIC -O3 -fvisibility=hidden'"
        Execute-Command -Command "make"
        Execute-Command -Command "make install"
        Pop-Location

        ### Execute-Command doesn't stop on failure, and without the library _decimal would silently be left out
        $libmpdecArchive = Join-Path -Path $installLocation -ChildPath "lib/libmpdec.a"
        if (-not (Test-Path $libmpdecArchive)) {
            Write-Host "libmpdec build failed, $libmpdecArchive is missing"
            exit 1
        }

        return $installLocation
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
        
        Execute-Command -Command "make 2>&1 | tee $buildOutputLocation" -ErrorAction Continue
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

        # Patch for 3.15.0a6: Fix test_bz2 BIG_DATA to ensure two compressed blocks
        # See: https://github.com/python/cpython/pull/145730
        if (($this.Architecture -match "arm64") -and ($this.Platform -match "22\.04") -and ($this.Version -eq [semver]"3.15.0-alpha.6")) {
            Write-Host "Applying patch for python/cpython#145730 (test_bz2 fix)..."
            Execute-Command -Command "curl -sL -o Lib/test/test_bz2.py https://raw.githubusercontent.com/python/cpython/19676e5fc28bdee8325a062a31ddeee60960cf75/Lib/test/test_bz2.py"
        }

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
