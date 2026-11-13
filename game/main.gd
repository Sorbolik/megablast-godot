extends Node2D
## The spike's only scene: the Cortile, the movement physics (sim/world.gd,
## identical to MegaBlast) at 60 ticks per second, the drawing at the screen's
## frame rate (interpolated), the APPRENDISTA rig (game/devil.gd).
##
## Controls: A/D or arrows walk, W/space/up jump, Q explosion at the feet,
## E Tonante recoil toward the mouse, X spike extras on/off, L 2D lights on/off, N new/old drawing, M measurement,
## F hit face, mouse wheel zoom. On the phone: the buttons at the bottom.
##
## Command line (after --): --misura N [--secondi S] [--senza-extra]
## measures N devils replaying scenari/movimento.txt and writes the result in
## the console and in user://misure.txt. --foto FILE: a screenshot after 2 s.

const WorldScript := preload("res://sim/world.gd")
const DARK := Color(0.42, 0.4, 0.52)
const NEAR := 2.2                # the nearest zoom (battle/camera.lua)
const MAP_PX := 1.5              # cortile_2.png: 1.5 image pixels per world unit

var world: World
var robots: Array = []           # [robot, devil, prev position, script state]
var cam: Camera2D
var mask_img: Image
var mask_tex: ImageTexture
var zoom := NEAR
var extras := true
var new_art := true             # the new APPRENDISTA of WB-033 (N, NUOVO)
var lights := true               # Godot only: 2D lights (L, LUCI)
var dark: CanvasModulate          # the scene a bit darker, so the lights show
var touch := {left = false, right = false, jump = false}
var hud: Label
var measuring := false
var measure := {}
var scenario: Array = []
var photo := ""
var photo_t := 2.0
var fx_layer: Node2D
var sequence: Array = []
var results: PackedStringArray = []
var hud_layer: CanvasLayer
var held := ""                   # keys held from the command line (photos): R L J


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	world = WorldScript.new("res://data/cortile.bin")
	scenario = load_scenario("res://scenari/movimento.txt")
	build_map()
	fx_layer = Node2D.new()
	add_child(fx_layer)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.zoom = Vector2(NEAR, NEAR)
	cam.limit_left = -World.MARGIN
	cam.limit_right = World.WORLD_W + World.MARGIN
	cam.limit_top = 0
	cam.limit_bottom = World.WORLD_H
	add_child(cam)
	if "--senza-extra" in args:
		extras = false
	if "--senza-luci" in args:
		lights = false
	if "--vecchio" in args:
		new_art = false
	dark = CanvasModulate.new()
	add_child(dark)
	dark.color = DARK if lights else Color.WHITE
	add_robot(0)
	build_hud()
	var i := args.find("--misura")
	if i >= 0:
		var n := int(args[i + 1])
		var secs := 60.0
		var j := args.find("--secondi")
		if j >= 0:
			secs = float(args[j + 1])
		start_measure(n, secs)
	var f := args.find("--foto")
	if f >= 0:
		photo = args[f + 1]
	var z := args.find("--zoom")
	if z >= 0:
		zoom = float(args[z + 1])
		cam.zoom = Vector2(zoom, zoom)
	var a := args.find("--dopo")
	if a >= 0:
		photo_t = float(args[a + 1])
	var lids := args.find("--palpebre")
	if lids >= 0:
		robots[0][1].force_blink = float(args[lids + 1])
	var hold := args.find("--tieni")
	if hold >= 0:
		held = args[hold + 1]


func load_scenario(path: String) -> Array:
	var out := []
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.get_slice("#", 0).strip_edges()
		if line == "":
			continue
		var w := line.split(" ", false)
		if w[0].is_valid_int():
			out.append([int(w[0]), w[1] if w.size() > 1 else ""])
		else:
			out.append([w[0]] + Array(w.slice(1)))
	return out


# --- the map --------------------------------------------------------------------

func world_to_screen(x: float, y: float) -> Vector2:
	return Vector2(x, World.WORLD_H - y)


func build_map() -> void:
	RenderingServer.set_default_clear_color(Color(0.239, 0.227, 0.29))
	var sky := Sprite2D.new()
	sky.texture = load("res://art/cortile/cortile_cielo_2.png")
	sky.centered = false
	var sky_layer := Parallax2D.new()
	sky_layer.scroll_scale = Vector2(0.0, 0.0)
	sky_layer.add_child(sky)
	sky.scale = Vector2(2560.0 / sky.texture.get_width(), 1440.0 / sky.texture.get_height())
	sky.position = Vector2(-640, -360)
	add_child(sky_layer)
	# the three strips (battle/paintings.lua: cortile): where they start from the
	# top and how tall on a 720 screen, how much they follow the camera
	for g in [["lontano", 42, 678, 0.1], ["medio", 54, 666, 0.3], ["vicino", 558, 162, 0.6]]:
		var tex: Texture2D = load("res://art/cortile/cortile_%s_2.png" % g[0])
		var layer := Parallax2D.new()
		layer.scroll_scale = Vector2(g[3], g[3])
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		var h: float = g[2] * 1.5
		s.scale = Vector2(h / tex.get_height(), h / tex.get_height())
		s.position = Vector2(-World.MARGIN, g[1] * 1.5)
		layer.repeat_size = Vector2(tex.get_width() * s.scale.x, 0)
		layer.repeat_times = 3
		layer.add_child(s)
		add_child(layer)
	# the painted terrain, cut by the cells
	var paint := Sprite2D.new()
	paint.texture = load("res://art/cortile/cortile_2.png")
	paint.centered = false
	paint.position = Vector2(-World.MARGIN, 0)
	paint.scale = Vector2(1.0 / MAP_PX, 1.0 / MAP_PX)
	mask_img = Image.create(World.GRID_W, World.WORLD_H / World.CELL, false, Image.FORMAT_L8)
	refresh_mask(0, World.WORLD_H / World.CELL - 1)
	mask_tex = ImageTexture.create_from_image(mask_img)
	var m := ShaderMaterial.new()
	m.shader = load("res://game/map.gdshader")
	m.set_shader_parameter("mask", mask_tex)
	paint.material = m
	add_child(paint)


func refresh_mask(cy0: int, cy1: int) -> void:
	var t := world.terrain
	var rows := t.h
	for cy in range(cy0, cy1 + 1):
		for cx in range(t.w):
			mask_img.set_pixel(cx, rows - 1 - cy, Color(1, 1, 1) if t.data[cy * t.w + cx] != 0 else Color(0, 0, 0))
	if mask_tex:
		mask_tex.update(mask_img)


# --- robots -----------------------------------------------------------------------

func add_robot(spawn: int) -> Array:
	var rb = world.add_robot(spawn % World.SPAWNS.size())
	if spawn >= World.SPAWNS.size():
		rb.x += 60 * (spawn / World.SPAWNS.size())
		rb.y = world.terrain.ground_below(rb.x, rb.y + 200)
	var d: Devil = Devil.make(extras, lights, new_art)
	d.gravity = world.gravity
	add_child(d)
	var entry := [rb, d, Vector2(rb.x, rb.y), {line = 0, left = 0, offset = spawn * 37}]
	robots.append(entry)
	return entry


# --- input and the 60 Hz simulation ---------------------------------------------

func player_controls() -> World.Controls:
	var c := World.Controls.new()
	c.left = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or touch.left
	c.right = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or touch.right
	c.jump = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) \
		or Input.is_physical_key_pressed(KEY_SPACE) or touch.jump
	c.left = c.left or held.contains("L")
	c.right = c.right or held.contains("R")
	c.jump = c.jump or held.contains("J")
	c.hold = c.jump
	return c


## the scenario played again and again (measurement), one line after the other
func scripted_controls(entry: Array) -> World.Controls:
	var st: Dictionary = entry[3]
	var c := World.Controls.new()
	while st.left <= 0:
		var line: Array = scenario[(st.line + st.offset) % scenario.size()]
		st.line += 1
		if line[0] is int:
			st.left = line[0]
			st.flags = line[1]
		elif line[0] == "eagle":
			world.fire_eagle(entry[0], float(line[1]) * PI / 180.0)
	st.left -= 1
	var fl: String = st.flags
	c.right = fl.contains("R")
	c.left = fl.contains("L")
	c.jump = fl.contains("J")
	c.hold = c.jump
	return c


func _physics_process(_dt: float) -> void:
	world.events.clear()
	for e in robots:
		var rb = e[0]
		e[2] = Vector2(rb.x, rb.y)
		var c: World.Controls = scripted_controls(e) if measuring else player_controls()
		e[3].moving = (1 if c.right else 0) - (1 if c.left else 0)
		world.update_robot(rb, c, true)
		# fell off: back to its spawn (the spike has no deaths)
		if rb.y < -20 or rb.x < -World.KILL_SIDE or rb.x > World.WORLD_W + World.KILL_SIDE:
			var sp: Array = World.SPAWNS[robots.find(e) % World.SPAWNS.size()]
			rb.x = sp[0]
			rb.y = world.terrain.ground_below(rb.x, sp[1])
			rb.vx = 0.0
			rb.vy = 0.0
			rb.recoil = 0
			e[2] = Vector2(rb.x, rb.y)
	for ev in world.events:
		match ev.type:
			"explosion":
				refresh_mask(ev.row_min, ev.row_max)
				boom(world_to_screen(ev.x, ev.y), ev.r)
			"hurt":
				for e in robots:
					if e[0] == ev.robot:
						e[1].hit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var rb = robots[0][0]
		match event.physical_keycode:
			KEY_Q:
				world.explode(rb.x - 20 * robots[0][1].face, rb.y + 5)
			KEY_E:
				var m := get_global_mouse_position()
				world.fire_eagle(rb, atan2((World.WORLD_H - m.y) - (rb.y + 20), m.x - rb.x))
			KEY_X:
				toggle_extras()
			KEY_L:
				toggle_lights()
			KEY_N:
				toggle_art()
			KEY_M:
				start_sequence()
			KEY_F:
				robots[0][1].hit()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(NEAR * 2.0, zoom * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(0.6, zoom / 1.1)


func toggle_extras() -> void:
	extras = not extras
	respawn_devils()


func toggle_art() -> void:
	new_art = not new_art
	respawn_devils()


func toggle_lights() -> void:
	lights = not lights
	dark.color = DARK if lights else Color.WHITE
	respawn_devils()


func respawn_devils() -> void:
	for e in robots:
		var old: Devil = e[1]
		var d: Devil = Devil.make(extras, lights, new_art)
		d.gravity = world.gravity
		add_child(d)
		e[1] = d
		old.queue_free()


func boom(at: Vector2, r: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.4))
	ramp.set_color(1, Color(0.6, 0.1, 0.0, 0.0))
	p.color_ramp = ramp
	p.position = at
	fx_layer.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	if lights:
		# the flash: lights the devils, the walls and the smoke, then dies out
		var flash := PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(0.5, 0.0)
		g.width = 256
		g.height = 256
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		flash.texture = g
		flash.texture_scale = r / 40.0
		flash.color = Color(1.0, 0.75, 0.4)
		flash.energy = 3.0
		flash.height = 30.0
		flash.position = at
		fx_layer.add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "energy", 0.0, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_callback(flash.queue_free)
	cam.offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))


# --- drawing: every frame, interpolated between two ticks -------------------------

func _process(dt: float) -> void:
	var f := Engine.get_physics_interpolation_fraction()
	var solid := func(p: Vector2) -> bool: return world.terrain.solid(p.x, World.WORLD_H - p.y)
	for e in robots:
		var rb = e[0]
		var prev: Vector2 = e[2]
		var x: float = lerp(prev.x, rb.x, f)
		var y: float = lerp(prev.y, rb.y, f)
		var moving: int = e[3].get("moving", 0)
		e[1].animate(dt, world_to_screen(x, y), rb.grounded, moving, solid)
	var me: Devil = robots[0][1]
	cam.position = me.position + Vector2(0, -40 if photo == "" else -20)
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), min(1.0, dt * 6))
	cam.offset = cam.offset.lerp(Vector2.ZERO, min(1.0, dt * 10))
	update_hud(dt)
	if photo != "":
		photo_t -= dt
		hud_layer.visible = photo_t > 0.3
		if photo_t <= 0:
			get_viewport().get_texture().get_image().save_png(photo)
			print("foto: ", photo)
			get_tree().quit()


# --- HUD and the measurement ------------------------------------------------------

func build_hud() -> void:
	var layer := CanvasLayer.new()
	hud_layer = layer
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)
	var bar := HBoxContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -110
	bar.offset_bottom = -16
	bar.offset_left = 16
	bar.offset_right = -16
	bar.add_theme_constant_override("separation", 12)
	layer.add_child(bar)
	for spec in [["◀", "left"], ["▶", "right"], ["", ""], ["SALTA", "jump"], ["BOOM", "boom"],
			["TONANTE", "eagle"], ["EXTRA", "extra"], ["LUCI", "lights"], ["NUOVO", "art"], ["MISURA", "measure"]]:
		if spec[0] == "":
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.add_child(gap)
			continue
		var bt := Button.new()
		bt.text = spec[0]
		bt.custom_minimum_size = Vector2(110, 90)
		bt.add_theme_font_size_override("font_size", 24)
		bt.focus_mode = Control.FOCUS_NONE
		var key: String = spec[1]
		if key in ["left", "right", "jump"]:
			bt.button_down.connect(func(): touch[key] = true)
			bt.button_up.connect(func(): touch[key] = false)
		else:
			bt.pressed.connect(func(): button(key))
		bar.add_child(bt)


func button(key: String) -> void:
	var rb = robots[0][0]
	match key:
		"boom":
			world.explode(rb.x - 20 * robots[0][1].face, rb.y + 5)
		"eagle":
			world.fire_eagle(rb, deg_to_rad(200.0 if robots[0][1].face > 0 else -20.0))
		"extra":
			toggle_extras()
		"lights":
			toggle_lights()
		"art":
			toggle_art()
		"measure":
			start_sequence()


## MISURA: 4 and 8 devils, each without and with the spike's extras, 20 s
## each (+5 s to settle): the results stay on the screen
func start_sequence() -> void:
	sequence = [[4, false], [4, true], [8, false], [8, true]]
	results.clear()
	next_in_sequence()


func next_in_sequence() -> void:
	if sequence.is_empty():
		return
	var step: Array = sequence.pop_front()
	if extras != step[1]:
		toggle_extras()
	start_measure(step[0], 20)


func start_measure(n: int, secs: float) -> void:
	while robots.size() < n:
		add_robot(robots.size())
	measuring = true
	measure = {n = n, secs = secs, warm = 5.0, frames = PackedFloat32Array(), cpu = PackedFloat32Array()}


func update_hud(dt: float) -> void:
	var fps := Engine.get_frames_per_second()
	var cpu := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	hud.text = "%d FPS  %.2f ms/frame  logica %.2f ms  draw call %d  diavoletti %d  extra %s" % [
		fps, dt * 1000.0, cpu, draw, robots.size(), "sì" if extras else "no"]
	for r in results:
		hud.text += "\n" + r
	if measuring:
		measure.warm -= dt
		if measure.warm < 0:
			measure.frames.append(dt * 1000.0)
			measure.cpu.append(cpu)
			measure.secs -= dt
			hud.text += "\nMISURA: ancora %.0f s" % measure.secs
			if measure.secs <= 0:
				finish_measure()


func finish_measure() -> void:
	measuring = false
	var fr: PackedFloat32Array = measure.frames
	var sorted := fr.duplicate()
	sorted.sort()
	var total := 0.0
	for v in fr:
		total += v
	var avg := total / fr.size()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	var worst: float = sorted[sorted.size() - 1]
	var cpu_total := 0.0
	for v in measure.cpu:
		cpu_total += v
	var line := "%s | %s | diavoletti %d | extra %s | %d frame | media %.2f ms (%.0f FPS) | 1%% peggiori %.2f ms | peggiore %.2f ms | logica media %.2f ms" % [
		Time.get_datetime_string_from_system(), OS.get_model_name(), measure.n, "sì" if extras else "no",
		fr.size(), avg, 1000.0 / avg, p99, worst, cpu_total / measure.cpu.size()]
	print("MISURA ", line)
	var f := FileAccess.open("user://misure.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://misure.txt") else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()
	results.append("%d diavoletti, extra %s: %.2f ms (%.0f FPS), 1%% peggiori %.2f ms, peggiore %.1f ms" % [
		measure.n, "sì" if extras else "no", avg, 1000.0 / avg, p99, worst])
	if not sequence.is_empty():
		next_in_sequence()
	elif "--misura" in OS.get_cmdline_user_args():
		get_tree().quit()
