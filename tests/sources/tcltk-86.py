import tkinter
import _tkinter

header = _tkinter.TK_VERSION
lib = tkinter.Tk().getvar('tk_version')

print('header version=' + header)
print('lib version=' + lib)

if lib != '8.6' or header != '8.6':
  exit(1)
