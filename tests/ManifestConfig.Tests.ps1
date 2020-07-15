Import-Module (Join-Path $PSScriptRoot "../helpers/packages-generation/manifest-utils.psm1")

$ConfigurationFile = Join-Path $PSScriptRoot "../config/python-manifest-config.json"
$Configuration = Read-ConfigurationFile -Filepath $ConfigurationFile

$stableTestCases = @(
    @{ ReleaseName = "python-3.8.3-darwin-x64.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.8.3-linux-16.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "16.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.8.3-linux-18.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "18.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.8.3-linux-20.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.8.3-win32-x64.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.8.3-win32-x86.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"} }
) | ForEach-Object { $_.Configuration = $Configuration; $_ }

$unstableTestCases = @(
    @{ ReleaseName = "python-3.9.0-alpha.2-darwin-x64.tar.gz"; ExpectedResult = @{ platform = "darwin"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.9.0-beta.1-linux-16.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "16.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.9.0-rc.4-linux-18.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "18.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.9.0-beta.2-linux-20.04-x64.tar.gz"; ExpectedResult = @{ platform = "linux"; platform_version = "20.04"; arch = "x64"} },
    @{ ReleaseName = "python-3.9.0-beta.2-win32-x64.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x64"} },
    @{ ReleaseName = "python-3.9.0-beta.2-win32-x86.zip"; ExpectedResult = @{ platform = "win32"; platform_version = $null; arch = "x86"} }
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