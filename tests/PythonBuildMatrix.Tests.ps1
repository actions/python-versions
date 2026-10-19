BeforeAll {
    Import-Module "$PSScriptRoot/../builders/python-build-matrix.psm1"
}

Describe "Python build matrix" {
    It "Uses supported Windows threading modes for <Version>" -ForEach @(
        @{ Version = "3.11.0"; Count = 3 }
        @{ Version = "3.12.9"; Count = 3 }
        @{ Version = "3.13.0-alpha.1"; Count = 6 }
        @{ Version = "3.13.7"; Count = 6 }
        @{ Version = "3.14.4"; Count = 6 }
        @{ Version = "3.15.0-rc.1"; Count = 6 }
        @{ Version = "3.16.0-alpha.1"; Count = 6 }
        @{ Version = "3.16.2"; Count = 6 }
        @{ Version = "3.17.0-beta.2"; Count = 6 }
        @{ Version = "4.0.0"; Count = 6 }
    ) {
        $matrix = @(New-PythonBuildMatrix -Version $Version -Configurations @(
            "windows-2022_x64", "windows-2022_x86", "windows-11_arm64"
        ) -BuildModes @("default", "freethreaded"))
        $matrix.Count | Should -Be $Count
        @($matrix.arch | Sort-Object -Unique).Count | Should -Be $Count
        foreach ($entry in $matrix) {
            $entry.platform | Should -Be "win32"
            $entry.os | Should -Be $(if ($entry.arch.StartsWith("arm64")) { "windows-11-arm" } else { "windows-2022" })
            $entry.ContainsKey("version") | Should -BeFalse
        }
    }

    It "Generates only default builds when requested" {
        $matrix = @(New-PythonBuildMatrix -Version "3.16.0" -Configurations @("windows-2022_x64") -BuildModes default)
        $matrix.Count | Should -Be 1
        $matrix[0].arch | Should -Be "x64"
    }

    It "Preserves non-Windows runner mappings" {
        $matrix = @(New-PythonBuildMatrix -Version "3.11.0" -Configurations @(
            "ubuntu-22.04", "ubuntu-24.04_arm64", "rhel-9", "macos-14_arm64", "macos-15-intel"
        ) -BuildModes default)
        $matrix.Count | Should -Be 5
        $matrix[0].platform | Should -Be "linux-22.04"
        $matrix[0].arch | Should -Be "x64"
        $matrix[1].os | Should -Be "ubuntu-24.04-arm"
        $matrix[2].os | Should -Be "setup-actions-rhel-9"
        $matrix[2].platform | Should -Be "rhel-9"
        $matrix[3].platform | Should -Be "darwin"
        $matrix[3].arch | Should -Be "arm64"
        $matrix[4].os | Should -Be "macos-15-intel"
    }

    It "Rejects invalid platforms" {
        { New-PythonBuildMatrix -Version "3.16.0" -Configurations invalid -BuildModes default } | Should -Throw "*Unsupported build platform*"
    }

    It "Rejects invalid build modes" {
        { New-PythonBuildMatrix -Version "3.16.0" -Configurations windows-2022 -BuildModes invalid } | Should -Throw
    }
}
