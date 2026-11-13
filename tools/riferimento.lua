-- Reference run with the REAL MegaBlast simulation (client/sim, LuaJIT).
-- Usage: luajit tools/riferimento.lua MEGABLAST_DIR scenari/movimento.txt OUT.txt
-- Writes one line per tick: tick, the exact bits of x y vx vy, grounded, hp, x y. The Godot port
-- (sim/robot_sim.gd) runs the same scenario and tools/confronta.py compares.
local mb, scen, out = arg[1], arg[2], arg[3]
package.path = mb .. "/client/?.lua;" .. package.path
local game = require "sim.game"
local C = require "sim.config"

local g = game.new(1, "cortile")
for i, rb in ipairs(g.robots) do if i ~= 1 then rb.dead = true end end
local rb = g.robots[1]

local f = assert(io.open(out, "w"))
local ffi = require "ffi"
local cell = ffi.new("double[1]")
local function fmt(v) return string.format("%.17g", v) end
-- the exact bits of a double, little endian (as PackedFloat64Array.hex_encode in Godot)
local function hex(v)
	cell[0] = v
	local b = ffi.cast("uint8_t*", cell)
	local s = {}
	for i = 0, 7 do s[#s + 1] = string.format("%02x", b[i]) end
	return table.concat(s)
end
local function dump(tick)
	f:write(tick, " ", hex(rb.x), " ", hex(rb.y), " ", hex(rb.vx), " ", hex(rb.vy), " ", rb.grounded and 1 or 0,
		" ", rb.hp, " ", fmt(rb.x), " ", fmt(rb.y), "\n")
end
f:write("# gravity ", fmt(g.gravity), " start ", fmt(rb.x), " ", fmt(rb.y), "\n")

local tick = 0
for line in io.lines(scen) do
	line = line:gsub("#.*", "")
	local w = {}
	for s in line:gmatch("%S+") do w[#w + 1] = s end
	if w[1] == "place" then
		rb.x = tonumber(w[2])
		rb.y = g.terrain:ground_below(rb.x, tonumber(w[3]))
		rb.vx, rb.vy, rb.grounded = 0, 0, true
	elseif w[1] == "blast" then
		g:explode(rb.x + tonumber(w[2]), rb.y + tonumber(w[3]), nil, game.MISSILE_BLAST)
	elseif w[1] == "eagle" then
		local a, s = math.rad(tonumber(w[2])), C.EAGLE
		rb.recoil = s.recoil_ticks
		rb.recoil_vx, rb.recoil_vy = -math.cos(a) * s.recoil, -math.sin(a) * s.recoil
		rb.grounded, rb.knocked, rb.fall_top = false, false, nil
	elseif tonumber(w[1]) then
		local fl = w[2] or ""
		local input = { right = fl:find("R") ~= nil, left = fl:find("L") ~= nil, jump = fl:find("J") ~= nil }
		input.hold = input.jump
		for _ = 1, tonumber(w[1]) do
			tick = tick + 1
			g:update_robot(rb, input, true)
			dump(tick)
		end
	end
end
f:close()
