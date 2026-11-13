-- Exports the Cortile terrain mask from the REAL simulation to data/cortile.bin
-- (one byte per cell, row 0 at the bottom, GRID_W x 360) so the port reads
-- exactly the same cells. Usage: luajit tools/esporta_mappa.lua MEGABLAST_DIR
local mb = arg[1]
package.path = mb .. "/client/?.lua;" .. package.path
local game = require "sim.game"
local g = game.new(1, "cortile")
local t = g.terrain
local f = assert(io.open("data/cortile.bin", "wb"))
local parts = {}
for i = 1, t.w * t.h do parts[i] = string.char(t.data[i]) end
f:write(table.concat(parts))
f:close()
local sp = {}
for _, s in ipairs(require("sim.maps").get("cortile").spawns) do sp[#sp + 1] = s.x .. "," .. s.from end
print(string.format("grid %d x %d cell %d ox %d spawns %s", t.w, t.h, t.cell, t.ox, table.concat(sp, " ")))
