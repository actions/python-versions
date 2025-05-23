param (
    [semver] [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
    $Version,
    [string] [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
    $Platform,
    [string] [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()]
    $Architecture
)

$HardwareArchitecture = $Architecture -replace "-freethreaded", ""

Import-Module (Join-Path $PSScriptRoot "../helpers/pester-extensions.psm1")
Import-Module (Join-Path $PSScriptRoot "../helpers/common-helpers.psm1")
Import-Module (Join-Path $PSScriptRoot "../builders/python-version.psm1")

BeforeAll {
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
            $module = $regexMatch.Groups[1].Value.Trim()
            Write-Host "Failed missing modules:"
            Write-Host $module
            if ( ($module -eq "_tkinter") -and ( [semver]"$($Version.Major).$($Version.Minor)" -ge [semver]"3.10" -and $Version.PreReleaseLabel ) ) {
                Write-Host "$module $Version ignored"
            } else {
                return 1
            }
        }

        return 0
    }
}

Describe "Tests" {
    It "Python version" {
        "python --version" | Should -ReturnZeroExitCode
        $pythonLocation = (Get-Command "python").Path
        $pythonLocation | Should -Not -BeNullOrEmpty
        $expectedPath = Join-Path -Path $env:RUNNER_TOOL_CACHE -ChildPath "Python"
        $pythonLocation.startsWith($expectedPath) | Should -BeTrue
    }

    It "Run simple code" {
        "python ./sources/simple-test.py" | Should -ReturnZeroExitCode
    }

    # linux has no display name and no $DISPLAY environment variable - skip tk test
    # if (-not (($Platform -match "ubuntu") -or ($Platform -match "linux"))) {
    #     It "Check if tcl/tk has the same headed and library versions" {
	#     "python ./sources/tcltk.py" | Should -ReturnZeroExitCode
    #     }
    # }

    if (($Version -lt "3.11.0") -and (($Platform -ne "darwin") -or ($HardwareArchitecture -ne "arm64"))) {
        It "Check if sqlite3 module is installed" {
            "python ./sources/python-sqlite3.py" | Should -ReturnZeroExitCode
        }
    }

    It "Run pip" {
        "pip install requests" | Should -ReturnZeroExitCode
        "pip uninstall requests -y" | Should -ReturnZeroExitCode
    }

    if (IsNixPlatform $Platform) {

        It "Check for failed modules in build_output" {
            $buildOutputLocation = Join-Path $env:RUNNER_TEMP "build_output.txt"
            Analyze-MissingModules $buildOutputLocation | Should -Be 0
        }

        It "Check if all required python modules are installed"  {
            "python ./sources/python-modules.py" | Should -ReturnZeroExitCode
        }

        It "Check if python configuration is correct" {
            $nativeVersion = Convert-Version -version $Version
            "python ./sources/python-config-test.py $Version $nativeVersion $Architecture" | Should -ReturnZeroExitCode
        }

        It "Check if shared libraries are linked correctly" {
            "bash ./sources/psutil-install-test.sh" | Should -ReturnZeroExitCode
        }
    }

    It "Check urlopen with HTTPS works" {
        "python ./sources/python-urlopen-https.py" | Should -ReturnZeroExitCode
    }

    It "Check a single dist-info per distribution is present" {
        "python ./sources/dist-info.py" | Should -ReturnZeroExitCode
    }
}
