param (
    [Version] [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
    $Version,
    [String] [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
    $Platform
)

Import-Module (Join-Path $PSScriptRoot "../helpers/pester-extensions.psm1")
Import-Module (Join-Path $PSScriptRoot "../helpers/common-helpers.psm1")

function Analyze-MissingModules([string] $buildOutputLocation) {
    $searchStringStart = "Failed to build these modules:"
    $searchStringEnd = "running build_scripts"
    $pattern = "$searchStringStart(.*?)$searchStringEnd"

    $buildContent = Get-Content -Path $buildOutputLocation
    $splitBuiltOutput = $buildContent -split "\n";

    ### Search for missing modules that are displayed between the search strings
    $regexMatch = [regex]::match($SplitBuiltOutput, $Pattern)
    if ($regexMatch.Success)
    {
        Write-Host "Failed missing modules:"
        Write-Host $regexMatch.Groups[1].Value
        return 1
    }

    return 0
}

Describe "Tests" {
    It "Python version" {
        "python --version" | Should -ReturnZeroExitCode
        $pythonLocation = (Get-Command "python").Path
        $pythonLocation | Should -Not -BeNullOrEmpty
        $expectedPath = Join-Path -Path $env:AGENT_TOOLSDIRECTORY -ChildPath "Python"
        $pythonLocation.startsWith($expectedPath) | Should -BeTrue
    }

    It "Run simple code" {
        "python ./sources/simple-test.py" | Should -ReturnZeroExitCode
    }

    if ($Version -ge "3.2.0") {
        It "Check if sqlite3 module is installed" {
            "python ./sources/python-sqlite3.py" | Should -ReturnZeroExitCode
        }
    }

    if (IsNixPlatform $Platform) {

        It "Check for failed modules in build_output" {
            $buildOutputLocation = Join-Path $env:BUILD_BINARIESDIRECTORY "build_output.txt"
            Analyze-MissingModules $buildOutputLocation | Should -Be 0
        }

        It "Check if all required python modules are installed"  {
            "python ./sources/python-modules.py" | Should -ReturnZeroExitCode
        }

        It "Check if python configuration is correct" {
            "python ./sources/python-config-test.py" | Should -ReturnZeroExitCode
        }

        It "Check if shared libraries are linked correctly" {
            "bash ./sources/psutil-install-test.sh" | Should -ReturnZeroExitCode
        }
    }

    # Pyinstaller 3.5 does not support Python 3.8.0. Check issue https://github.com/pyinstaller/pyinstaller/issues/4311
    if ($Version -lt "3.8.0") {
        It "Validate Pyinstaller" {
            "pip install pyinstaller" | Should -ReturnZeroExitCode
            "pyinstaller --onefile ./sources/simple-test.py" | Should -ReturnZeroExitCode
            "./dist/simple-test" | Should -ReturnZeroExitCode
        }
    }
}