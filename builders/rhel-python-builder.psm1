using module "./nix-python-builder.psm1"

class RhelPythonBuilder : NixPythonBuilder {
    <#
    .SYNOPSIS
    RHEL Python builder class.

    .DESCRIPTION
    Contains methods that required to build RHEL Python artifact from sources. Inherited from base NixPythonBuilder.

    .PARAMETER platform
    The full name of platform for which Python should be built.

    .PARAMETER version
    The version of Python that should be built.

    #>

    RhelPythonBuilder(
        [semver] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) { }

    [void] Configure() {
        <#
        .SYNOPSIS
        Execute configure script with required parameters.
        #>

        $pythonBinariesLocation = $this.GetFullPythonToolcacheLocation()

        ### To build Python with SO we must pass full path to lib folder to the linker
        $env:LDFLAGS="-Wl,--rpath=${pythonBinariesLocation}/lib"
        $configureString = "./configure"
        $configureString += " --prefix=$pythonBinariesLocation"
        $configureString += " --enable-shared"
        $configureString += " --enable-optimizations"

        if ($this.IsFreeThreaded()) {
            if ($this.Version -lt "3.13.0") {
                Write-Host "Python versions lower than 3.13.0 do not support free threading"
                exit 1
            }
            $configureString += " --disable-gil"
        }

        ### Python 3.15+ skips _decimal unless it finds a system libmpdec, and the RHEL builder doesn't install mpdecimal.
        ### Linking a static copy also keeps the artifact from needing libmpdec on the runner.
        if ([semver]"$($this.Version.Major).$($this.Version.Minor)" -ge [semver]"3.15") {
            $libmpdecLocation = $this.BuildLibmpdec()
            $configureString += " LIBMPDEC_CFLAGS='-I$libmpdecLocation/include'"
            $configureString += " LIBMPDEC_LIBS='$libmpdecLocation/lib/libmpdec.a -lm'"
        }

        ### Compile with support of loadable sqlite extensions.
        ### Link to documentation (https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.enable_load_extension)
        $configureString += " --enable-loadable-sqlite-extensions"

        Write-Host "The passed configure options are: "
        Write-Host $configureString

        Execute-Command -Command $configureString
    }

    [void] PrepareEnvironment() {
        <#
        .SYNOPSIS
        Prepare system environment by installing dependencies and required packages.
        #>

        if ($this.Version -lt "3.9.0") {
            Write-Host "Python versions lower than 3.9.0 are not supported"
            exit 1
        }

        ### Install dependent packages
        @(
            "make",
            "gcc",
            "gcc-c++",
            "openssl-devel",
            "zlib-devel",
            "bzip2-devel",
            "sqlite-devel",
            "ncurses-devel",
            "readline-devel",
            "gdbm-devel",
            "xz-devel",
            "libffi-devel",
            "tk-devel"
        ) | ForEach-Object {
            Execute-Command -Command "sudo dnf install -y $_"
        }
    }
}
