-- Exports the devil's clips from MegaBlast (client/battle/animations.lua, the
-- animation editor's ones) to data/clip.json: the spike plays THE SAME clips
-- with the same sampling (game/pose.gd = battle/pose.lua).
-- Usage: luajit tools/esporta_clip.lua MEGABLAST_DIR
local mb = arg[1]
local A = dofile(mb .. "/client/battle/animations.lua")
local WANTED = { "fermo", "corsa", "aria", "sale", "scende", "colpito", "vittoria", "naso", "sbadiglio", "guarda_coda" }
local function num(v) return string.format("%.6g", v) end
local out = {}
for _, name in ipairs(WANTED) do
	local c = A[name]
	if c then
		local tr = {}
		local keys = {}
		for k in pairs(c.tracks) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local vals = {}
			for i, v in ipairs(c.tracks[k]) do vals[i] = num(v) end
			tr[#tr + 1] = string.format('"%s":[%s]', k, table.concat(vals, ","))
		end
		local face = ""
		if c.face then
			local f = {}
			for i, v in ipairs(c.face) do f[i] = type(v) == "number" and num(v) or ('"' .. v .. '"') end
			face = ',"face":[' .. table.concat(f, ",") .. "]"
		end
		out[#out + 1] = string.format('"%s":{"duration":%s,"loop":%s,"tracks":{%s}%s}', name, num(c.duration),
			tostring(c.loop == true), table.concat(tr, ","), face)
	end
end
local f = assert(io.open("data/clip.json", "w"))
f:write("{", table.concat(out, ",\n"), "}\n")
f:close()
print("clip esportate: " .. #out)
