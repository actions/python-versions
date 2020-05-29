param (
    [string] $ToolName
)

$targetPath = $env:AGENT_TOOLSDIRECTORY
if ($ToolName) {
    $targetPath = Join-Path $targetPath $ToolName
}

if (Test-Path $targetPath) {
    Get-ChildItem -Path $targetPath -Recurse | Where-Object { $_.LinkType -eq "SymbolicLink" } | ForEach-Object { $_.Delete() }
    Remove-Item -Path $targetPath -Recurse -Force
}
