using module "../builders/win-python-builder.psm1"

BeforeAll {
    Import-Module "$PSScriptRoot/../helpers/common-helpers.psm1"
    Import-Module "$PSScriptRoot/../helpers/win-helpers.psm1"
    Import-Module "$PSScriptRoot/../builders/python-version.psm1"
    $originalRunnerTemp = $env:RUNNER_TEMP

    function New-TestBuilder([string] $Version, [string] $Architecture) {
        [WinPythonBuilder]::new([semver] $Version, $Architecture, "win32")
    }
}

AfterAll {
    $env:RUNNER_TEMP = $originalRunnerTemp
}

Describe "Windows Python packages" {
    BeforeEach {
        $env:RUNNER_TEMP = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        Mock Invoke-RestMethod -ModuleName win-python-builder {
            $nativeVersion = if ($Uri -match 'windows-(.+)\.json$') { $Matches[1] }
            $shortVersion = ($nativeVersion -split '\.')[0..1] -join '.'
            $baseVersion = $nativeVersion -replace '(a|b|rc)\d+$', ''
            @{
                versions = @(
                    foreach ($arch in @("32", "64", "arm64")) {
                        foreach ($suffix in @("", "t")) {
                            foreach ($kind in @("pythoncore", "pythontest")) {
                                @{
                                    schema = 1
                                    id = "$kind-$shortVersion$suffix-$arch"
                                    'sort-version' = $nativeVersion
                                    url = "https://www.python.org/ftp/python/$baseVersion/python-$nativeVersion$suffix-$kind-$arch.zip"
                                    hash = @{ sha256 = "a" * 64 }
                                }
                            }
                        }
                    }
                )
            }
        }
    }

    It "Preserves the legacy installer for <Version> <Architecture>" -ForEach @(
        foreach ($version in @("3.11.0", "3.12.9", "3.13.0-alpha.1", "3.14.4", "3.15.0-alpha.1", "3.15.2")) {
            foreach ($arch in @("x86", "x64", "arm64")) {
                foreach ($mode in @("", "-freethreaded")) {
                    if ($mode -and ([semver] $version).Minor -lt 13) { continue }
                    @{
                        Version = $version
                        Architecture = "$arch$mode"
                        Suffix = @{ x86 = ""; x64 = "-amd64"; arm64 = "-arm64" }[$arch]
                    }
                }
            }
        }
    ) {
        $builder = New-TestBuilder $Version $Architecture
        $nativeVersion = Convert-Version ([semver] $Version)
        $baseVersion = $builder.GetBaseVersion()
        $builder.GetSourceUri().AbsoluteUri | Should -Be "https://www.python.org/ftp/python/$baseVersion/python-$nativeVersion$Suffix.exe"
        $builder.GetPythonExtension() | Should -Be ".exe"
        Should -Invoke Invoke-RestMethod -ModuleName win-python-builder -Times 0 -Exactly
    }

    It "Rejects free-threaded builds before Python 3.13 for <Version>" -ForEach @(
        @{ Version = "3.11.0" }
        @{ Version = "3.12.9" }
    ) {
        { New-TestBuilder $Version "x64-freethreaded" } | Should -Throw "*require Python 3.13*"
    }

    It "Downloads legacy installers without requesting manifest checksums" {
        Mock Download-File -ModuleName win-python-builder { Join-Path $OutputFolder "python.exe" }
        Mock Get-FileHash -ModuleName win-python-builder { throw "Unexpected checksum request" }
        $builder = New-TestBuilder "3.15.0" "x64"
        $builder.Download() | Should -Be (Join-Path $builder.WorkFolderLocation "python.exe")
        Should -Invoke Get-FileHash -ModuleName win-python-builder -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -ModuleName win-python-builder -Times 0 -Exactly
    }

    It "Selects the <Architecture> package for <Version>" -ForEach @(
        foreach ($version in @("3.16.0-alpha.1", "3.16.0-beta.2", "3.16.0-rc.1", "3.16.0", "3.16.2", "3.17.0-beta.2", "4.0.0")) {
            foreach ($arch in @("x86", "x64", "arm64")) {
                foreach ($suffix in @("", "-freethreaded")) {
                    @{
                        Version = $version
                        Architecture = "$arch$suffix"
                        PackageArch = @{ x86 = "32"; x64 = "64"; arm64 = "arm64" }[$arch]
                        ThreadSuffix = if ($suffix) { "t" } else { "" }
                    }
                }
            }
        }
    ) {
        $builder = New-TestBuilder $Version $Architecture
        $nativeVersion = Convert-Version ([semver] $Version)
        $baseVersion = $builder.GetBaseVersion()
        $builder.GetSourceUri().AbsoluteUri | Should -Be "https://www.python.org/ftp/python/$baseVersion/python-$nativeVersion$ThreadSuffix-pythontest-$PackageArch.zip"
        $builder.GetPythonExtension() | Should -Be ".zip"
        $builder.GetSourceUri() | Should -Not -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName win-python-builder -Times 1 -Exactly -ParameterFilter {
            $Uri -eq "https://www.python.org/ftp/python/$baseVersion/windows-$nativeVersion.json"
        }
    }

    It "Uses the core runtime when a matching test distribution is not published" {
        Mock Invoke-RestMethod -ModuleName win-python-builder {
            @{ versions = @(
                @{ schema = 1; id = "pythoncore-3.16t-arm64"; 'sort-version' = "3.16.0a1"
                    url = "https://www.python.org/ftp/python/3.16.0/python-3.16.0a1t-arm64.zip"
                    hash = @{ sha256 = "a" * 64 } }
                @{ schema = 1; id = "pythontest-3.16-arm64"; 'sort-version' = "3.16.0a1"
                    url = "https://www.python.org/ftp/python/3.16.0/python-3.16.0a1-test-arm64.zip"
                    hash = @{ sha256 = "b" * 64 } }
            ) }
        }
        $builder = New-TestBuilder "3.16.0-alpha.1" "arm64-freethreaded"
        $builder.GetSourceUri().AbsoluteUri | Should -Be "https://www.python.org/ftp/python/3.16.0/python-3.16.0a1t-arm64.zip"
    }

    It "Rejects missing or wrong-version packages" {
        Mock Invoke-RestMethod -ModuleName win-python-builder {
            @{ versions = @(
                @{ id = "pythoncore-3.16-64"; 'sort-version' = "3.16.0a2" }
            ) }
        }
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        { $builder.GetSourceUri() } | Should -Throw "*Expected one Windows package*found 0*"
    }

    It "Rejects invalid package metadata" -ForEach @(
        @{ Schema = 2; Hash = "a" * 64; Url = "https://www.python.org/python.zip" }
        @{ Schema = 1; Hash = ""; Url = "https://www.python.org/python.zip" }
        @{ Schema = 1; Hash = "invalid"; Url = "https://www.python.org/python.zip" }
        @{ Schema = 1; Hash = "a" * 64; Url = "http://www.python.org/python.zip" }
        @{ Schema = 1; Hash = "a" * 64; Url = "https://www.python.org/python.exe" }
    ) {
        Mock Invoke-RestMethod -ModuleName win-python-builder {
            @{ versions = @(
                @{ schema = $Schema; id = "pythoncore-3.16-64"; 'sort-version' = "3.16.0a1"
                    url = $Url; hash = @{ sha256 = $Hash } }
            ) }
        }
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        { $builder.GetSourceUri() } | Should -Throw "*Invalid Windows package*"
    }

    It "Propagates manifest download errors" {
        Mock Invoke-RestMethod -ModuleName win-python-builder { throw "Manifest unavailable" }
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        { $builder.GetSourceUri() } | Should -Throw "*Manifest unavailable*"
    }

    It "Rejects duplicate packages" {
        Mock Invoke-RestMethod -ModuleName win-python-builder {
            $package = @{ id = "pythontest-3.16-64"; 'sort-version' = "3.16.0a1" }
            @{ versions = @($package, $package) }
        }
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        { $builder.GetSourceUri() } | Should -Throw "*found 2*"
    }

    It "Verifies the downloaded SHA256 before producing an artifact" -ForEach @(
        @{ ActualHash = "a" * 64; Valid = $true }
        @{ ActualHash = "b" * 64; Valid = $false }
    ) {
        Mock Download-File -ModuleName win-python-builder { Join-Path $OutputFolder "python.zip" }
        Mock Get-FileHash -ModuleName win-python-builder { @{ Hash = $ActualHash } }
        Mock Create-SevenZipArchive -ModuleName win-python-builder {}
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        if ($Valid) {
            $builder.Build()
            $setupPath = Join-Path $builder.WorkFolderLocation "setup.ps1"
            $setup = Get-Content $setupPath -Raw
            $setup | Should -Not -Match '\{\{__'
            $setup | Should -Match 'python-3.16.0a1-pythontest-64.zip'
            Should -Invoke Create-SevenZipArchive -ModuleName win-python-builder -Times 1 -Exactly -ParameterFilter {
                $ArchivePath -eq (Join-Path $builder.ArtifactFolderLocation "python-3.16.0-alpha.1-win32-x64.zip")
            }
        } else {
            { $builder.Build() } | Should -Throw "*SHA256 mismatch*"
            Test-Path (Join-Path $builder.WorkFolderLocation "setup.ps1") | Should -BeFalse
            Should -Invoke Create-SevenZipArchive -ModuleName win-python-builder -Times 0 -Exactly
        }
        Should -Invoke Get-FileHash -ModuleName win-python-builder -Times 1 -Exactly -ParameterFilter { $Algorithm -eq "SHA256" }
    }
}

Describe "Windows ZIP setup" {
    BeforeAll {
        $originalToolcache = $env:AGENT_TOOLSDIRECTORY
    }

    BeforeEach {
        $env:RUNNER_TEMP = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $env:AGENT_TOOLSDIRECTORY = Join-Path $env:RUNNER_TEMP "tool cache"
        Mock Get-Item {}
        Mock Test-Path { [IO.Directory]::Exists($Path) -or [IO.File]::Exists($Path) }
        Mock Test-Path { throw "ZIP setup must not inspect the registry" } -ParameterFilter { $Path -like "Registry::*" }
        Mock Expand-Archive {}
        Mock Remove-Item {}
        Mock New-Item {}
        Mock New-Item { throw "Reached Python alias" } -ParameterFilter { $Path -like "*python3.exe" }
    }

    AfterAll {
        $env:AGENT_TOOLSDIRECTORY = $originalToolcache
    }

    It "Extracts <Architecture> without registry changes or executable replacement" -ForEach @(
        @{ Architecture = "x64" }
        @{ Architecture = "x86" }
        @{ Architecture = "arm64" }
        @{ Architecture = "x64-freethreaded" }
        @{ Architecture = "x86-freethreaded" }
        @{ Architecture = "arm64-freethreaded" }
    ) {
        $builder = New-TestBuilder "3.16.0-alpha.1" $Architecture
        $builder.WindowsPackage = @{ url = "https://www.python.org/python.zip" }
        $builder.CreateInstallationScript()
        $setupPath = Join-Path $builder.WorkFolderLocation "setup.ps1"
        { & $setupPath } | Should -Throw "*Reached Python alias*"
        Should -Invoke Expand-Archive -Times 1 -Exactly -ParameterFilter {
            $LiteralPath -eq (Join-Path $builder.WorkFolderLocation "python.zip") -and
            $DestinationPath -eq (Join-Path $env:AGENT_TOOLSDIRECTORY "Python/3.16.0-alpha.1/$Architecture") -and
            $ErrorAction -eq "Stop"
        }
        Should -Invoke Remove-Item -Times 0 -Exactly
        Should -Invoke Test-Path -Times 0 -Exactly -ParameterFilter { $Path -like "Registry::*" }
        Test-Path (Join-Path $env:AGENT_TOOLSDIRECTORY "Python/3.16.0-alpha.1/$Architecture.complete") | Should -BeFalse
    }

    It "Stops on extraction errors without marking the installation complete" {
        Mock Expand-Archive { throw "Corrupt ZIP" }
        $builder = New-TestBuilder "3.16.0-alpha.1" "x64"
        $builder.WindowsPackage = @{ url = "https://www.python.org/python.zip" }
        $builder.CreateInstallationScript()
        { & (Join-Path $builder.WorkFolderLocation "setup.ps1") } | Should -Throw "*Corrupt ZIP*"
        Should -Invoke New-Item -Times 0 -Exactly -ParameterFilter { $Path -like "*python3.exe" }
        Test-Path (Join-Path $env:AGENT_TOOLSDIRECTORY "Python/3.16.0-alpha.1/x64.complete") | Should -BeFalse
    }
}
