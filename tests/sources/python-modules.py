"""
Make sure all the optional modules are installed.
This is needed for Linux since we build from source.
"""

from __future__ import print_function

import importlib
import sys

# The Python standard library as of Python 3.0
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

# Modules that had different names in Python 2
if sys.version_info.major == 2:
    def replace(lst, old, new):
        lst[lst.index(old)] = new

    # Keys are the Python 2 names
    # Values are the Python 3 names
    renames = {
        'ConfigParser': 'configparser',
        'copy_reg': 'copyreg',
        'HTMLParser': 'html',
        'httplib': 'http',
        'Queue': 'queue',
        'repr': 'reprlib',
        'SocketServer': 'socketserver',
        'xmlrpclib': 'xmlrpc',
        'Tkinter': 'tkinter'
    }

    # All of the Python 3 names should be in the list
    for python2name, python3name in renames.items():
        replace(standard_library, python3name, python2name)

# Add new modules
# See https://docs.python.org/3/whatsnew/index.html
if sys.version_info >= (3, 2):
    standard_library.extend([
        'concurrent',
    ])

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
