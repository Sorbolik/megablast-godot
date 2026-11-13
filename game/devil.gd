class_name Devil
extends Node2D
## The APPRENDISTA rebuilt in Godot from the SAME drawings as MegaBlast
## (art/apprendista, tools/prepara_pezzi.py), with Godot's own tools:
##   - Skeleton2D + Bone2D: one skeleton, the joints where MegaBlast has them;
##   - Polygon2D skinned meshes: every piece is a grid bent by its bones
##     (torso that breathes, elbows and knees, ONE continuous tail, the flame);
##   - the same clips as MegaBlast (data/clip.json, game/pose.gd) and the same
##     springs (battle/scoria.lua), so the motion is the game's one;
##   - on top, what MegaBlast can't do today: a real cloth cape (a 2D mesh
##     simulated point by point, not one bent strip), a flame that trails
##     behind the motion (a simulated chain bends its bones), embers and glow,
##     eyes that blink and look around (a shader on the eye, the eye's shape
##     is the mask).
## Graphics only: the simulation (sim/world.gd) doesn't know about it.

const DISEGNO_H := 39.2          # world px from the feet to the top of the head
const UNITS := 200.0             # drawing units, same height
const ART := "res://art/apprendista/"

# springs (battle/scoria.lua): position, velocity, stiffness, damping
enum { SQ, LEAN, SHOVE, KICK, HEAD, TAIL }
const SPRING_W := [16.0, 10.0, 12.0, 18.0, 11.0, 7.0]
const SPRING_Z := [0.3, 0.45, 0.5, 0.45, 0.28, 0.25]
const STEP := 0.9
const FACES := ["testa", "testa_felice", "testa_colpita", "testa_arrabbiata", "testa_paura", "testa_ko"]

## Turn off the spike's extras to see the devil as MegaBlast draws it today
## (rigid pieces, no cloth, no eyes): the A/B in the measurements.
@export var extras := true
@export var team_color := Color(0.85, 0.2, 0.2)

var k := DISEGNO_H / UNITS
var rig: Dictionary
var skel: Skeleton2D
var b := {}                      # bones by name
var rest_pos := {}               # rest position of each bone (godot local units)
var head_poly: Polygon2D
var face_tex := {}
var current_face := "testa"
var eyes: Array[Sprite2D] = []
var eyes_node: Node2D
var cape: Polygon2D
var cape_grid := {}              # the cloth: points, previous points, pins
var flame_chain: Array[Vector2] = []
var flame_prev: Array[Vector2] = []
var flame_rot := [0.0, 0.0, 0.0]
var embers: CPUParticles2D
var glow: Sprite2D
var gravity := 193.8             # world px/s^2, set from the simulation

# the driver state (as battle/scoria.lua)
var x := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var v := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var goal := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var t := 0.0
var passo := 0.0
var cammina := 0.0
var ground := true
var vx := 0.0
var vy := 0.0
var last := Vector2.ZERO
var face := 1
var braccia := [0.0, 0.0]
var gambe := [0.0, 0.0]
var coda_a: Array[float] = []
var action := ""
var action_t := 0.0
var pose := Pose.new()
var blink := 0.0
var blink_timer := 2.0
var blink_phase := -1.0
var blink_double := false
var look := Vector2.ZERO
var look_goal := Vector2.ZERO
var look_timer := 1.0
var elbow := [0.0, 0.0]
## photos: the lids held at this value (0 open, 1 closed), -1 = they blink by themselves
var force_blink := -1.0
var elbow_v := [0.0, 0.0]


func _ready() -> void:
	Pose.load_clips("res://data/clip.json")
	rig = JSON.parse_string(FileAccess.get_file_as_string(ART + "rig.json"))
	scale = Vector2(k, k)
	build()


## units (y up) -> godot local (y down)
static func U(px: float, py: float) -> Vector2:
	return Vector2(px, -py)


func tex(name: String) -> Texture2D:
	return load(ART + name + ".png")


# --- the skeleton ----------------------------------------------------------------

func bone(name: String, parent: Node, pos: Vector2) -> Bone2D:
	var bn := Bone2D.new()
	bn.name = name
	bn.position = pos
	bn.set_autocalculate_length_and_angle(false)
	bn.set_length(12.0)
	parent.add_child(bn)
	b[name] = bn
	rest_pos[name] = pos
	return bn


func build() -> void:
	var pv: Dictionary = rig.pivots
	var pc: Dictionary = rig.pieces
	skel = Skeleton2D.new()
	skel.name = "Scheletro"
	add_child(skel)
	var body := bone("corpo", skel, Vector2.ZERO)
	var forma := bone("forma", body, Vector2.ZERO)
	var busto := bone("busto", forma, U(pv.busto[0], pv.busto[1]))
	bone("petto", busto, U(-10.4, 42.8))
	var collo := bone("collo", forma, U(pv.testa[0], pv.testa[1]))
	bone("cranio", collo, U(-15.0, 94.8))
	var f := bone("fiamma_0", collo, U(0, 82))
	for i in range(1, 4):
		f = bone("fiamma_%d" % i, f, U(0, 15))
	var ba := bone("braccio_a", forma, U(pv.braccio[0], pv.braccio[1]))
	bone("mano_a", bone("gomito_a", ba, U(-8.5, -27)), U(0, -24))
	var bd := bone("braccio_d", forma, U(pv.braccio_dietro[0], pv.braccio_dietro[1]))
	bone("mano_d", bone("gomito_d", bd, U(-5.1, -26)), U(0, -26))
	var ga := bone("gamba_a", forma, U(pv.gamba[0], pv.gamba[1]))
	bone("piede_a", bone("ginocchio_a", ga, U(-5.2, -34.8)), U(0, -32))
	var gd := bone("gamba_d", forma, U(pv.gamba_dietro[0], pv.gamba_dietro[1]))
	bone("piede_d", bone("ginocchio_d", gd, U(9.2, -34.6)), U(0, -32))
	# the tail: a chain on the drawing's joints, turned like the rest angles
	var tl: Dictionary = rig.tail
	var j: Array = tl.joints
	var rest: Array = tl.rest
	var parent: Node = forma
	for i in range(rest.size()):
		var pos := U(j[i][0], j[i][1]) if i == 0 else Vector2(Vector2(j[i][0], j[i][1]).distance_to(Vector2(j[i - 1][0], j[i - 1][1])), 0)
		var tb := bone("coda_%d" % i, parent, pos)
		tb.rotation = -(rest[i] - (rest[i - 1] if i > 0 else 0.0))
		parent = tb
		coda_a.append(rest[i] - (rest[i - 1] if i > 0 else 0.0))
	bone("coda_punta", parent, Vector2(Vector2(j[5][0], j[5][1]).distance_to(Vector2(j[4][0], j[4][1])), 0))
	for n in b:
		b[n].rest = b[n].transform

	# the pieces, from the back (the fermo clip's layers in MegaBlast)
	var tail_poly := mesh_rect("coda", tl.left + tl.w / 2, tl.top - tl.h / 2, tl.w, tl.h, 8, 10,
		chain_weights(["coda_0", "coda_1", "coda_2", "coda_3", "coda_4", "coda_punta"], 7.0))
	tail_poly.name = "coda"
	if extras and rig.cape:
		make_cape()
	piece("braccio_dietro", ["braccio_d", "gomito_d", "mano_d"])
	piece("gamba_dietro", ["gamba_d", "ginocchio_d", "piede_d"])
	piece("busto", ["busto", "petto"])
	if pc.busto.tint:
		var tint := piece("busto", ["busto", "petto"], "busto_tinta")
		tint.modulate = team_color
	head_poly = piece("testa", [], "testa", head_weights)
	for fc in FACES:
		face_tex[fc] = tex(fc)
	make_eyes()
	make_flame()
	piece("gamba", ["gamba_a", "ginocchio_a", "piede_a"])
	piece("braccio", ["braccio_a", "gomito_a", "mano_a"])


## the global (skeleton space, godot units) position of a bone at rest
func rest_global(name: String) -> Vector2:
	var bn: Node = b[name]
	var tr := Transform2D.IDENTITY
	while bn is Bone2D:
		tr = bn.rest * tr
		bn = bn.get_parent()
	return tr.origin


## weights along a chain of bones: each vertex goes to the segments nearest it
## (gaussian of the distance), so the mesh bends smoothly at the joints
func chain_weights(names: Array, sigma: float) -> Callable:
	var pts: Array[Vector2] = []
	for n in names:
		pts.append(rest_global(n))
	return func(p: Vector2) -> Dictionary:
		var w := {}
		var total := 0.0
		for i in range(pts.size() - 1):
			var d := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p)
			var wi := exp(-(d * d) / (sigma * sigma)) + 1e-6
			w[names[i]] = w.get(names[i], 0.0) + wi
			total += wi
		for n in w:
			w[n] /= total
		return w


## the head: rigid on the neck, the top (horns) on the skull bone: it can squash
func head_weights(p: Vector2) -> Dictionary:
	var top := smoothstep(-185.0, -225.0, p.y)
	return {"collo": 1.0 - top, "cranio": top}


func piece(spot: String, chain: Array, img := "", weights = null) -> Polygon2D:
	var p: Dictionary = rig.pieces[spot]
	var wf: Callable
	if weights is Callable:
		wf = weights
	elif chain.size() == 1:
		wf = func(_p: Vector2) -> Dictionary: return {chain[0]: 1.0}
	else:
		var span: float = rest_global(chain[0]).distance_to(rest_global(chain[chain.size() - 1]))
		wf = chain_weights(chain, max(6.0, span * 0.3))
	var poly := mesh_rect(img if img != "" else spot, p.cx, p.cy, p.w, p.h, 6, 8, wf)
	poly.name = img if img != "" else spot
	return poly


## A Polygon2D: a cols x rows grid over the drawing (center cx, cy and size in
## units, y up), skinned to the bones that weights() gives for each vertex
func mesh_rect(img: String, cx: float, cy: float, w: float, h: float, cols: int, rows: int,
		weights: Callable) -> Polygon2D:
	var t := tex(img)
	var poly := Polygon2D.new()
	poly.texture = t
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for r in range(rows + 1):
		for c in range(cols + 1):
			var u := float(c) / cols
			var vv := float(r) / rows
			verts.append(U(cx - w / 2 + u * w, cy + h / 2 - vv * h))
			uvs.append(Vector2(u * t.get_width(), vv * t.get_height()))
	var quads := []
	for r in range(rows):
		for c in range(cols):
			var i := r * (cols + 1) + c
			quads.append(PackedInt32Array([i, i + 1, i + cols + 2, i + cols + 1]))
	poly.polygon = verts
	poly.uv = uvs
	poly.polygons = quads
	add_child(poly)
	poly.skeleton = poly.get_path_to(skel)
	var per := {}
	for i in range(verts.size()):
		var wt: Dictionary = weights.call(verts[i])
		for n in wt:
			if not per.has(n):
				var arr := PackedFloat32Array()
				arr.resize(verts.size())
				per[n] = arr
			per[n][i] = wt[n]
	for n in per:
		poly.add_bone(skel.get_path_to(b[n]), per[n])
	return poly


# --- the eyes --------------------------------------------------------------------

func make_eyes() -> void:
	eyes_node = Node2D.new()
	eyes_node.name = "occhi"
	add_child(eyes_node)
	var follow := RemoteTransform2D.new()
	b.collo.add_child(follow)
	follow.remote_path = follow.get_path_to(eyes_node)
	follow.update_scale = true
	eyes_node.visible = extras
	var head: Dictionary = rig.pieces.testa
	var neck := Vector2(rig.pivots.testa[0], rig.pivots.testa[1])
	var shader := load("res://game/eye.gdshader")
	for e in rig.eyes:
		var s := Sprite2D.new()
		s.texture = tex(e.img)
		s.position = U(head.cx + e.cx - neck.x, head.cy + e.cy - neck.y)
		s.scale = Vector2(e.w / s.texture.get_width(), e.h / s.texture.get_height())
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("pupil", tex(e.pupil))
		m.set_shader_parameter("lid_color", Color8(e.lid[0], e.lid[1], e.lid[2]))
		s.material = m
		eyes_node.add_child(s)
		eyes.append(s)


# --- the flame ---------------------------------------------------------------------

func make_flame() -> void:
	var p: Dictionary = rig.pieces.fiamma
	if extras:
		glow = Sprite2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(0.5, 0.0)
		g.width = 64
		g.height = 64
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.65, 0.2, 0.55))
		grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
		g.gradient = grad
		glow.texture = g
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.scale = Vector2(2.0, 2.4)
		b.fiamma_1.add_child(glow)
	mesh_rect("fiamma", p.cx, p.cy, p.w, p.h, 4, 8,
		chain_weights(["fiamma_0", "fiamma_1", "fiamma_2", "fiamma_3"], 9.0)).name = "fiamma"
	if extras:
		embers = CPUParticles2D.new()
		embers.amount = 10
		embers.lifetime = 0.9
		embers.local_coords = false
		embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		embers.emission_sphere_radius = 6.0
		embers.direction = Vector2(0, -1)
		embers.spread = 25.0
		embers.gravity = Vector2(0, -60)
		embers.initial_velocity_min = 20.0
		embers.initial_velocity_max = 50.0
		embers.scale_amount_min = 0.12
		embers.scale_amount_max = 0.25
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 0.85, 0.3, 1))
		ramp.set_color(1, Color(1, 0.3, 0.05, 0))
		embers.color_ramp = ramp
		var dot := GradientTexture2D.new()
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(0.5, 0.0)
		dot.width = 16
		dot.height = 16
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		dot.gradient = soft
		embers.texture = dot
		var add2 := CanvasItemMaterial.new()
		add2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		embers.material = add2
		b.fiamma_2.add_child(embers)
	for i in range(4):
		flame_chain.append(Vector2.ZERO)
		flame_prev.append(Vector2.ZERO)


# --- the cape: a real cloth ------------------------------------------------------

func make_cape() -> void:
	var cp: Dictionary = rig.cape
	var t2 := tex(cp.img)
	cape = Polygon2D.new()
	cape.name = "mantello"
	cape.texture = t2
	var cols := 4
	var rows := 6
	var uvs := PackedVector2Array()
	var quads := []
	var rest := PackedVector2Array()
	var cx: float = cp.at[0] + cp.x
	var cy: float = cp.at[1] + cp.y
	for r in range(rows + 1):
		for c in range(cols + 1):
			var u := float(c) / cols
			var vv := float(r) / rows
			rest.append(U(cx - cp.w / 2 + u * cp.w, cy + cp.h / 2 - vv * cp.h))
			uvs.append(Vector2(u * t2.get_width(), vv * t2.get_height()))
	for r in range(rows):
		for c in range(cols):
			var i := r * (cols + 1) + c
			quads.append(PackedInt32Array([i, i + 1, i + cols + 2, i + cols + 1]))
	cape.polygon = rest
	cape.uv = uvs
	cape.polygons = quads
	add_child(cape)
	# the constraints, once: pairs of points and their length (units)
	var ca := PackedInt32Array()
	var cb := PackedInt32Array()
	var cl := PackedFloat32Array()
	for r in range(rows + 1):
		for c in range(cols + 1):
			var i := r * (cols + 1) + c
			var pairs := []
			if c < cols:
				pairs.append(i + 1)
			if r < rows:
				pairs.append(i + cols + 1)
				if c < cols:
					pairs.append(i + cols + 2)
				if c > 0:
					pairs.append(i + cols)
			for j in pairs:
				if i <= cols and j <= cols:
					continue
				ca.append(i)
				cb.append(j)
				cl.append(rest[i].distance_to(rest[j]))
	cape_grid = {pins = cols + 1, rest = rest, p = PackedVector2Array(), o = PackedVector2Array(),
		ca = ca, cb = cb, cl = cl, ready = false}


## the shape's frame (forma bone) in the parent's space: the pins follow it
func forma_xform() -> Transform2D:
	return transform * b.corpo.transform * b.forma.transform


## The cloth (Verlet, like battle/cloth.lua but a whole 2D grid instead of one
## chain): the top row pinned to the shoulders, the rest falls, keeps its
## lengths, can't pass through the body to the front nor into the terrain.
## Fixed 60 Hz steps, so it behaves the same at every frame rate.
func cape_step(dt: float, solid: Callable) -> void:
	if cape == null:
		return
	var g := cape_grid
	var rest: PackedVector2Array = g.rest
	var n := rest.size()
	var pins: int = g.pins
	var fx := forma_xform()
	var p: PackedVector2Array = g.p
	var o: PackedVector2Array = g.o
	if not g.ready:
		p.resize(n)
		o.resize(n)
		for i in range(n):
			p[i] = fx * rest[i]
			o[i] = p[i]
		g.ready = true
	var to_forma := fx.affine_inverse()
	var ca: PackedInt32Array = g.ca
	var cb: PackedInt32Array = g.cb
	var cl: PackedFloat32Array = g.cl
	var m := ca.size()
	var steps := mini(3, maxi(1, roundi(dt * 60.0)))
	var h := dt / steps
	var drag := exp(-4.0 * h)
	var fall := Vector2(0, gravity * 0.9) * h * h
	for _s in range(steps):
		for i in range(pins):
			p[i] = fx * rest[i]
			o[i] = p[i]
		for i in range(pins, n):
			var q := p[i]
			p[i] = q + (q - o[i]) * drag + fall
			o[i] = q
		for _it in range(3):
			for c in range(m):
				var i := ca[c]
				var j := cb[c]
				var d := p[j] - p[i]
				var len := d.length()
				if len < 1e-6:
					continue
				var corr := d * ((len - cl[c] * k) / len)
				if i < pins:
					p[j] -= corr
				else:
					p[i] += corr * 0.5
					p[j] -= corr * 0.5
		for i in range(pins, n):
			var lp := to_forma * p[i]
			var front := rest[i].x + 6.0
			if lp.x > front:
				lp.x = front
				p[i] = fx * lp
	# the terrain: once per frame, only the lower half (the top is on the body)
	if solid.is_valid():
		for i in range(n / 2, n):
			if solid.call(p[i]):
				p[i] = o[i]
	g.p = p
	g.o = o
	var inv := transform.affine_inverse()
	var out := PackedVector2Array()
	out.resize(n)
	for i in range(n):
		out[i] = inv * p[i]
	cape.polygon = out


# --- the driver: the same logic as battle/scoria.lua ------------------------------

func springs(dt: float) -> void:
	var n := maxi(1, ceili(dt * 120))
	var h := dt / n
	for _i in range(n):
		for i in range(6):
			var w: float = SPRING_W[i]
			var z: float = SPRING_Z[i]
			v[i] += (w * w * (goal[i] - x[i]) - 2 * z * w * v[i]) * h
			x[i] += v[i] * h


func hit() -> void:
	action = "colpito"
	action_t = 0.0
	v[SQ] -= 4
	start_blink(true)


## One frame. pos: the feet (godot world coords, y down), grounded, moving
## (-1, 0, 1, the controls), solid(p): terrain test for the cape
func animate(dt: float, pos: Vector2, grounded: bool, moving: int, solid: Callable) -> void:
	t += dt
	if moving != 0:
		face = moving
	var dx := absf(pos.x - last.x)
	if dt > 0:
		vx = (pos.x - last.x) / dt
		vy = -(pos.y - last.y) / dt
	last = pos
	position = pos
	scale = Vector2(k * face, k)

	var runs := grounded and moving != 0 and dx < DISEGNO_H
	if runs:
		passo = fmod(passo + dx / (STEP * DISEGNO_H) * 2 * PI, 2 * PI)
	cammina += ((1.0 if runs else 0.0) - cammina) * min(1.0, dt * 10)
	if grounded and not ground and vy < -40:
		v[SQ] -= min(7.0, -vy / 40)
		v[HEAD] -= min(4.0, -vy / 80)
		v[TAIL] -= min(3.0, -vy / 100)
		if extras and vy < -200:
			start_blink(false)
	elif not grounded and ground and vy > 20:
		v[SQ] += 4
		v[TAIL] += 2
	ground = grounded
	if action != "":
		action_t += dt

	pose.reset()
	var forward := moving * face
	var lean := -0.22 * clampf(forward * 50 / 70.0, -1, 1) * cammina
	var sq := 0.0
	var cd := 0.2 * clampf(forward * 50 / 70.0, -1, 1) * cammina
	if not grounded:
		cd += clampf(vy / 900, -0.2, 0.2)
	if action == "colpito" and action_t < Pose.clips.colpito.duration:
		pose.add("colpito", action_t, 1)
	elif not grounded:
		var jump_v := sqrt(2 * gravity * 5.2 * 28 / 3.612)
		var above := clampf(vy / jump_v, -1, 1)
		pose.add("aria", t, 1)
		pose.add("sale", 0, above)
		pose.add("scende", 0, -above)
		sq = min(0.2, absf(vy) / 900)
	elif runs or cammina > 0.05:
		pose.add("fermo", t, 1 - cammina)
		pose.add("corsa", passo / (2 * PI) * Pose.clips.corsa.duration, cammina)
	else:
		action = ""
		pose.add("fermo", t, 1)
	goal[SQ] = pose.get_c("schiaccia") + sq
	goal[LEAN] = lean
	goal[HEAD] = pose.get_c("testa")
	goal[TAIL] = cd + pose.get_c("coda")
	springs(dt)
	apply_pose(dt)
	set_face(pose.face_name if pose.face_name != "" else "testa")
	if extras:
		eyes_step(dt)
		flame_step(dt)
		cape_step(dt, solid)


func apply_pose(dt: float) -> void:
	var po := pose
	var q: float = max(0.4, x[SQ])
	var lx := 1 + (1 - q) * 0.8
	var pv: Dictionary = rig.pivots
	b.forma.scale = Vector2(lx, q)
	b.corpo.rotation = -(x[LEAN] + po.get_c("corpo"))
	b.corpo.position = Vector2(-x[SHOVE] * UNITS * 0.75 + po.get_c("corpo_x"), -po.get_c("salto"))
	var follow: float = min(1.0, dt * 16)
	braccia[0] += (po.get_c("braccio_a") - braccia[0]) * follow
	braccia[1] += (po.get_c("braccio_d") - braccia[1]) * follow
	gambe[0] += (po.get_c("gamba_a") - gambe[0]) * follow
	gambe[1] += (po.get_c("gamba_d") - gambe[1]) * follow
	b.braccio_a.rotation = -braccia[0]
	b.braccio_d.rotation = -braccia[1]
	b.gamba_a.rotation = -gambe[0]
	b.gamba_d.rotation = -gambe[1]
	b.gamba_a.position = U(pv.gamba[0] + po.get_c("gamba_a_x"), pv.gamba[1] + po.get_c("alza_a"))
	b.gamba_d.position = U(pv.gamba_dietro[0] + po.get_c("gamba_d_x"), pv.gamba_dietro[1] + po.get_c("alza_d"))
	b.braccio_a.position = U(pv.braccio[0] + po.get_c("braccio_a_x"), pv.braccio[1] + po.get_c("braccio_a_y"))
	b.braccio_d.position = U(pv.braccio_dietro[0] + po.get_c("braccio_d_x"), pv.braccio_dietro[1] + po.get_c("braccio_d_y"))
	b.busto.position = U(pv.busto[0] + po.get_c("busto_x"), pv.busto[1] + po.get_c("busto_y"))
	b.busto.rotation = -po.get_c("busto")
	var tl: Dictionary = rig.tail
	b.coda_0.position = U(tl.joints[0][0] + po.get_c("coda_x"), tl.joints[0][1] + po.get_c("coda_y"))
	tail_step(dt, po.get_c("coda_gira"))
	b.collo.position = U(pv.testa[0] + po.get_c("testa_x"), pv.testa[1] + po.get_c("testa_y"))
	b.collo.rotation = -x[HEAD]
	b.collo.scale = Vector2(1 / lx, 1 / q)
	b.fiamma_0.position = U(po.get_c("fiamma_x"), 82 + po.get_c("fiamma_y"))
	b.fiamma_0.rotation = -po.get_c("fiamma")
	var sqf := po.get_c("fiamma_schiaccia")
	b.fiamma_0.scale = Vector2(po.get_c("fiamma_scala_x") / sqf, po.get_c("fiamma_scala_y") * sqf)
	if extras:
		# the spike's extras on the mesh: the chest breathes, the skull squashes a
		# little after the body (jelly), elbows and knees follow through
		b.petto.scale = Vector2(1.0 + 0.025 * sin(t * 2.4), 1.0 + 0.04 * sin(t * 2.4))
		var jelly: float = clampf(1.0 + (x[SQ] - 1.0) * 0.6, 0.85, 1.15)
		b.cranio.scale = Vector2(1.0 / jelly, jelly)
		for i in range(2):
			var target: float = clampf(-(braccia[i] - (po.get_c("braccio_a") if i == 0 else po.get_c("braccio_d"))) * 2.0 + 0.15, -0.3, 0.9)
			elbow_v[i] += (120.0 * (target - elbow[i]) - 14.0 * elbow_v[i]) * dt
			elbow[i] += elbow_v[i] * dt
		b.gomito_a.rotation = -elbow[0]
		b.gomito_d.rotation = -elbow[1]
		var knee: float = clampf((1.0 - q) * 1.6, 0, 0.5)
		b.ginocchio_a.rotation = knee
		b.ginocchio_d.rotation = knee


func tail_step(dt: float, turn_around: float) -> void:
	var r: Array = rig.tail.rest
	var first := 0.0
	for i in range(coda_a.size()):
		var rest: float = r[i] - first
		first = r[i]
		var a: float = rest + (x[TAIL] + sin(t * 2.6 - (i + 1) * 0.8) * 0.05) * (0.5 + 0.1 * (i + 1))
		coda_a[i] += (a - coda_a[i]) * min(1.0, dt * (18 - 2.5 * (i + 1)))
		var g := turn_around if i == 0 else 0.0
		b["coda_%d" % i].rotation = -(coda_a[i] + g)


func set_face(f: String) -> void:
	if f == current_face or not face_tex.has(f):
		return
	current_face = f
	head_poly.texture = face_tex[f]
	if eyes_node:
		eyes_node.visible = extras and f == "testa"


# --- eyes: blink and look ----------------------------------------------------------

func start_blink(double: bool) -> void:
	if blink_phase < 0:
		blink_phase = 0.0
		blink_double = double


func eyes_step(dt: float) -> void:
	blink_timer -= dt
	if blink_timer <= 0:
		start_blink(randf() < 0.15)
		blink_timer = randf_range(2.2, 5.5)
	if blink_phase >= 0:
		# closes in 70 ms, stays 40 ms, opens in 110 ms
		blink_phase += dt
		var ph := blink_phase
		if ph < 0.07:
			blink = ph / 0.07
		elif ph < 0.11:
			blink = 1.0
		elif ph < 0.22:
			blink = 1.0 - (ph - 0.11) / 0.11
		else:
			blink = 0.0
			blink_phase = -1.0
			if blink_double:
				blink_double = false
				blink_phase = -0.08
				blink_timer = 0.12
	# the look: toward where it moves, otherwise now and then somewhere else
	look_timer -= dt
	if absf(vx) > 20 or absf(vy) > 60:
		look_goal = Vector2(clampf(vx / 120.0 * face, -1, 1), clampf(-vy / 300.0, -1, 1))
	elif look_timer <= 0:
		look_timer = randf_range(0.8, 2.5)
		look_goal = Vector2(randf_range(-0.6, 1.0), randf_range(-0.5, 0.4))
	look = look.lerp(look_goal, min(1.0, dt * 12))
	if force_blink >= 0:
		blink = force_blink
	for e in eyes:
		var m := e.material as ShaderMaterial
		m.set_shader_parameter("blink", blink)
		m.set_shader_parameter("look", look)


# --- the flame: a chain that floats up and trails behind -------------------------

func flame_step(dt: float) -> void:
	var names := ["fiamma_0", "fiamma_1", "fiamma_2", "fiamma_3"]
	var base: Vector2 = b.fiamma_0.global_position
	var seg := 15.0 * k
	if flame_chain[0] == Vector2.ZERO:
		for i in range(4):
			flame_chain[i] = base + Vector2(0, -seg * i)
			flame_prev[i] = flame_chain[i]
	var steps := maxi(1, ceili(dt * 120.0))
	var h := dt / steps
	for _s in range(steps):
		flame_chain[0] = base
		flame_prev[0] = base
		for i in range(1, 4):
			var p := flame_chain[i]
			var vel := (p - flame_prev[i]) * exp(-6.0 * h)
			flame_prev[i] = p
			# hot air: it floats up; a little turbulence that grows to the tip
			var wob := Vector2(sin(t * 9.0 + i * 1.7) + 0.6 * sin(t * 15.3 - i), 0) * 22.0 * i
			flame_chain[i] = p + vel + (Vector2(0, -gravity * 1.2) + wob) * h * h
		for _it in range(3):
			for i in range(1, 4):
				var d := flame_chain[i] - flame_chain[i - 1]
				var l := d.length()
				if l > 1e-6:
					flame_chain[i] = flame_chain[i - 1] + d / l * seg
	# the bones turn toward the chain, in the devil's own space (so the facing
	# flip doesn't matter), a little at most
	var acc: float = b.collo.get_relative_transform_to_parent(self).get_rotation()
	for i in range(1, 4):
		var d := to_local(flame_chain[i]) - to_local(flame_chain[i - 1])
		var want := wrapf(atan2(d.y, d.x) + PI / 2 - acc, -PI, PI)
		var bn: Bone2D = b[names[i - 1]]
		var base_rot := bn.rotation if i == 1 else 0.0
		want = base_rot + clampf(wrapf(want - base_rot, -PI, PI), -0.45, 0.45)
		flame_rot[i - 1] = lerp_angle(flame_rot[i - 1], want, min(1.0, dt * 20))
		bn.rotation = flame_rot[i - 1]
		acc += bn.rotation
	var stretch := clampf(1.0 + vy / 2000.0, 0.85, 1.25)
	b.fiamma_1.scale = Vector2(1.0 / sqrt(stretch), stretch)
	if glow:
		glow.modulate.a = 0.75 + 0.25 * sin(t * 13.0) * sin(t * 7.3)
