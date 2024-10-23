using module "./nix-python-builder.psm1"

class macOSPythonBuilder : NixPythonBuilder {
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

    macOSPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) { }

    [void] PrepareEnvironment() {
        <#
        .SYNOPSIS
        Prepare system environment by installing dependencies and required packages.
        #>
    }

    [void] Configure() {
        <#
        .SYNOPSIS
        Execute configure script with required parameters.
        #>

        $pythonBinariesLocation = $this.GetFullPythonToolcacheLocation()
        $configureString = "./configure"
        $configureString += " --prefix=$pythonBinariesLocation"
        $configureString += " --enable-optimizations"
        $configureString += " --enable-shared"
        $configureString += " --with-lto"

        ### For Python versions which support it, compile a universal2 (arm64 + x86_64 hybrid) build. The arm64 slice
        ### will never be used itself by a Github Actions runner but using a universal2 Python is the only way to build
        ### universal2 C extensions and wheels. This is supported by Python >= 3.10 and was backported to Python >=
        ### 3.9.1 and >= 3.8.10.
        ### Disabled, discussion: https://github.com/actions/python-versions/pull/114
        # if ($this.Version -ge "3.8.10" -and $this.Version -ne "3.8.13" -and $this.Version -ne "3.9.0" ) {
        #     $configureString += " --enable-universalsdk --with-universal-archs=universal2"
        # }

        ### OS X 10.11, Apple no longer provides header files for the deprecated system version of OpenSSL.
        ### Solution is to install these libraries from a third-party package manager,
        ### and then add the appropriate paths for the header and library files to configure command.
        ### Link to documentation (https://cpython-devguide.readthedocs.io/setup/#build-dependencies)
        $configureString += " --with-openssl=/usr/local/opt/openssl@1.1"
        $configureString += " --with-tcltk-includes='-I /usr/local/opt/tcl-tk/include' --with-tcltk-libs='-L/usr/local/opt/tcl-tk/lib -ltcl8.6 -ltk8.6'"
        $configureString += " --enable-loadable-sqlite-extensions"
        $env:LDFLAGS += " -L$(brew --prefix sqlite3)/lib"
        $env:CFLAGS += " -I$(brew --prefix sqlite3)/include"
        $env:CPPFLAGS += "-I$(brew --prefix sqlite3)/include"

        Write-Host "The passed configure options are: "
        Write-Host $configureString

        Execute-Command -Command $configureString
    }

    [string] GetPkgName() {
        <#
        .SYNOPSIS
        Return Python installation Package.
        #>

        $nativeVersion = Convert-Version -version $this.Version
        $architecture = "-macos11"
        $extension = ".pkg"

        $pkg = "python-${nativeVersion}${architecture}${extension}"

        return $pkg
    }

    [uri] GetPkgUri() {
        <#
        .SYNOPSIS
        Get base Python URI and return complete URI for Python installation package.
        #>

        $base = $this.GetBaseUri()
        $versionName = $this.GetBaseVersion()
        $pkg = $this.GetPkgName()

        $uri = "${base}/${versionName}/${pkg}"

        return $uri
    }

    [string] DownloadPkg() {
        <#
        .SYNOPSIS
        Download Python installation executable into artifact location.
        #>

        $pkgUri = $this.GetPkgUri()

        Write-Host "Sources URI: $pkgUri"
        $pkgLocation = Download-File -Uri $pkgUri -OutputFolder $this.WorkFolderLocation
        Write-Debug "Done; Package location: $pkgLocation"

        New-Item -Path $this.WorkFolderLocation -Name "build_output.txt"  -ItemType File
        return $pkgLocation
    }

    [void] CreateInstallationScriptPkg() {
        <#
        .SYNOPSIS
        Create Python artifact installation script based on specified template.
        #>

        $installationTemplateLocation = Join-Path -Path $this.InstallationTemplatesLocation -ChildPath "macos-pkg-setup-template.sh"
        $installationTemplateContent = Get-Content -Path $installationTemplateLocation -Raw
        $installationScriptLocation = New-Item -Path $this.WorkFolderLocation -Name $this.InstallationScriptName  -ItemType File

        $variablesToReplace = @{
            "{{__VERSION_FULL__}}" = $this.Version;
            "{{__PKG_NAME__}}" = $this.GetPkgName();
            "{{__ARCH__}}" = $this.Architecture;
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

        $PkgVersion = [semver]"3.11.0-beta.1"

        if (($this.Version -ge $PkgVersion) -or ($this.Architecture -eq "arm64")) {
            Write-Host "Download Python $($this.Version) [$($this.Architecture)] package..."
            $this.DownloadPkg()

            Write-Host "Create installation script..."
            $this.CreateInstallationScriptPkg()
        } else {
            ([NixPythonBuilder]$this).Build()
        }

        Write-Host "Archive artifact"
        $this.ArchiveArtifact()
    }
}
