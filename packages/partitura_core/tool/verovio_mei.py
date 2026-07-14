import sys, verovio
tk = verovio.toolkit()
if not tk.loadFile(sys.argv[1]):
    sys.stderr.write("verovio could not load\n"); sys.exit(1)
print(tk.getMEI())
