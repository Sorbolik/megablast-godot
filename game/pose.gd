class_name Pose
extends RefCounted
## Port of MegaBlast client/battle/pose.lua: the devil's clips (data/clip.json,
## from the animation editor) sampled at any time with the same curves, and
## added into a pose with weights. Same clips, same sampling: what changes in
## the spike is only how the pose is drawn.

const NEUTRAL_ONE := ["schiaccia", "fiamma_schiaccia", "fiamma_scala_x", "fiamma_scala_y",
	"mostra_testa", "mostra_fiamma", "mostra_busto", "mostra_braccio_a", "mostra_braccio_d",
	"mostra_gamba_a", "mostra_gamba_d", "mostra_ala", "mostra_coda", "mostra_arma"]

static var clips: Dictionary = {}

var v: Dictionary = {}
var face_name := ""
var face_weight := 0.0


static func load_clips(path: String) -> void:
	if not clips.is_empty():
		return
	clips = JSON.parse_string(FileAccess.get_file_as_string(path))


static func neutral(c: String) -> float:
	return 1.0 if c in NEUTRAL_ONE else 0.0


func reset() -> void:
	v.clear()
	face_name = ""
	face_weight = 0.0


func get_c(c: String) -> float:
	return v.get(c, neutral(c))


static func inside(clip: Dictionary, t: float) -> float:
	var d: float = clip.duration
	if clip.loop:
		return t - floor(t / d) * d
	return clampf(t, 0.0, d)


static func slope(tr: Array, i: int, n: int, d: float, cycle: bool) -> float:
	var ta: float
	var va: float
	var tb: float
	var vb: float
	if i > 0:
		ta = tr[3 * i - 3]
		va = tr[3 * i - 2]
	elif cycle and n > 1:
		ta = tr[3 * n - 3] - d
		va = tr[3 * n - 2]
	else:
		return 0.0
	if i < n - 1:
		tb = tr[3 * i + 3]
		vb = tr[3 * i + 4]
	elif cycle and n > 1:
		tb = tr[0] + d
		vb = tr[1]
	else:
		return 0.0
	if tb - ta < 1e-9:
		return 0.0
	return (vb - va) / (tb - ta)


## The value of a track at time t (inside the clip). Keys: t, v, curve (0-based here)
static func value(tr: Array, t: float, d: float, cycle: bool) -> float:
	var n := tr.size() / 3
	if n == 1:
		return tr[1]
	var i := -1
	for k in range(n):
		if tr[3 * k] <= t:
			i = k
		else:
			break
	var t0: float
	var t1: float
	var j: int
	if i < 0:
		if not cycle:
			return tr[1]
		i = n - 1
		j = 0
		t0 = tr[3 * n - 3] - d
		t1 = tr[0]
	elif i == n - 1:
		if not cycle:
			return tr[3 * n - 2]
		j = 0
		t0 = tr[3 * i]
		t1 = tr[0] + d
	else:
		j = i + 1
		t0 = tr[3 * i]
		t1 = tr[3 * j]
	var v0: float = tr[3 * i + 1]
	var v1: float = tr[3 * j + 1]
	var curve: int = int(tr[3 * i + 2])
	var h := t1 - t0
	if curve == 2 or h < 1e-9:
		return v0
	var u := (t - t0) / h
	if curve == 1:
		return v0 + (v1 - v0) * u
	var m0 := slope(tr, i, n, d, cycle) * h
	var m1 := slope(tr, j, n, d, cycle) * h
	var u2 := u * u
	var u3 := u2 * u
	return (2 * u3 - 3 * u2 + 1) * v0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * v1 + (u3 - u2) * m1


func add(clip_name: String, t: float, weight: float) -> void:
	if weight <= 0 or not clips.has(clip_name):
		return
	var clip: Dictionary = clips[clip_name]
	t = inside(clip, t)
	var d: float = clip.duration
	var cycle: bool = clip.loop
	for c in clip.tracks:
		v[c] = get_c(c) + weight * (value(clip.tracks[c], t, d, cycle) - neutral(c))
	if clip.has("face") and weight > face_weight:
		var visage: Array = clip.face
		var f: String = visage[visage.size() - 1] if cycle else visage[1]
		for k in range(0, visage.size(), 2):
			if visage[k] <= t:
				f = visage[k + 1]
			else:
				break
		face_name = f
		face_weight = weight
