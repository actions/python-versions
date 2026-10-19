import struct
import sys
import sysconfig


architecture = sys.argv[1]
expected_platform = {
    "x86": "win32",
    "x64": "win-amd64",
    "arm64": "win-arm64",
}
hardware_architecture = architecture.replace("-freethreaded", "")
assert sysconfig.get_platform() == expected_platform[hardware_architecture]
assert struct.calcsize("P") * 8 == (32 if hardware_architecture == "x86" else 64)
assert bool(sysconfig.get_config_var("Py_GIL_DISABLED")) == architecture.endswith(
    "-freethreaded"
)
assert sys.version.split()[0] == sys.argv[2]
