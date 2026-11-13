class_name World
extends RefCounted
## Port of the movement part of MegaBlast client/sim/game.lua: walking with
## steps, free jump with air control, short jump, coyote time and jump buffer,
## fall damage, the Lanciarune explosion (crater + push) and the Tonante recoil.
## Same numbers and the same order of operations as the Lua: the trajectories
## must match bit for bit (tools/confronta.py). Robot vs robot is left out:
## the spike has one devil that moves.

# --- the numbers of game.lua / body.lua / config.lua -------------------------
const CELL := 3
const WORLD_W := 640 * CELL
const WORLD_H := 360 * CELL
const MARGIN_CELLS := 60
const MARGIN := MARGIN_CELLS * CELL
const GRID_W := 640 + 2 * MARGIN_CELLS
const DT := 1.0 / 60.0
const REF_H := 28.0
const U := REF_H / 3.612
const GRAVITY := 25 * U
const ROBOT_H := 39.2
const ROBOT_HALF_W := 29.4 / 2
const HURT_R := 20.49
const HURT_Y := 19.6
const HURT_FAT := 0.1 * U
const MAX_CLIMB := 10.5
const JUMP_CUT := 0.45
const COYOTE_TICKS := 6
const JUMP_BUFFER_TICKS := 6
const FALL_SAFE := 40 * U
const FALL_DAMAGE := 1.25 / U
const FALL_DAMAGE_MAX := 75
const KILL_SIDE := 1100
const MISSILE_BLAST := {r = 5 * U, damage_r = 9 * U, damage = 25, damage_min = 12.5, impulse = 10}
const EAGLE := {damage = 38, range = 600, recoil = 300, recoil_ticks = 22}
const DEFAULT_STATS := {walk_speed = 5 * U, jump_height = 5.2 * U, air_speed = 5 * U,
	air_jumps = 0, fall_damage_mul = 1, knockback_mul = 1}
## Spawns of the Cortile (sim/maps.lua)
const SPAWNS := [[210, 450], [1710, 450], [600, 380], [1320, 380]]


class Robot:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var grounded := false
	var knocked := false
	var rising := false
	var facing := 1
	var hp := 100
	var coyote := 0
	var jump_buf := 0
	var jump_held := false
	var air_left := 0
	var fall_top := NAN          # NAN = nil in the Lua
	var recoil := 0              # 0 = nil
	var recoil_vx := 0.0
	var recoil_vy := 0.0
	var walk_speed: float = DEFAULT_STATS.walk_speed
	var air_speed: float = DEFAULT_STATS.air_speed
	var jump_vy: float = sqrt(2 * GRAVITY * DEFAULT_STATS.jump_height)
	var air_jumps: int = DEFAULT_STATS.air_jumps


class Controls:
	var left := false
	var right := false
	var jump := false
	var hold := false


var terrain: Terrain
var gravity := GRAVITY
var robots: Array[Robot] = []
## what happened in the last tick, for the drawing: "jump", "land", "blast", ...
var events: Array[Dictionary] = []


func _init(mask_path: String) -> void:
	terrain = Terrain.from_file(mask_path, GRID_W, WORLD_H / CELL, CELL, MARGIN_CELLS)


func add_robot(spawn: int) -> Robot:
	var rb := Robot.new()
	var sp: Array = SPAWNS[spawn]
	rb.x = sp[0]
	var gy := terrain.ground_below(rb.x, sp[1])
	rb.y = gy if not is_nan(gy) else WORLD_H / 2.0
	rb.facing = 1 if rb.x < WORLD_W / 2.0 else -1
	robots.append(rb)
	return rb


# --- collisions ----------------------------------------------------------------

## Half width of the capsule at the height of the cell row [a, b); -1 = none
static func capsule_half(y: float, a: float, b: float) -> float:
	var r := ROBOT_HALF_W
	var hh := ROBOT_H
	var low := y + r
	var high := y + hh - r
	var p: float = max(a, min(b, low))
	if p < low:
		var d := low - p
		return sqrt(r * r - d * d) if d < r else -1.0
	p = min(b, max(a, high))
	if p > high:
		var d := p - high
		return sqrt(r * r - d * d) if d < r else -1.0
	return r


func terrain_collides(x: float, y: float) -> bool:
	var c := CELL
	var cy0 := floori(y / c)
	var cy1 := floori((y + ROBOT_H - 0.01) / c)
	for cy in range(cy0, cy1 + 1):
		var hw := capsule_half(y, cy * c, cy * c + c)
		if hw >= 0.0 and terrain.any_solid(floori((x - hw) / c), floori((x + hw) / c), cy, cy):
			return true
	return false


func robot_collides(x: float, y: float, _me: Robot) -> bool:
	return terrain_collides(x, y)


func step_x(rb: Robot, dx: float) -> bool:
	for climb in range(0, int(MAX_CLIMB) + 1):
		if not robot_collides(rb.x + dx, rb.y + climb, rb):
			rb.x = rb.x + dx
			rb.y = rb.y + climb
			return true
	return false


func land(rb: Robot) -> void:
	var top := rb.fall_top
	rb.fall_top = NAN
	events.append({type = "land", robot = rb, drop = 0.0 if is_nan(top) else top - rb.y})
	if is_nan(top):
		return
	var drop := top - rb.y - FALL_SAFE
	if drop <= 0:
		return
	var dmg := floori(min(drop * FALL_DAMAGE, FALL_DAMAGE_MAX) * DEFAULT_STATS.fall_damage_mul + 0.5)
	if dmg <= 0:
		return
	hurt(rb, dmg)


func hurt(rb: Robot, amount: int) -> void:
	if amount <= 0:
		return
	rb.hp -= amount
	events.append({type = "hurt", robot = rb, amount = amount})


# --- one tick of a robot (game.update_robot) ---------------------------------

func update_robot(rb: Robot, input: Controls, active: bool) -> void:
	if rb.recoil > 0:
		update_recoil(rb)
		return
	if terrain_collides(rb.x, rb.y):
		rb.y = rb.y + 1
		return

	var move := 1
	var jump := 1
	var dir := (1 if input.right else 0) - (1 if input.left else 0)
	if dir != 0:
		rb.facing = dir

	rb.coyote = max(0, rb.coyote - 1)
	rb.jump_buf = max(0, rb.jump_buf - 1)
	var want_jump: bool = input.jump
	var pressed: bool = want_jump and not rb.jump_held
	rb.jump_held = input.jump
	if want_jump and not rb.grounded:
		if rb.coyote > 0:
			rb.grounded = true
		elif pressed and active and rb.air_left > 0:
			rb.air_left = rb.air_left - 1
			rb.vx = dir * rb.walk_speed * move
			rb.vy = rb.jump_vy * jump
			rb.knocked = false
			rb.rising = true
			rb.fall_top = NAN
			events.append({type = "air_jump", robot = rb})
		else:
			rb.jump_buf = JUMP_BUFFER_TICKS
	if rb.grounded:
		rb.air_left = rb.air_jumps
	if rb.grounded and rb.jump_buf > 0:
		want_jump = true

	if rb.grounded:
		if dir != 0:
			step_x(rb, dir * rb.walk_speed * move * DT)
		if want_jump:
			rb.vx = dir * rb.walk_speed * move
			rb.vy = rb.jump_vy * jump
			rb.grounded = false
			rb.rising = true
			rb.coyote = 0
			rb.jump_buf = 0
			events.append({type = "jump", robot = rb})
		elif not robot_collides(rb.x, rb.y - 1, rb):
			var landed := false
			for d in range(1, int(MAX_CLIMB) + 1):
				if robot_collides(rb.x, rb.y - d - 1, rb):
					rb.y = rb.y - d
					landed = true
					break
			if not landed:
				rb.grounded = false
				rb.vx = 0.0
				rb.vy = 0.0
				rb.coyote = COYOTE_TICKS

	if not rb.grounded:
		if rb.rising and (rb.knocked or rb.vy <= 0):
			rb.rising = false
		if rb.rising and input.hold == false:
			rb.vy = rb.vy * JUMP_CUT
			rb.rising = false
		var chute := 1
		var air := rb.air_speed * move * chute
		if dir != 0:
			rb.vx = dir * air
		if active:
			rb.vx = max(-air, min(air, rb.vx))
		rb.vy = rb.vy - gravity * DT
		if rb.vy < 0 and is_nan(rb.fall_top):
			rb.fall_top = rb.y
		var landed := false
		var mx := rb.vx * DT
		var my := rb.vy * DT
		var steps: float = max(1, ceil(max(absf(mx), absf(my))))
		var sx := mx / steps
		var sy := my / steps
		for _i in range(int(steps)):
			if sx != 0:
				if not robot_collides(rb.x + sx, rb.y, rb):
					rb.x = rb.x + sx
				elif not robot_collides(rb.x + sx, rb.y + 3, rb):
					rb.x = rb.x + sx
					rb.y = rb.y + 3
				else:
					rb.vx = 0.0
					sx = 0.0
			if sy != 0:
				if robot_collides(rb.x, rb.y + sy, rb):
					if sy < 0:
						rb.grounded = true
						rb.knocked = false
						rb.vx = 0.0
						landed = true
					rb.vy = 0.0
					sy = 0.0
				else:
					rb.y = rb.y + sy
		if landed:
			land(rb)
	else:
		rb.fall_top = NAN


## The Tonante: fixed speed, no gravity, slides on the free axis (update_recoil)
func update_recoil(rb: Robot) -> void:
	var mx := rb.recoil_vx * DT
	var my := rb.recoil_vy * DT
	var steps: float = max(1, ceil(max(absf(mx), absf(my))))
	var sx := mx / steps
	var sy := my / steps
	for _i in range(int(steps)):
		if not robot_collides(rb.x + sx, rb.y + sy, rb):
			rb.x = rb.x + sx
			rb.y = rb.y + sy
		elif sx != 0 and step_x(rb, sx):
			pass
		elif sy != 0 and not robot_collides(rb.x, rb.y + sy, rb):
			rb.y = rb.y + sy
		else:
			rb.recoil = 1
			break
	rb.recoil = rb.recoil - 1
	if rb.recoil <= 0:
		rb.vx = 0.0
		rb.vy = 0.0
		rb.recoil = 0


func fire_eagle(rb: Robot, angle: float) -> void:
	rb.facing = -1 if cos(angle) < 0 else 1
	rb.recoil = EAGLE.recoil_ticks
	rb.recoil_vx = -cos(angle) * EAGLE.recoil
	rb.recoil_vy = -sin(angle) * EAGLE.recoil
	rb.grounded = false
	rb.knocked = false
	rb.fall_top = NAN
	events.append({type = "eagle", robot = rb, angle = angle})


# --- the Lanciarune explosion (game.explode, blast, blast_on) -----------------

func explode(x: float, y: float, blast: Dictionary = MISSILE_BLAST) -> Array[int]:
	var rows := terrain.carve(x, y, blast.r)
	events.append({type = "explosion", x = x, y = y, r = blast.r, row_min = rows[0], row_max = rows[1]})
	for rb in robots:
		var hw := HURT_R + HURT_FAT
		var y0 := rb.y + HURT_Y - hw
		var y1 := rb.y + HURT_Y + hw
		var dx: float = max(rb.x - hw, min(rb.x + hw, x)) - x
		var dy: float = max(y0, min(y1, y)) - y
		var d := sqrt(dx * dx + dy * dy)
		if d >= blast.damage_r:
			continue
		var f: float = 1 - d / blast.damage_r
		var dmin: float = blast.damage_min
		var dmg: float = dmin + (blast.damage - dmin) * f
		var imp: float = blast.impulse * DEFAULT_STATS.knockback_mul
		rb.vx = dx * imp * f
		rb.vy = dy * imp * f
		rb.grounded = false
		rb.knocked = true
		hurt(rb, floori(dmg + 0.5))
	return rows
