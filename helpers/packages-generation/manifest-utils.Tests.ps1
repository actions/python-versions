Import-Module (Join-Path $PSScriptRoot "manifest-utils.psm1") -Force

Describe "New-AssetItem" {
    It "use regex to parse all values in correct order" {
        $githubAsset = @{ name = "python-3.8.3-linux-16.04-x64.tar.gz"; browser_download_url = "long_url"; }
        $configuration = @{
            regex = "python-\d+\.\d+\.\d+-(\w+)-([\w\.]+)?-?(x\d+)";
            groups = [PSCustomObject]@{ platform = 1; platform_version = 2; arch = 3; };
        }
        $expectedOutput = [PSCustomObject]@{
            filename = "python-3.8.3-linux-16.04-x64.tar.gz"; platform = "linux"; platform_version = "16.04";
            arch = "x64"; download_url = "long_url";
        }

        $actualOutput = New-AssetItem -ReleaseAsset $githubAsset -Configuration $configuration
        Assert-Equivalent -Actual $actualOutput -Expected $expectedOutput
    }

    It "support constant values in groups" {
        $githubAsset = @{ name = "python-3.8.3-linux-16.04-x64.tar.gz"; browser_download_url = "long_url"; }
        $configuration = @{
            regex = "python-\d+\.\d+\.\d+-(\w+)-([\w\.]+)?-?(x\d+)";
            groups = [PSCustomObject]@{ platform = 1; platform_version = 2; arch = "x64"; }
        }
        $expectedOutput = [PSCustomObject]@{
            filename = "python-3.8.3-linux-16.04-x64.tar.gz"; platform = "linux"; platform_version = "16.04";
            arch = "x64"; download_url = "long_url";
        }

        $actualOutput = New-AssetItem -ReleaseAsset $githubAsset -Configuration $configuration
        Assert-Equivalent -Actual $actualOutput -Expected $expectedOutput
    }

    It "Skip empty groups" {
        $githubAsset = @{ name = "python-3.8.3-win32-x64.zip"; browser_download_url = "long_url"; }
        $configuration = @{
            regex = "python-\d+\.\d+\.\d+-(\w+)-([\w\.]+)?-?(x\d+)";
            groups = [PSCustomObject]@{ platform = 1; platform_version = 2; arch = 3; }
        }
        $expectedOutput = [PSCustomObject]@{
            filename = "python-3.8.3-win32-x64.zip"; platform = "win32";
            arch = "x64"; download_url = "long_url";
        }

        $actualOutput = New-AssetItem -ReleaseAsset $githubAsset -Configuration $configuration
        Assert-Equivalent -Actual $actualOutput -Expected $expectedOutput
    }
}

Describe "Get-VersionFromRelease" {
    It "clear version" {
        $release = @{ name = "3.8.3" }
        Get-VersionFromRelease -Release $release | Should -Be "3.8.3"
    }

    It "version with title" {
        $release = @{ name = "3.8.3: Release title" }
        Get-VersionFromRelease -Release $release | Should -Be "3.8.3"
    }
}

Describe "Build-VersionsManifest" {
    $assets = @(
        @{ name = "python-3.8.3-linux-16.04-x64.tar.gz"; browser_download_url = "fake_url"; }
        @{ name = "python-3.8.3-linux-18.04-x64.tar.gz"; browser_download_url = "fake_url"; }
    )
    $configuration = @{
        regex = "python-\d+\.\d+\.\d+-(\w+)-([\w\.]+)?-?(x\d+)";
        groups = [PSCustomObject]@{ platform = 1; platform_version = 2; arch = "x64"; }
    }
    $expectedManifestFiles = @(
        [PSCustomObject]@{ filename = "python-3.8.3-linux-16.04-x64.tar.gz"; arch = "x64"; platform = "linux"; platform_version = "16.04"; download_url = "fake_url" },
        [PSCustomObject]@{ filename = "python-3.8.3-linux-18.04-x64.tar.gz"; arch = "x64"; platform = "linux"; platform_version = "18.04"; download_url = "fake_url" }
    )

    It "build manifest with correct version order" {
        $releases = @(
            @{ name = "3.8.1"; draft = $false; prerelease = $false; html_url = "fake_html_url"; published_at = "2020-05-14T09:54:06Z"; assets = $assets },
            @{ name = "3.5.2: Hello"; draft = $false; prerelease = $false; html_url = "fake_html_url"; published_at = "2020-05-06T11:45:36Z"; assets = $assets },
            @{ name = "3.8.3: Release title"; draft = $false; prerelease = $false; html_url = "fake_html_url"; published_at = "2020-05-06T11:43:38Z"; assets = $assets }
        )
        $expectedManifest = @(
            [PSCustomObject]@{ version = "3.8.3"; stable = $true; release_url = "fake_html_url"; files = $expectedManifestFiles },
            [PSCustomObject]@{ version = "3.8.1"; stable = $true; release_url = "fake_html_url"; files = $expectedManifestFiles },
            [PSCustomObject]@{ version = "3.5.2"; stable = $true; release_url = "fake_html_url"; files = $expectedManifestFiles }
        )
        $actualManifest = Build-VersionsManifest -Releases $releases -Configuration $configuration
        Assert-Equivalent -Actual $actualManifest -Expected $expectedManifest
    }

    It "Skip draft and prerelease" {
        $releases = @(
            @{ name = "3.8.1"; draft = $true; prerelease = $false; html_url = "fake_html_url"; published_at = "2020-05-14T09:54:06Z"; assets = $assets },
            @{ name = "3.5.2"; draft = $false; prerelease = $true; html_url = "fake_html_url"; published_at = "2020-05-06T11:45:36Z"; assets = $assets },
            @{ name = "3.8.3"; draft = $false; prerelease = $false; html_url = "fake_html_url"; published_at = "2020-05-06T11:43:38Z"; assets = $assets }
        )
        $expectedManifest = @(
            [PSCustomObject]@{ version = "3.8.3"; stable = $true; release_url = "fake_html_url"; files = $expectedManifestFiles }
        )
        [array]$actualManifest = Build-VersionsManifest -Releases $releases -Configuration $configuration
        Assert-Equivalent -Actual $actualManifest -Expected $expectedManifest 
    }

    It "take latest published release for each version" {
        $releases = @(
            @{ name = "3.8.1"; draft = $false; prerelease = $false; html_url = "fake_html_url1"; published_at = "2020-05-06T11:45:36Z"; assets = $assets },
            @{ name = "3.8.1"; draft = $false; prerelease = $false; html_url = "fake_html_url2"; published_at = "2020-05-14T09:54:06Z"; assets = $assets },
            @{ name = "3.8.1"; draft = $false; prerelease = $false; html_url = "fake_html_url3"; published_at = "2020-05-06T11:43:38Z"; assets = $assets }
        )
        $expectedManifest = @(
            [PSCustomObject]@{ version = "3.8.1"; stable = $true; release_url = "fake_html_url2"; files = $expectedManifestFiles }
        )
        [array]$actualManifest = Build-VersionsManifest -Releases $releases -Configuration $configuration
        Assert-Equivalent -Actual $actualManifest -Expected $expectedManifest
    }
}