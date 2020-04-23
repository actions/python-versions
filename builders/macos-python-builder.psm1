using module "./builders/nix-python-builder.psm1"

class macOSPythonBuilder : NixPythonBuilder {
    <#
    .SYNOPSIS
    MacOS Python builder class.

    .DESCRIPTION
    Contains methods that required to build macOS Python artifact from sources. Inherited from base NixPythonBuilder.

    .PARAMETER platform
    The full name of platform for which Python should be built.

    .PARAMETER version
    The version of Python that should be built.

    #>

    macOSPythonBuilder(
        [version] $version,
        [string] $architecture,
        [string] $platform
    ) : Base($version, $architecture, $platform) { }

    [void] Configure() {
        <#
        .SYNOPSIS
        Execute configure script with required parameters.
        #>

        $pythonBinariesLocation = $this.GetFullPythonToolcacheLocation()
        $configureString = "./configure --prefix=$pythonBinariesLocation --enable-optimizations --enable-shared --with-lto"

        ### Supress gcc warnings
        $env:CFLAGS="-w"

        ### OS X 10.11, Apple no longer provides header files for the deprecated system version of OpenSSL.
        ### Solution is to install these libraries from a third-party package manager,
        ### and then add the appropriate paths for the header and library files to configure command.
        ### Link to documentation (https://cpython-devguide.readthedocs.io/setup/#build-dependencies)
        if ($this.Version -lt "3.7.0") {
            $env:LDFLAGS="-L$(brew --prefix openssl)/lib"
            $env:CFLAGS="-I$(brew --prefix openssl)/include $($env:CFLAGS)"
        } else {
            $configureString += " --with-openssl=/usr/local/opt/openssl"
        }
        Write-Host $configureString

        Execute-Command -Command $configureString
    }

    [void] PrepareEnvironment() {
        <#
        .SYNOPSIS
        Prepare system environment by installing dependencies and required packages.
        #>

        ### reinstall header files to Avoid issue with X11 headers on Mojave
        $pkgName = "/Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg"
        Execute-Command -Command "sudo installer -pkg $pkgName -target /"
    }
}
