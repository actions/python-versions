import distutils.sysconfig
import sysconfig
import sys
import platform
import os

# Define variables
os_type = platform.system()
version = sys.argv[1]

lib_dir_path = sysconfig.get_config_var('LIBDIR')
ld_library_name = sysconfig.get_config_var('LDLIBRARY')

is_shared = sysconfig.get_config_var('Py_ENABLE_SHARED')
have_libreadline = sysconfig.get_config_var("HAVE_LIBREADLINE")

### Define expected variables
if os_type == 'Linux': expected_ld_library_extension = 'so'
if os_type == 'Darwin': expected_ld_library_extension = 'dylib'
expected_lib_dir_path = '{0}/Python/{1}/x64/lib'.format(os.getenv("AGENT_TOOLSDIRECTORY"), version)

# Check modules
### Validate libraries path
if lib_dir_path != expected_lib_dir_path:
    print('Invalid libraries location: %s; Expected: %s' % (lib_dir_path, expected_lib_dir_path))
    exit(1)

### Validate shared libraries
if is_shared:
    print('%s was built with shared extensions' % ld_library_name)
    
    ### Validate libpython extension
    ld_library_extension = ld_library_name.split('.')[-1]
    if ld_library_extension != expected_ld_library_extension:
        print('Invalid extension: %s; Expected %s' % (ld_library_extension, expected_ld_library_extension))
        exit(1)
else:
    print('%s was built without shared extensions' % ld_library_name)
    exit(1)

### Validate macOS
if os_type == 'Darwin':
    ### Validate openssl links
    if version < "3.7.0":
        expected_ldflags = '-L/usr/local/opt/openssl@1.1/lib'
        ldflags = sysconfig.get_config_var('LDFLAGS')

        if not expected_ldflags in ldflags:
            print('Invalid ldflags: %s; Expected: %s' % (ldflags, expected_ldflags))
            exit(1)
    else:
        expected_openssl_includes = '-I/usr/local/opt/openssl/include'
        expected_openssl_ldflags ='-L/usr/local/opt/openssl/lib'
        
        openssl_includes = sysconfig.get_config_var('OPENSSL_INCLUDES')
        openssl_ldflags = sysconfig.get_config_var('OPENSSL_LDFLAGS')

        if openssl_includes != expected_openssl_includes:
            print('Invalid openssl_includes: %s; Expected: %s' % (openssl_includes, expected_openssl_includes))
            exit(1)
        if openssl_ldflags != expected_openssl_ldflags:
            print('Invalid openssl_ldflags: %s; Expected: %s' % (openssl_ldflags, expected_openssl_ldflags))
            exit(1)

### Validate libreadline
if not have_libreadline:
    print('Missing libreadline')
    exit(1)