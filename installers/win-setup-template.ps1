$ErrorActionPreference = "Stop"

[String] $Architecture = "{{__ARCHITECTURE__}}"
[Version] $Version = "{{__VERSION__}}"
[String] $PythonExecName = "{{__PYTHON_EXEC_NAME__}}"

function Uninstall-Python
{
    param
    (
        [Parameter(Mandatory)][String] $Architecture,
        [Parameter(Mandatory)][Int32] $MajorVersion,
        [Parameter(Mandatory)][Int32] $MinorVersion
    )

    $archFilter = if ($Architecture -eq 'x86') { "32-bit" } else { "64-bit" }
    ### Python 2.7 x86 have no architecture postfix
    $versionFilter = if (($Architecture -eq "x86") -and ($MajorVersion -eq 2))
    {
        "Python $MajorVersion.$MinorVersion.\d+$"
    }
    else
    {
        "Python $MajorVersion.$MinorVersion.*($archFilter)"
    }
    
    $regPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products"
    $regKeys = Get-ChildItem -Path Registry::$regPath -Recurse | Where-Object Property -Ccontains DisplayName
    foreach ($key in $regKeys)
    {
        if ($key.getValue("DisplayName") -match $versionFilter)
        {
            Remove-Item -Path $key.PSParentPath -Recurse -Force -Verbose
        }
    }

    $regPath = "HKEY_CLASSES_ROOT\Installer\Products"
    Get-ChildItem -Path Registry::$regPath | Where-Object {
        $productName = $_.GetValue("ProductName")
        return $productName -and $productName -match $versionFilter
    } | ForEach-Object {
        Remove-Item Registry::$_ -Recurse -Force -Verbose
    }
}

function Get-ExecParams {
    param
    (
        [Parameter(Mandatory)][Boolean] $IsMSI,
        [Parameter(Mandatory)][String] $PythonArchPath
    )

    if ($IsMSI) 
    {
        "TARGETDIR=$PythonArchPath ALLUSERS=1"
    } 
    else 
    {
        "DefaultAllUsersTargetDir=$PythonArchPath InstallAllUsers=1"
    }
}

$ToolcacheRoot = $env:AGENT_TOOLSDIRECTORY
if ([string]::IsNullOrEmpty($ToolcacheRoot))
{
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
if (-Not (Test-Path $PythonToolcachePath)) 
{
    Write-Host "Create Python toolcache folder"
    New-Item -ItemType Directory -Path $PythonToolcachePath | Out-Null
} 
else 
{
    Write-Host "Check if current Python version is installed..."
    $InstalledVersion = Get-ChildItem -Path $PythonToolcachePath -Filter "$MajorVersion.$MinorVersion.*"

    if ($null -ne $InstalledVersion)
    {
        Uninstall-Python -Architecture $Architecture -MajorVersion $MajorVersion -MinorVersion $MinorVersion

        if (Test-Path -Path "$($InstalledVersion.FullName)/$Architecture")
        {
            Write-Host "Python$MajorVersion.$MinorVersion/$Architecture was found in $PythonToolcachePath"
            Write-Host "Delete Python$MajorVersion.$MinorVersion $Architecture"
            Remove-Item -Path "$($InstalledVersion.FullName)/$Architecture" -Recurse -Force
            Remove-Item -Path "$($InstalledVersion.FullName)/$Architecture.complete" -Force
        }
    }
    else
    {
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
if ($LASTEXITCODE -ne 0)
{
    Throw "Error happened during Python installation"
}

$PythonExePath = Join-Path -Path $PythonArchPath -ChildPath "python.exe"
cmd.exe /c "$PythonExePath --version && $PythonExePath -m ensurepip && $PythonExePath -m pip install --upgrade pip"

Write-Host "Create complete file"
New-Item -ItemType File -Path $PythonVersionPath -Name "$Architecture.complete" | Out-Null
