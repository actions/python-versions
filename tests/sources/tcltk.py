import tkinter
import _tkinter

header = _tkinter.TK_VERSION
lib = tkinter.Tk().getvar('tk_version')

if lib != header:
  print('header version=' + header)
  print('lib version=' + lib)
  exit(1)
