"""
Make sure all the optional modules are installed.
This is needed for Linux since we build from source.
"""

import importlib
import sys

# The Python standard library as of Python 3.2
standard_library = [
    'abc',
    'aifc',
    'antigravity',
    'argparse',
    'ast',
    'asynchat',
    'asyncore',
    'base64',
    'bdb',
    'binhex',
    'bisect',
    'bz2',
    'cProfile',
    'calendar',
    'cgi',
    'cgitb',
    'chunk',
    'cmd',
    'code',
    'codecs',
    'codeop',
    'collections',
    'colorsys',
    'compileall',
    'concurrent',
    'configparser',
    'contextlib',
    'copy',
    'copyreg',
    'crypt',
    'csv',
    'ctypes',
    'curses',
    'datetime',
    'dbm',
    'decimal',
    'difflib',
    'dis',
    'distutils',
    'doctest',
    'dummy_threading',
    'email',
    'encodings',
    'filecmp',
    'fileinput',
    'fnmatch',
    'formatter',
    'fractions',
    'ftplib',
    'functools',
    'genericpath',
    'getopt',
    'getpass',
    'gettext',
    'glob',
    'gzip',
    'hashlib',
    'heapq',
    'hmac',
    'html',
    'http',
    'idlelib',
    'imaplib',
    'imghdr',
    'imp',
    'importlib',
    'inspect',
    'io',
    'json',
    'keyword',
    'lib2to3',
    'linecache',
    'locale',
    'logging',
    'macpath',
    'mailbox',
    'mailcap',
    'mimetypes',
    'modulefinder',
    'multiprocessing',
    'netrc',
    'nntplib',
    'ntpath',
    'nturl2path',
    'numbers',
    'opcode',
    'operator',
    'optparse',
    'os',
    'pdb',
    'pickle',
    'pickletools',
    'pipes',
    'pkgutil',
    'platform',
    'plistlib',
    'poplib',
    'posixpath',
    'pprint',
    'profile',
    'pstats',
    'pty',
    'py_compile',
    'pyclbr',
    'pydoc',
    'pydoc_data',
    'queue',
    'quopri',
    'random',
    're',
    'readline',
    'reprlib',
    'rlcompleter',
    'runpy',
    'sched',
    'shelve',
    'shlex',
    'shutil',
    'signal',
    'site',
    'smtpd',
    'smtplib',
    'sndhdr',
    'socket',
    'socketserver',
    'sqlite3',
    'sre_compile',
    'sre_constants',
    'sre_parse',
    'ssl',
    '_ssl',
    'stat',
    'string',
    'stringprep',
    'struct',
    'subprocess',
    'sunau',
    'symbol',
    'symtable',
    'sysconfig',
    'tabnanny',
    'tarfile',
    'telnetlib',
    'tempfile',
    'test',
    'textwrap',
    'this',
    'threading',
    'timeit',
    'tkinter',
    'token',
    'tokenize',
    'trace',
    'traceback',
    'tty',
    'turtle',
    'turtledemo',
    'types',
    'unittest',
    'urllib',
    'uu',
    'uuid',
    'warnings',
    'wave',
    'weakref',
    'webbrowser',
    'wsgiref',
    'xdrlib',
    'xml',
    'xmlrpc',
    'zipfile'
]

# Add new modules
# See https://docs.python.org/3/whatsnew/index.html
if sys.version_info >= (3, 3):
    standard_library.extend([
        'ipaddress',
        'faulthandler',
        'lzma',
        'venv',
    ])

if sys.version_info >= (3, 4):
    standard_library.extend([
        'asyncio',
        'ensurepip',
        'enum',
        'pathlib',
        'selectors',
        'statistics',
        'tracemalloc',
    ])

if sys.version_info >= (3, 5):
    standard_library.extend([
        'typing',
        'zipapp',
    ])

if sys.version_info >= (3, 6):
    standard_library.extend([
        'secrets',
    ])

if sys.version_info >= (3, 7):
    standard_library.extend([
        'contextvars',
        'dataclasses',
    ])

# 'macpath' module has been removed from Python 3.8
if sys.version_info > (3, 7):
    standard_library.remove('macpath')

# 'dummy_threading' module has been removed from Python 3.9
if sys.version_info > (3, 8):
    standard_library.remove('dummy_threading')

# 'symbol' and 'formatter' modules have been removed from Python 3.10
if sys.version_info >= (3, 10):
    standard_library.remove('symbol')
    standard_library.remove('formatter')

# 'binhex' module has been removed from Python 3.11
if sys.version_info >= (3, 11):
    standard_library.remove('binhex')

# 'smtpd', 'asyncore' and 'asynchat' modules have been removed from Python 3.12
# https://docs.python.org/dev/whatsnew/3.12.html
if sys.version_info >= (3, 12):
    standard_library.remove('distutils')
    standard_library.remove('imp')
    standard_library.remove('smtpd')
    standard_library.remove('asyncore')
    standard_library.remove('asynchat')

# 'aifc', 'cgi', 'cgitb', 'chunk', 'crypt', 'imghdr', 'lib2to3', 'mailcap', 'nntplib',
# 'pipes', 'sndhdr', 'sunau', 'telnetlib', 'uu' and 'xdrlib' modules have been removed
# from Python 3.13
# https://docs.python.org/dev/whatsnew/3.13.html
if sys.version_info >= (3, 13):
    standard_library.remove('aifc')
    standard_library.remove('cgi')
    standard_library.remove('cgitb')
    standard_library.remove('chunk')
    standard_library.remove('crypt')
    standard_library.remove('imghdr')
    standard_library.remove('lib2to3')
    standard_library.remove('mailcap')
    standard_library.remove('nntplib')
    standard_library.remove('pipes')
    standard_library.remove('sndhdr')
    standard_library.remove('sunau')
    standard_library.remove('telnetlib')
    standard_library.remove('uu')
    standard_library.remove('xdrlib')

# Remove tkinter and Easter eggs
excluded_modules = [
    'antigravity',
    'this',
    'turtledemo',
]

def check_missing_modules(expected_modules):
    missing = []
    for module in expected_modules:
        try:
            importlib.import_module(module)
        except:
            missing.append(module)
    return missing

missing_modules = check_missing_modules(x for x in standard_library if x not in excluded_modules)
if missing_modules:
    print('The following modules are missing:')
    for module in missing_modules:
        print('  ', module)
    exit(1)
