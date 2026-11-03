import importlib.util
import os.path
import sys


def check_test_suite():
    spec = importlib.util.find_spec("test")
    if spec is None or not spec.submodule_search_locations:
        print("The 'test' package (Lib/test) is not installed")
        sys.exit(1)

    test_dir = list(spec.submodule_search_locations)[0]
    for name in ("support", "libregrtest"):
        if not os.path.isdir(os.path.join(test_dir, name)):
            print("Missing test.{} in {}".format(name, test_dir))
            sys.exit(1)


check_test_suite()
