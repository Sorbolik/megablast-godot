extends SceneTree
## Runs a scenario (scenari/*.txt) with the GDScript port and writes the same
## lines as tools/riferimento.lua. Usage:
##   godot --headless --path . --script tools/traiettoria.gd -- SCENARIO OUT

const WorldScript := preload("res://sim/world.gd")


static func hex(v: float) -> String:
	return PackedFloat64Array([v]).to_byte_array().hex_encode()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var world = WorldScript.new("res://data/cortile.bin")
	var rb = world.add_robot(0)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_line("# gravity %s start %s %s" % [world.gravity, rb.x, rb.y])
	var tick := 0
	var text := FileAccess.get_file_as_string(args[0])
	for raw in text.split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()
		if line == "":
			continue
		var w := line.split(" ", false)
		match w[0]:
			"place":
				rb.x = float(w[1])
				rb.y = world.terrain.ground_below(rb.x, float(w[2]))
				rb.vx = 0.0
				rb.vy = 0.0
				rb.grounded = true
			"blast":
				world.explode(rb.x + float(w[1]), rb.y + float(w[2]))
			"eagle":
				world.fire_eagle(rb, float(w[1]) * (PI / 180.0))
			_:
				var fl: String = w[1] if w.size() > 1 else ""
				var input = WorldScript.Controls.new()
				input.right = fl.contains("R")
				input.left = fl.contains("L")
				input.jump = fl.contains("J")
				input.hold = input.jump
				for _i in range(int(w[0])):
					tick += 1
					world.update_robot(rb, input, true)
					out.store_line("%d %s %s %s %s %d %d" % [tick, hex(rb.x), hex(rb.y), hex(rb.vx), hex(rb.vy),
						1 if rb.grounded else 0, rb.hp])
	out.close()
	quit()
