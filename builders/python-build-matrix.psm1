function New-PythonBuildMatrix {
    param(
        [Parameter(Mandatory)][semver] $Version,
        [Parameter(Mandatory)][string[]] $Configurations,
        [Parameter(Mandatory)][ValidateSet("default", "freethreaded")][string[]] $BuildModes
    )

    foreach ($configuration in $Configurations) {
        foreach ($buildMode in $BuildModes) {
            $parts = $configuration.Split("_")
            $os = $parts[0]
            $arch = if ($parts[1]) { $parts[1] } else { "x64" }
            switch -wildcard ($os) {
                "*ubuntu*" { $platform = $os.Replace("ubuntu", "linux"); if ($arch -eq "arm64") { $os = "${os}-arm" } }
                "*rhel*" { $platform = $os; $os = $os.Replace("rhel", "setup-actions-rhel") }
                "*macos*" { $platform = "darwin" }
                "*windows*" { $platform = "win32"; if ($arch -eq "arm64") { $os = "${os}-arm" } }
                default { throw "Unsupported build platform: $configuration" }
            }

            if ($buildMode -eq "freethreaded") {
                if ($Version.Major -lt 3 -or ($Version.Major -eq 3 -and $Version.Minor -lt 13)) {
                    continue
                }
                $arch += "-freethreaded"
            }

            @{
                platform = $platform
                os = $os
                arch = $arch
            }
        }
    }
}
