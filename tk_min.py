import tkinter as tk

root = tk.Tk()
label = tk.Label(root, text="Hello World!")
label.pack(padx=20, pady=20)
root.after(5000, root.destroy)    # Close the Window after 5 seconds
root.mainloop()
