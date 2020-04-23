using module "./builders/win-python-builder.psm1"
using module "./builders/ubuntu-python-builder.psm1"
using module "./builders/macos-python-builder.psm1"

<#
.SYNOPSIS
Generate Python artifact.

.DESCRIPTION
Main script that creates instance of PythonBuilder and builds of Python using specified parameters.

.PARAMETER Version
Required parameter. The version with which Python will be built.

.PARAMETER Architecture
Optional parameter. The architecture with which Python will be built. Using x64 by default.

.PARAMETER Platform
Required parameter. The platform for which Python will be built.

#>

param(
    [Parameter (Mandatory=$true)][Version] $Version,
    [Parameter (Mandatory=$true)][string] $Platform,
    [string] $Architecture = "x64"
)

Import-Module (Join-Path $PSScriptRoot "../helpers" | Join-Path -ChildPath "common-helpers.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "../helpers" | Join-Path -ChildPath "nix-helpers.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "../helpers" | Join-Path -ChildPath "win-helpers.psm1") -DisableNameChecking

function Get-PythonBuilder {
    <#
    .SYNOPSIS
    Wrapper for class constructor to simplify importing PythonBuilder.

    .DESCRIPTION
    Create instance of PythonBuilder with specified parameters.

    .PARAMETER Version
    The version with which Python will be built.

    .PARAMETER Architecture
    The architecture with which Python will be built.

    .PARAMETER Platform
    The platform for which Python will be built.

    #>

    param (
        [version] $Version,
        [string] $Architecture,
        [string] $Platform
    )

    $Platform = $Platform.ToLower()  
    if ($Platform -match 'windows') {
        $builder = [WinPythonBuilder]::New($Version, $Architecture, $Platform)
    } elseif ($Platform -match 'ubuntu') {
        $builder = [UbuntuPythonBuilder]::New($Version, $Architecture, $Platform)
    } elseif ($Platform -match 'macos') {
        $builder = [macOSPythonBuilder]::New($Version, $Architecture, $Platform)
    } else {
        Write-Host "##vso[task.logissue type=error;] Invalid platform: $Platform"
        exit 1
    }

    return $builder
}

### Create Python builder instance, and build artifact
$Builder = Get-PythonBuilder -Version -Architecture $Architecture $Version -Platform $Platform 
$Builder.Build()
