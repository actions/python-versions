if ($env:PLATFORM -match 'windows') {
  $PythonFilter = "Name like '%Python%'"
  Get-WmiObject Win32_Product -Filter $PythonFilter | Foreach-Object { 
      Write-Host "Uninstalling $($_.Name) ..."
      $_.Uninstall() | Out-Null 
  }
}

$PythonToolcachePath = Join-Path -Path $env:AGENT_TOOLSDIRECTORY -ChildPath "Python"
Write-Host "Removing Python toolcache directory ..."
Remove-Item -Path $PythonToolcachePath -Recurse -Force