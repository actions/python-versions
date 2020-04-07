[Version]$Version = "{{__VERSION__}}"

$PythonToolcachePath = Join-Path -Path $env:AGENT_TOOLSDIRECTORY -ChildPath "Python"
$PythonVersionPath = Join-Path -Path $PythonToolcachePath -ChildPath $Version.ToString()
$PythonArchPath = Join-Path -Path $PythonVersionPath -ChildPath "x64"

$ToolArchiveName = "tool.zip"
$PythonMajorBinary = "python$($Version.Major)"
$PythonMajorDotMinorBinary = "python$($Version.Major).$($Version.Minor)"

Write-Host "Check if Python hostedtoolcache folder exist..."
if (-Not (Test-Path $PythonToolcachePath)) {
    Write-Host "Create Python toolcache folder"
    New-Item -ItemType Directory -Path $PythonToolcachePath | Out-Null
} else {
    Write-Host "Check if current Python version is installed..."
    if (Test-Path -Path $PythonVersionPath) {
        Write-Host "Python$Version was found in $PythonToolcachePath"
        Write-Host "Delete Python$Version..."
        Remove-Item -Path $PythonVersionPath -Recurse -Force | Out-Null
    } else {
        Write-Host "No Python$Version found"
    }
}

Write-Host "Create Python $Version folder in $PythonToolcachePath"
New-Item -ItemType Directory -Path $PythonArchPath -Force | Out-Null

Write-Host "Copy Python binaries to hostedtoolcache folder"
Copy-Item -Path $ToolArchiveName -Destination $PythonArchPath | Out-Null

Set-Location -Path $PythonArchPath
Write-Host "Unzip python to $PythonArchPath"
Expand-Archive -Path $ToolArchiveName -Destination "."

Write-Host "Remove temporary files..."
Remove-Item -Path $ToolArchiveName | Out-Null

Write-Host "Create additional symlinks"
ln -s ./bin/$PythonMajorDotMinorBinary python

Set-Location -Path "./bin"
if (-not (Test-Path "./python")) {
    ln -s $PythonMajorDotMinorBinary python
}

chmod +x ../python $PythonMajorBinary $PythonMajorDotMinorBinary python

Write-Host "Upgrading PIP..."
./python -m ensurepip
./python -m pip install --ignore-installed pip

Write-Host "Create complete file"
New-Item -ItemType File -Path $PythonVersionPath -Name "x64.complete" | Out-Null