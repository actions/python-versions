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

    # Windows free-threaded Python 3.16+ is installed from a "PythonCore" package, as there is no free-threaded "PythonTest" package with Lib/test
    $SkipTestSuite = ($Platform -eq "win32") -and ($Architecture -match "-freethreaded") -and ([semver]$Version -ge [semver]"3.16.0-alpha.1")
    It "Check if the standard library test suite (Lib/test) is installed" -Skip:$SkipTestSuite {
        "python ./sources/stdlib-test-suite.py" | Should -ReturnZeroExitCode
    }

    if ($Platform -eq "win32") {
        It "pip.exe is from the toolcache" {
            $pipLocation = (Get-Command "pip").Path
            $pipLocation | Should -Not -BeNullOrEmpty
            $expectedPath = Join-Path -Path $env:RUNNER_TOOL_CACHE -ChildPath "Python"
            $pipLocation.startsWith($expectedPath) | Should -BeTrue
        }

        # TODO: Python 3.16+ is extracted from a package, so it is not registered for the legacy py.exe launcher
        $SkipPyLauncher = [semver]$Version -ge [semver]"3.16.0-alpha.1"
        It "py.exe finds Python" -Skip:$SkipPyLauncher {
            $suffix = if ($Architecture -match "-freethreaded") { "t" } else { "" }
            $major, $minor = "$Version".Split(".")[0..1]
            $pyLocation = py "-$major.$minor$suffix" -c "import sys; print(sys.executable)"
            $LASTEXITCODE | Should -Be 0
            $expectedPath = Join-Path -Path $env:RUNNER_TOOL_CACHE -ChildPath "Python"
            $pyLocation.startsWith($expectedPath) | Should -BeTrue
        }
    }

    It "Run pip" {
        "pip install requests" | Should -ReturnZeroExitCode
        "pip uninstall requests -y" | Should -ReturnZeroExitCode
    }

    if ((IsNixPlatform $Platform) -or ($Platform -match "rhel")) {

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
