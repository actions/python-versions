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

        ### To build Python with SO we must pass full path to lib folder to the linker
        $env:LDFLAGS="-Wl,--rpath=${pythonBinariesLocation}/lib"
        $configureString = "./configure"
        $configureString += " --prefix=$pythonBinariesLocation"
        $configureString += " --enable-shared"
        $configureString += " --enable-optimizations"

        ### Compile with ucs4 for Python 2.x. On 3.x, ucs4 is enabled by default
        if ($this.Version -lt "3.0.0") {
            $configureString += " --enable-unicode=ucs4"
        }

        ### Compile with support of loadable sqlite extensions. Unavailable for Python 2.*
        ### Link to documentation (https://docs.python.org/3/library/sqlite3.html#sqlite3.Connection.enable_load_extension)
        if ($this.Version -ge "3.2.0") {
            $configureString += " --enable-loadable-sqlite-extensions"
        }

        if ($this.Version -ge "3.11.0") {
            $configureString += "CC=gcc CXX=g++ TCLTK_CFLAGS=-I/usr/include/tcl8.6   TCLTK_LIBS=`"-ltcl8.6 -ltk8.6`""
        }

        Execute-Command -Command $configureString
    }

    [void] PrepareEnvironment() {
        <#
        .SYNOPSIS
        Prepare system environment by installing dependencies and required packages.
        #>

        if (($this.Version -gt "3.0.0") -and ($this.Version -lt "3.5.3")) {
            Write-Host "Python3 versions lower than 3.5.3 are not supported"
            exit 1
        }

        ### Compile with tkinter support
        if ($this.Version -gt "3.0.0") {
            $tkinterInstallString = "sudo apt-get install -y --allow-downgrades python3-tk tk-dev"
        } else {
            $tkinterInstallString = "sudo apt install -y python-tk tk-dev"
        }

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
            "libgdbm-dev"
        ) | ForEach-Object {
            Execute-Command -Command "sudo apt install -y $_"
        }
   
        if ($this.Platform -eq "linux-18.04" -or ($this.Platform -ne "linux-18.04")) {
            ### On Ubuntu-1804, libgdbm-compat-dev has older modules that are no longer in libgdbm-dev
            Write-Host "Work around" 
            Execute-Command -Command "sudo add-apt-repository ppa:deadsnakes/ppa -y"
            Execute-Command -Command "sudo apt update"
            Execute-Command -Command "sudo apt install python3.11-tk"
            Execute-Command -Command "sudo apt install tcl8.6 tcl8.6-dev tk8.6 tk8.6-dev"
        }

        ### On Ubuntu-1804, libgdbm-compat-dev has older modules that are no longer in libgdbm-dev
        Execute-Command -Command "sudo apt install -y libgdbm-compat-dev"
    }
}
