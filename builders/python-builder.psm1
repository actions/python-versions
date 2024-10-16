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

    .PARAMETER WithPyDebug
    The flag that indicates whether Python should be a debug build with the --with-pydebug configure option.

    .PARAMETER HostedToolcacheLocation
    The location of hostedtoolcache artifacts. Using system AGENT_TOOLSDIRECTORY variable value.

    .PARAMETER TempFolderLocation
    The location of temporary files that will be used during Python generation. Using system TEMP directory.

    .PARAMETER WorkFolderLocation
    The location of generated Python artifact. Using system environment BUILD_STAGINGDIRECTORY variable value.

    .PARAMETER ArtifactFolderLocation
    The location of generated Python artifact. Using system environment BUILD_BINARIESDIRECTORY variable value.

    .PARAMETER InstallationTemplatesLocation
    The location of installation script template. Using "installers" folder from current repository.

    #>

    [semver] $Version
    [string] $Architecture
    [string] $Platform
    [string] $HostedToolcacheLocation
    [string] $TempFolderLocation
    [string] $WorkFolderLocation
    [string] $ArtifactFolderLocation
    [string] $InstallationTemplatesLocation

    PythonBuilder ([semver] $version, [string] $architecture, [string] $platform) {
        $this.InstallationTemplatesLocation = Join-Path -Path $PSScriptRoot -ChildPath "../installers"

        $artifactDirectory = Join-Path $env:RUNNER_TEMP "artifact"
        $workDirectory = Join-Path $env:RUNNER_TEMP "work"

        New-Item -Force -Type Directory $artifactDirectory
        New-Item -Force -Type Directory $workDirectory

        $this.HostedToolcacheLocation = $env:RUNNER_TOOL_CACHE
        $this.TempFolderLocation = $env:RUNNER_TEMP
        $this.WorkFolderLocation =  $workDirectory
        $this.ArtifactFolderLocation = $artifactDirectory

        $this.Version = $version
        $this.Architecture = $architecture
        $this.Platform = $platform
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

    [string] GetBaseVersion() {
        <#
        .SYNOPSIS
        Return Major.Minor.Patch version string.
        #>

        return "$($this.Version.Major).$($this.Version.Minor).$($this.Version.Patch)"
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
