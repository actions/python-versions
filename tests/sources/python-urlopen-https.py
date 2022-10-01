import sys

if sys.version_info[0] == 2:
    from urllib2 import urlopen
else:
    from urllib.request import urlopen

response = urlopen("https://raw.githubusercontent.com/actions/python-versions/c641695f6a07526c18f10e374e503e649fef9427/.gitignore")
data = response.read()
assert len(data) == 140, len(data)
