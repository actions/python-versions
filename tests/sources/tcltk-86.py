import tkinter
import _tkinter

lib = tkinter.Tk().getvar('tk_version')
header = _tkinter.TK_VERSION

if lib != '8.6' or header != '8.6':
  exit(1)
