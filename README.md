# Python for Actions
This repository contains the code and scripts that we use to build Python packages used in [runner-images](https://github.com/actions/runner-images) and accessible through the [setup-python](https://github.com/actions/setup-python) Action.
File [versions-manifest.json](./versions-manifest.json) contains the list of available and released versions.

> Caution: this is prepared for and only permitted for use by actions `runner-images` and `setup-python` action.

Some versions are pre-installed on [runner-images](https://github.com/actions/runner-images) images.
More versions are available to install on-the-fly through the [`setup-python`](https://github.com/actions/setup-python) action.

## Building installation packages
**Ubuntu:** The official Python sources are downloaded from [python.org](https://www.python.org/ftp/python/), built using the `make` tool, and archived along with the installation script for further distribution and installation. We build each Python version against all [versions of Ubuntu](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources) that are available at the time the Python version is released.

**macOS:** 
- For **Python < 3.11**, the official Python sources are downloaded from [python.org](https://www.python.org/ftp/python/), built using the `make` tool, and archived along with the installation script for further distribution and installation.  For backward compatibility, we build each Python version against the oldest [version of macOS](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources) that is available at the time the Python version is released.
- For **Python >= 3.11**, the official macOS `universal2` Python binaries are simply downloaded from [python.org](https://www.python.org/ftp/python/) and archived along with the installation script for further distribution and installation.

**Windows:**
- For **Python < 3.16**, the official Python executables are downloaded from [python.org](https://www.python.org/ftp/python/) and archived along with the installation script.
- For **Python >= 3.16**, the Windows release manifest on python.org selects the ZIP distribution for x64, x86, or ARM64, including free-threaded builds. The package's SHA-256 is verified before archiving it with the installation script, which extracts it directly into the toolcache. The test distribution is preferred when available because it also includes `Lib/test` and native test modules; otherwise the core runtime is used. ZIP installations do not register with the legacy Python launcher or Python install manager; use `python` and `pip` on the PATH configured by `setup-python`.

To generate Windows-only artifacts, dispatch [Build Python package](./.github/workflows/build-python-packages.yml) with `VERSION` set to the desired semver (for example, `3.11.9`, `3.15.0`, or `3.16.0-alpha.1`), `PLATFORMS` set to `windows-2022_x64,windows-2022_x86,windows-11_arm64`, and `THREADING_BUILD_MODES` set to `default,freethreaded` (or just `default`). The matrix uses the requested version without adding fixed-version builds and automatically omits free-threaded jobs before Python 3.13, including support for 3.13 prereleases. Leave `PUBLISH_RELEASES` disabled to build and test without publishing a release.

Windows packaging requires an official distribution for the requested version and architecture. In particular, security-only releases of older Python branches may not publish Windows installers; this workflow does not build those releases from source. Future versions use the 3.16+ manifest format as long as that format remains compatible.

## Support policy
We aim to make new versions of Python available as soon as they are released. Both stable and prerelease versions are considered for building and releasing. Please open an issue in [actions/setup-python](https://github.com/actions/setup-python) if a version you're looking for isn't available.

When a new version of an operating system is released and made available for use with [GitHub hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources), we will provide the **latest existing patch versions of Python for all major versions that have not reached [end-of-life](https://devguide.python.org/versions/)**.  Any subsequent Python versions will be made available for the new OS as well.

Beginning **approximately six months prior** to the removal of a Python version from the [versions-manifest.json](https://github.com/actions/python-versions/blob/main/versions-manifest.json) file, a pinned issue will be created in the [setup-python](https://github.com/actions/setup-python) repository. This pinned issue will provide important details about the upcoming end of support, including the specific date, as well as any other notes, relevant updates or alternatives. We encourage users to regularly check pinned issues for updates on tool versions they are using for maximum transparency, security, performance and overall compatibility with their projects.

## Contribution
Contributions are welcome! See [Contributor's Guide](./CONTRIBUTING.md) for more details about contribution process and code structure
