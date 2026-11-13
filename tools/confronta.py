#!/usr/bin/env python3
"""Confronta tick per tick la traiettoria della simulazione vera di MegaBlast
(LuaJIT) con quella del port in Godot. Uso:
  python3 tools/confronta.py MEGABLAST_DIR [GODOT] [SCENARIO]
Finisce con OK solo se x, y, vx, vy (bit per bit), a terra e vita coincidono."""
import subprocess, sys, tempfile, os

mb = sys.argv[1]
godot = sys.argv[2] if len(sys.argv) > 2 else "godot"
scen = sys.argv[3] if len(sys.argv) > 3 else "scenari/movimento.txt"
d = tempfile.mkdtemp()
ref, port = os.path.join(d, "lua.txt"), os.path.join(d, "godot.txt")
subprocess.run(["luajit", "tools/riferimento.lua", mb, scen, ref], check=True)
subprocess.run(["timeout", "120", godot, "--headless", "--path", ".", "--script", "tools/traiettoria.gd", "--", scen, port],
               check=True, stdout=subprocess.DEVNULL)
a = [l.split()[:7] for l in open(ref) if not l.startswith("#")]
b = [l.split()[:7] for l in open(port) if not l.startswith("#")]
nomi = ["tick", "x", "y", "vx", "vy", "a_terra", "vita"]
for la, lb in zip(a, b):
    if la != lb:
        diff = [n for n, u, v in zip(nomi, la, lb) if u != v]
        print(f"DIVERSI al tick {la[0]}: {', '.join(diff)}")
        print("  lua  ", la)
        print("  godot", lb)
        sys.exit(1)
if len(a) != len(b):
    print(f"DIVERSI: {len(a)} tick in Lua, {len(b)} in Godot")
    sys.exit(1)
print(f"OK: {len(a)} tick identici bit per bit ({scen})")
