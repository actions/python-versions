class PythonBuilder {
    <#
    .SYNOPSIS
    Base Python builder class.

    .DESCRIPTION
    Base Python builder class that contains general builder methods.

    .PARAMETER Version
    The version of Python that should be built.

    .PARAMETER Architecture
    The architecture with which Python should be built.

    .PARAMETER HostedToolcacheLocation
    The location of hostedtoolcache artifacts. Using system AGENT_TOOLSDIRECTORY variable value.

    .PARAMETER TempFolderLocation
    The location of temporary files that will be used during Python generation. Using system BUILD_STAGINGDIRECTORY variable value.

    .PARAMETER ArtifactLocation
    The location of generated Python artifact. Using system environment BUILD_BINARIESDIRECTORY variable value.

    .PARAMETER InstallationTemplatesLocation
    The location of installation script template. Using "installers" folder from current repository.

    .PARAMETER InstallationScriptName
    The name of installation script that will be generated for Python artifact.

    #>

    [version] $Version
    [string] $Architecture
    [string] $HostedToolcacheLocation
    [string] $TempFolderLocation
    [string] $ArtifactLocation
    [string] $InstallationTemplatesLocation
    [string] $InstallationScriptName

    PythonBuilder ([version] $version, [string] $architecture) {
        $this.Version = $version
        $this.Architecture = $architecture

        $this.HostedToolcacheLocation = $env:AGENT_TOOLSDIRECTORY
        $this.TempFolderLocation = $env:BUILD_STAGINGDIRECTORY
        $this.ArtifactLocation = $env:BUILD_BINARIESDIRECTORY

        $this.InstallationTemplatesLocation = Join-Path -Path $PSScriptRoot -ChildPath "../installers"
        $this.InstallationScriptName = "setup.ps1"
    }

    [uri] GetBaseUri() {
        <#
        .SYNOPSIS
        Return base URI for Python build sources.
        #>

        return "https://www.python.org/ftp/python"
    }

    [string] GetPythonToolcacheLocation() {
        <#
        .SYNOPSIS
        Return path to Python hostedtoolcache folder.
        #>

        return "$($this.HostedToolcacheLocation)/Python"
    }

    [string] GetFullPythonToolcacheLocation() {
        <#
        .SYNOPSIS
        Return full path to hostedtoolcache Python folder.
        #>

        $pythonToolcacheLocation = $this.GetPythonToolcacheLocation()
        return "$pythonToolcacheLocation/$($this.Version)/$($this.Architecture)"
    }

    [void] PreparePythonToolcacheLocation() {
        <#
        .SYNOPSIS
        Prepare system hostedtoolcache folder for new Python version. 
        #>
        $pythonBinariesLocation = $this.GetFullPythonToolcacheLocation()

        if (Test-Path $pythonBinariesLocation) {
            Write-Host "Purge $pythonBinariesLocation folder..."
            Remove-Item $pythonBinariesLocation -Recurse -Force
        } else {
            Write-Host "Create $pythonBinariesLocation folder..."
            New-Item -ItemType Directory -Path $pythonBinariesLocation 
        }
    }
}
