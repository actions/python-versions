using module "./nix-python-builder.psm1"

class UbuntuPythonBuilder : NixPythonBuilder {
    <#
    .SYNOPSIS
    Ubuntu Python builder class.

    .DESCRIPTION
    Contains methods that required to build Ubuntu Python artifact from sources. Inherited from base NixPythonBuilder.

    .PARAMETER platform
    The full name of platform for which Python should be built.

    .PARAMETER version
    The version of Python that should be built.

    #>

    UbuntuPythonBuilder(
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

        ### To build Python with SO, passing relative path W.r.t to the binary location.
        $env:LDFLAGS="-Wl,-rpath='`$`$ORIGIN/../lib'"
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

        ### Compile with support of loadable sqlite extensions.
        ### Link to documentation (https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.enable_load_extension)
        $configureString += " --enable-loadable-sqlite-extensions"

        Write-Host "The passed configure options are: "
        Write-Host $configureString
        Write-Host "LDFLAGS: $env:LDFLAGS"

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

        ### Compile with tkinter support
        $tkinterInstallString = "sudo apt-get install -y --allow-downgrades python3-tk tk-dev"

        Execute-Command -Command "sudo apt-get update"
        Execute-Command -Command $tkinterInstallString

        ### Install dependent packages
        @(
            "make",
            "build-essential",
            "libssl-dev",
            "zlib1g-dev",
            "libbz2-dev",
            "libsqlite3-dev",
            "libncursesw5-dev",
            "libreadline-dev",
            "libgdbm-dev",
            "liblzma-dev"
        ) | ForEach-Object {
            Execute-Command -Command "sudo apt install -y $_"
        }

        ### On Ubuntu-1804, libgdbm-compat-dev has older modules that are no longer in libgdbm-dev
        Execute-Command -Command "sudo apt install -y libgdbm-compat-dev"
    }
}
