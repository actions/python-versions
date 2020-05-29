###
# Visual Studio helper functions
###

function Get-VSWhere {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe";

    if (-not (Test-Path $vswhere )) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $vswhere = ".\vswhere.exe"
        $vswhereApiUri = "https://api.github.com/repos/Microsoft/vswhere/releases/latest"
        $tag = (Invoke-RestMethod -Uri $vswhereApiUri)[0].tag_name
        $vswhereUri = "https://github.com/Microsoft/vswhere/releases/download/$tag/vswhere.exe"
        Invoke-WebRequest -Uri $vswhereUri -OutFile $vswhere | Out-Null
    }

    return $vswhere
}

function Invoke-Environment
{
    Param
    (
        [Parameter(Mandatory)]
        [string]
        $Command
    )

    & "${env:COMSPEC}" /s /c "`"$Command`" -no_logo && set" | Foreach-Object {
        if ($_ -match '^([^=]+)=(.*)') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

function Get-VSInstallationPath {
    $vswhere = Get-VSWhere
    $installationPath = & $vswhere -prerelease -legacy -latest -property installationPath

    return $installationPath
}

function Invoke-VSDevEnvironment {
    Write-Host "Invoke-VSDevEnvironment had been invoked"
    $installationPath = Get-VSInstallationPath
    $envFilepath = Join-Path $installationPath "Common7\Tools\vsdevcmd.bat"
    Invoke-Environment -Command $envFilepath
}