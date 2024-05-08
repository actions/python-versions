import glob
import os.path
import sysconfig
from collections import defaultdict


def check_dist_info():
    paths = set([sysconfig.get_path("purelib"), sysconfig.get_path("platlib")])
    versions = defaultdict(list)
    for path in paths:
        pattern = os.path.join(path, "*.dist-info")
        for dist_info in glob.glob(pattern):
            name = os.path.basename(dist_info).split("-", maxsplit=1)[0]
            versions[name].append(dist_info)
    exit_code = 0
    for name in versions:
        if len(versions[name]) > 1:
            print("multiple dist-info found for {}: {}".format(name, versions[name]))
            exit_code = 1
    exit(exit_code)


if __name__ == "__main__":
    check_dist_info()
