function Convert-Label() {
    <#
    .SYNOPSIS
    Convert generic semver label to native Python label.
    #>

    param(
        [Parameter(Mandatory)]
        [string] $label
    )

    switch ($label) {
        "alpha" { return "a" }
        "beta" { return "b" }
        "rc" { return "rc" }
        default { throw "Invalid version label '$label'" }
    }
}

function Convert-Version {
    <#
    .SYNOPSIS
    Convert generic semver version to native Python version.
    #>

    param(
        [Parameter(Mandatory)]
        [semver] $version,
        [char] $delimiter = "."
    )

    $nativeVersion = "{0}.{1}.{2}" -f $version.Major, $version.Minor, $version.Patch

    if ($version.PreReleaseLabel)
    {
        $preReleaseLabel = $version.PreReleaseLabel.Split($delimiter)
        
        $preReleaseLabelName = Convert-Label -Label $preReleaseLabel[0]
        $preReleaseLabelVersion = $preReleaseLabel[1]

        $nativeVersion += "${preReleaseLabelName}${preReleaseLabelVersion}"
    }

    return $nativeVersion
}