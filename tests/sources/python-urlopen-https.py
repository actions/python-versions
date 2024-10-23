import sys
from urllib.request import urlopen

response = urlopen("https://raw.githubusercontent.com/actions/python-versions/c641695f6a07526c18f10e374e503e649fef9427/.gitignore")
data = response.read()
assert len(data) == 140, len(data)
