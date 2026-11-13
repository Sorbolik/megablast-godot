class_name Terrain
extends RefCounted
## Port of MegaBlast client/sim/terrain.lua: a grid of cells, 0 empty,
## 1 dirt, 2 steel. Origin bottom left, y up. ox extra columns on each side.
## Same operations in the same order as the Lua, so results match bit for bit.

const EMPTY := 0
const DIRT := 1
const STEEL := 2

var w: int
var h: int
var cell: float
var ox: int
var data: PackedByteArray


func _init(width: int, height: int, cell_size: float, extra_cols: int) -> void:
	w = width
	h = height
	cell = cell_size
	ox = extra_cols
	data = PackedByteArray()
	data.resize(w * h)


static func from_file(path: String, width: int, height: int, cell_size: float, extra_cols: int) -> Terrain:
	var t := Terrain.new(width, height, cell_size, extra_cols)
	var bytes := FileAccess.get_file_as_bytes(path)
	assert(bytes.size() == width * height, "maschera della mappa di misura sbagliata: " + path)
	t.data = bytes
	return t


func get_cell(cx: int, cy: int) -> int:
	cx += ox
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return 0
	return data[cy * w + cx]


func any_solid(cx0: int, cx1: int, cy0: int, cy1: int) -> bool:
	cx0 += ox
	cx1 += ox
	if cx0 < 0: cx0 = 0
	if cy0 < 0: cy0 = 0
	if cx1 > w - 1: cx1 = w - 1
	if cy1 > h - 1: cy1 = h - 1
	for cy in range(cy0, cy1 + 1):
		var row := cy * w
		for i in range(row + cx0, row + cx1 + 1):
			if data[i] != 0:
				return true
	return false


func solid(x: float, y: float) -> bool:
	return get_cell(floori(x / cell), floori(y / cell)) != 0


## Carves a circle (steel stays). Returns [cy0, cy1], the rows touched.
func carve(x: float, y: float, radius: float) -> Array[int]:
	var c := cell
	var cx0: int = max(-ox, floori((x - radius) / c))
	var cx1: int = min(w - ox - 1, floori((x + radius) / c))
	var cy0: int = max(0, floori((y - radius) / c))
	var cy1: int = min(h - 1, floori((y + radius) / c))
	var r2 := radius * radius
	for cy in range(cy0, cy1 + 1):
		var dy := (cy + 0.5) * c - y
		for cx in range(cx0, cx1 + 1):
			var dx := (cx + 0.5) * c - x
			var i := cy * w + cx + ox
			if dx * dx + dy * dy <= r2 and data[i] == 1:
				data[i] = 0
	return [cy0, cy1]


## First surface below height y in column x, or NAN if there is none.
func ground_below(x: float, y: float) -> float:
	var cx := floori(x / cell)
	var start: int = min(h - 1, floori(y / cell))
	for cy in range(start, -1, -1):
		if get_cell(cx, cy) != 0 and get_cell(cx, cy + 1) == 0:
			return (cy + 1) * cell
	return NAN
