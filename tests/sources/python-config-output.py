import distutils.sysconfig
import sysconfig

from pprint import pprint
pprint(sysconfig.get_config_vars())
pprint(distutils.sysconfig.get_config_vars())