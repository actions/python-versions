$ErrorActionPreference = "Stop"

[String]$Architecture = "{{__ARCHITECTURE__}}"
[Version]$Version = "{{__VERSION__}}"
[String]$PythonExecName = "{{__PYTHON_EXEC_NAME__}}"

function Get-ArchitectureFilter {
    param(
        [Parameter (Mandatory = $true)]
        [String]$Architecture
    )

    if ($Architecture -eq 'x86') {
        "32-bit"
    } else {
        "64-bit"
    }
}

function Get-PythonFilter {
    param(
        [Parameter (Mandatory = $true)]
        [String]$ArchFilter,
        [Parameter (Mandatory = $true)]
        [String]$Architecture,
        [Parameter (Mandatory = $true)]
        [Boolean]$IsMSI,
        [Parameter (Mandatory = $true)]
        [Int32]$MajorVersion,
        [Parameter (Mandatory = $true)]
        [Int32]$MinorVersion
    )

    ### Python 2.7 have no architecture postfix
    if ($IsMSI -and $Architecture -eq "x86") {
        "(Name like '%Python%%$MajorVersion.$MinorVersion%') and (not (Name like '%64-bit%'))"
    } else {
        "Name like '%Python%%$MajorVersion.$MinorVersion%%$ArchFilter%'"
    }
}

function Uninstall-Python {
    param(
        [Parameter (Mandatory = $true)]
        [String]$Architecture,
        [Parameter (Mandatory = $true)]
        [Boolean]$IsMSI,
        [Parameter (Mandatory = $true)]
        [Int32]$MajorVersion,
        [Parameter (Mandatory = $true)]
        [Int32]$MinorVersion
    )

    $ArchFilter = Get-ArchitectureFilter -Architecture $Architecture
    Write-Host "Check for installed Python$MajorVersion.$MinorVersion $ArchFilter WMI..."
    $PythonFilter = Get-PythonFilter -ArchFilter $ArchFilter -Architecture $Architecture -IsMSI $IsMSI -MajorVersion $MajorVersion -MinorVersion $MinorVersion
    Get-WmiObject Win32_Product -Filter $PythonFilter | Foreach-Object { 
        Write-Host "Uninstalling $($_.Name) ..."
        $_.Uninstall() | Out-Null 
    }
}

function Delete-PythonVersion {
    param(
        [Parameter (Mandatory = $true)]
        [System.IO.FileSystemInfo]$InstalledVersion,
        [Parameter (Mandatory = $true)]
        [String]$Architecture
    )

    Remove-Item -Path "$($InstalledVersion.FullName)/$Architecture" -Recurse -Force
    Remove-Item -Path "$($InstalledVersion.FullName)/$Architecture.complete" -Force  
}

function Get-ExecParams {
    param(
        [Parameter (Mandatory = $true)]
        [Boolean]$IsMSI,
        [Parameter (Mandatory = $true)]
        [String]$PythonArchPath
    )

    if ($IsMSI) {
        "TARGETDIR=$PythonArchPath ALLUSERS=1"
    } else {
        "DefaultAllUsersTargetDir=$PythonArchPath InstallAllUsers=1"
    }
}

$ToolcacheRoot = $env:AGENT_TOOLSDIRECTORY
if ([string]::IsNullOrEmpty($ToolcacheRoot)) {
    # GitHub images don't have `AGENT_TOOLSDIRECTORY` variable
    $ToolcacheRoot = $env:RUNNER_TOOL_CACHE
}
$PythonToolcachePath = Join-Path -Path $ToolcacheRoot -ChildPath "Python"
$PythonVersionPath = Join-Path -Path $PythonToolcachePath -ChildPath $Version.ToString()
$PythonArchPath = Join-Path -Path $PythonVersionPath -ChildPath $Architecture

$IsMSI = $PythonExecName -match "msi"

$MajorVersion = $Version.Major
$MinorVersion = $Version.Minor

Write-Host "Check if Python hostedtoolcache folder exist..."
if (-Not (Test-Path $PythonToolcachePath)) {
    Write-Host "Create Python toolcache folder"
    New-Item -ItemType Directory -Path $PythonToolcachePath | Out-Null
} else {
    Write-Host "Check if current Python version is installed..."
    $InstalledVersion = Get-ChildItem -Path $PythonToolcachePath -Filter "$MajorVersion.$MinorVersion.*"

    if ($InstalledVersion -ne $null) {
        Uninstall-Python -Architecture $Architecture -IsMSI $IsMSI -MajorVersion $MajorVersion -MinorVersion $MinorVersion

        if (Test-Path -Path "$($InstalledVersion.FullName)/$Architecture") {
            Write-Host "Python$MajorVersion.$MinorVersion/$Architecture was found in $PythonToolcachePath"
            Write-Host "Delete Python$MajorVersion.$MinorVersion $Architecture"
            Delete-PythonVersion -InstalledVersion $InstalledVersion -Architecture $Architecture
        }
    } else {
        Write-Host "No Python$MajorVersion.$MinorVersion.* found"
    }
}

Write-Host "Create Python $Version folder in $PythonToolcachePath"
New-Item -ItemType Directory -Path $PythonArchPath -Force | Out-Null

Write-Host "Copy Python binaries to $PythonArchPath"
Copy-Item -Path ./$PythonExecName -Destination $PythonArchPath | Out-Null

Write-Host "Install Python $Version in $PythonToolcachePath..."
$ExecParams = Get-ExecParams -IsMSI $IsMSI -PythonArchPath $PythonArchPath

cmd.exe /c "cd $PythonArchPath && call $PythonExecName $ExecParams /quiet"
if ($LASTEXITCODE -ne 0) {
    Throw "Error happened during Python installation"
}

$PythonExePath = Join-Path -Path $PythonArchPath -ChildPath "python.exe"
cmd.exe /c "$PythonExePath --version && $PythonExePath -m ensurepip && $PythonExePath -m pip install --upgrade pip"

Write-Host "Create complete file"
New-Item -ItemType File -Path $PythonVersionPath -Name "$Architecture.complete" | Out-Null
