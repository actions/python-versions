Import-Module (Join-Path $PSScriptRoot "../helpers/packages-generation/manifest-utils.psm1")

$ConfigurationFile = Join-Path $PSScriptRoot "../config/python-manifest-config.json"
$Configuration = Read-ConfigurationFile -Filepath $ConfigurationFile

$stableTestCases = @(
    
    @{ ReleaseName = "python-3.13.0-darwin-x64.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.13.0-linux-20.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.13.0-linux-22.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "22.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.13.0-win32-x64.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.13.0-win32-x86.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"} },
    @{ ReleaseName = "python-3.13.0-darwin-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.13.0-linux-20.04-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.13.0-linux-22.04-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "22.04"; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.13.0-win32-x64-freethreaded.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.13.0-win32-x86-freethreaded.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"; freethreaded = $true} }

) | ForEach-Object { $_.Configuration = $Configuration; $_ }

$unstableTestCases = @(

   @{ ReleaseName = "python-3.14.0-alpha.5-darwin-x64.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.14.0-alpha.5-linux-20.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.14.0-alpha.5-linux-22.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "22.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.14.0-alpha.5-win32-x64.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.14.0-alpha.5-win32-x86.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"} },
    @{ ReleaseName = "python-3.14.0-alpha.5-darwin-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.14.0-alpha.5-linux-20.04-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.14.0-alpha.5-linux-22.04-x64-freethreaded.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "22.04"; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.14.0-alpha.5-win32-x64-freethreaded.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"; freethreaded = $true} },
    @{ ReleaseName = "python-3.14.0-alpha.5-win32-x86-freethreaded.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"; freethreaded = $true} }

) | ForEach-Object { $_.Configuration = $Configuration; $_ }

Describe "Python manifest config" {
    Context "Stable versions" {
        It "<ReleaseName>" -TestCases $stableTestCases {
            $Release = @{ name = $ReleaseName }
            $asset = New-AssetItem -ReleaseAsset $Release -Configuration $Configuration
            $asset.platform | Should -Be $ExpectedResult.platform
            $asset.platform_version | Should -Be $ExpectedResult.platform_version
            $asset.arch | Should -Be $ExpectedResult.arch
        }
    }

    Context "Prerelease versions" {
        It "<ReleaseName>" -TestCases $unstableTestCases {
            $Release = @{ name = $ReleaseName }
            $asset = New-AssetItem -ReleaseAsset $Release -Configuration $Configuration
            $asset.platform | Should -Be $ExpectedResult.platform
            $asset.platform_version | Should -Be $ExpectedResult.platform_version
            $asset.arch | Should -Be $ExpectedResult.arch
        }
    }
}