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

        if ($this.Version -eq "3.7.17") {
            # We have preinstalled ncurses and readLine on the hoster runners. But we need to install bzip2 for
            # setting up an environment
            # If we get any issues realted to ncurses or readline we can try to run this command
            # brew install ncurses readline
            Execute-Command -Command "brew install bzip2"
        }
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
        if ($this.Version -lt "3.7.0") {
            $env:LDFLAGS = "-L$(brew --prefix openssl@1.1)/lib -L$(brew --prefix zlib)/lib"
            $env:CFLAGS = "-I$(brew --prefix openssl@1.1)/include -I$(brew --prefix zlib)/include"
        } else {
            $configureString += " --with-openssl=$(brew --prefix openssl@1.1)"

            # Configure may detect libintl from non-system sources, such as Homebrew (it **does** on macos arm64) so turn it off
            # $configureString += " ac_cv_lib_intl_textdomain=no"
            # This has libintl.a in there, so hopefully it picks it up
            $env:LDFLAGS = "-L$(brew --prefix gettext)/lib"
            $env:CFLAGS = "-I$(brew --prefix gettext)/include"

            # For Python 3.7.2 and 3.7.3 we need to provide PATH for zlib to pack it properly. Otherwise the build will fail
            # with the error: zipimport.ZipImportError: can't decompress data; zlib not available
            if ($this.Version -eq "3.7.2" -or $this.Version -eq "3.7.3" -or $this.Version -eq "3.7.17") {
                $env:LDFLAGS += " -L$(brew --prefix zlib)/lib"
                $env:CFLAGS += " -I$(brew --prefix zlib)/include"
            }

            if ($this.Version -ge "3.11.0") {
                # Python 3.11+: configure: WARNING: unrecognized options: --with-tcltk-includes, --with-tcltk-libs
                # https://github.com/python/cpython/blob/762f489b31afe0f0589aa784bf99c752044e7f30/Doc/whatsnew/3.11.rst#L2167-L2172
                $tcl_inc_dir = "$(brew --prefix tcl-tk)/include"
                # In Homebrew Tcl/Tk 8.6.13, headers have been moved to the 'tcl-tk' subdir
                if (Test-Path -Path "$tcl_inc_dir/tcl-tk") {
                    $tcl_inc_dir = "$tcl_inc_dir/tcl-tk"
                }
                $env:TCLTK_CFLAGS = "-I$tcl_inc_dir"
                $env:TCLTK_LIBS = "-L$(brew --prefix tcl-tk)/lib -ltcl8.6 -ltk8.6"
            } elseif ($this.Version -gt "3.7.12") {
                $configureString += " --with-tcltk-includes='-I $(brew --prefix tcl-tk)/include' --with-tcltk-libs='-L$(brew --prefix tcl-tk)/lib -ltcl8.6 -ltk8.6'"
            }

            if ($this.Version -eq "3.7.17") {
                $env:LDFLAGS += " -L$(brew --prefix bzip2)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix ncurses)/lib"
                $env:CFLAGS += " -I$(brew --prefix bzip2)/include -I$(brew --prefix readline)/include -I$(brew --prefix ncurses)/include"
            }
        }

        ### Compile with support of loadable sqlite extensions. Unavailable for Python 2.*
        ### Link to documentation (https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.enable_load_extension)
        if ($this.Version -ge "3.2.0") {
            $configureString += " --enable-loadable-sqlite-extensions"
            $env:LDFLAGS += " -L$(brew --prefix sqlite3)/lib"
            $env:CFLAGS += " -I$(brew --prefix sqlite3)/include"
            $env:CPPFLAGS += "-I$(brew --prefix sqlite3)/include"
        }

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
