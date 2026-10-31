class_name FireTrap
extends Hazard
## Pressure plate that erupts in a column of flame. Stepping on it (player or
## enemy) clicks it down and arms it; after `arm_time` it burns for
## `burn_time`, then cools down. Anyone still on the plate re-arms it.
##
## Telegraph: the plate sinks, its grate glows hotter and it puffs smoke
## (turning to embers near the end) while armed.
## States: idle -> armed -> burning -> cooldown -> idle.

const IDLE := &"idle"
const ARMED := &"armed"
const BURNING := &"burning"
const COOLDOWN := &"cooldown"
const GRATE_COLOR := Color(1.0, 0.4, 0.05)
const FLAME_COLOR := Color(1.0, 0.45, 0.08, 0.55)
const CORE_COLOR := Color(1.0, 0.85, 0.3, 0.8)
const SINK := 0.03

## Square plate, metres per side.
@export var plate_size: float = 2.0
@export var arm_time: float = 1.5
@export var burn_time: float = 1.5
@export var cooldown_time: float = 1.5
@export var flame_height: float = 3.0
## Damage per tick while inside the flame (the player's hurt i-frames limit how
## often it actually lands on them).
@export var damage: float = 10.0
@export var tick_interval: float = 0.25
@export var knockback: float = 5.0
@export var knockback_up: float = 5.0
## Enemies caught in the flame keep burning afterwards.
@export var enemy_burn_dps: float = 8.0
@export var enemy_burn_duration: float = 3.0

var hit_box: HitBox
var trigger: Area3D

var _plate: Node3D
var _grate_material: StandardMaterial3D
var _flame: Node3D
var _puff_timer: float = 0.0


func _setup() -> void:
	_plate = Node3D.new()
	add_child(_plate)
	add_box(Vector3(plate_size, 0.08, plate_size), Vector3(0, 0.04, 0), flat_material(Color(0.22, 0.2, 0.2), 0.5, 0.6), _plate)
	_grate_material = glow_material(Color(0.35, 0.12, 0.05))
	for i: int in 3:
		var z := (float(i) - 1.0) * plate_size * 0.28
		add_box(Vector3(plate_size * 0.75, 0.02, plate_size * 0.08), Vector3(0, 0.085, z), _grate_material, _plate)
	# Brass corner studs so it reads as a mechanism, not a floor tile.
	var brass := flat_material(Color(0.8, 0.6, 0.25), 0.4, 0.8)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c := corner * plate_size * 0.42
		add_box(Vector3(0.18, 0.12, 0.18), Vector3(c.x, 0.06, c.y), brass, _plate)

	_flame = Node3D.new()
	_flame.visible = false
	add_child(_flame)
	_add_flame_cylinder(plate_size * 0.45, plate_size * 0.2, flame_height, FLAME_COLOR)
	_add_flame_cylinder(plate_size * 0.25, plate_size * 0.05, flame_height * 0.75, CORE_COLOR)

	hit_box = make_hit_box("FlameHitBox", Vector3(plate_size * 0.9, flame_height, plate_size * 0.9),
			Vector3(0, flame_height * 0.5, 0), damage, knockback, knockback_up)
	hit_box.repeat_interval = tick_interval
	hit_box.hit_landed.connect(_on_hit_landed)
	trigger = make_trigger("PlateTrigger", Vector3(plate_size, 0.5, plate_size), Vector3(0, 0.25, 0))
	enter_state(IDLE)


func _add_flame_cylinder(bottom_radius: float, top_radius: float, height: float, c: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = bottom_radius
	cyl.top_radius = top_radius
	cyl.height = height
	var mat := glow_material(c, true)
	mat.emission = Color(c.r, c.g, c.b) * 2.0
	var mi := add_mesh(cyl, Vector3(0, height * 0.5, 0), mat, _flame)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Arms the trap as if someone stepped on it (no effect unless idle).
func trigger_now() -> void:
	if state == IDLE:
		enter_state(ARMED)


func _tick_state(delta: float) -> void:
	match state:
		IDLE:
			if not creatures_in(trigger).is_empty():
				enter_state(ARMED)
		ARMED:
			var t := clampf(state_time / arm_time, 0.0, 1.0)
			# Hotter and faster flicker as it builds.
			var flicker := 0.75 + 0.25 * sin(_age * lerpf(8.0, 40.0, t))
			_grate_material.emission = GRATE_COLOR * lerpf(0.4, 3.0, t * t) * flicker
			_puff_timer -= delta
			if _puff_timer <= 0.0:
				_puff_timer = lerpf(0.3, 0.1, t)
				var smoke := Color(0.35, 0.33, 0.32, 0.5).lerp(Color(1.0, 0.5, 0.1, 0.7), t)
				GameFeel.impact(global_position + Vector3.UP * 0.3, smoke, plate_size * lerpf(0.4, 0.8, t), 0.3)
			if state_time >= arm_time:
				enter_state(BURNING)
		BURNING:
			var s := 1.0 + 0.12 * sin(_age * 31.0) + 0.06 * sin(_age * 53.0)
			_flame.scale = Vector3(1.0 + 0.08 * sin(_age * 23.0), s, 1.0 + 0.08 * cos(_age * 19.0))
			if state_time >= burn_time:
				enter_state(COOLDOWN)
		COOLDOWN:
			_grate_material.emission = GRATE_COLOR * 1.5 * (1.0 - state_time / cooldown_time)
			if state_time >= cooldown_time:
				enter_state(IDLE)


func _on_enter_state(new_state: StringName) -> void:
	_plate.position.y = -SINK if new_state == ARMED or new_state == BURNING else 0.0
	_flame.visible = new_state == BURNING
	hit_box.active = new_state == BURNING
	match new_state:
		IDLE:
			_grate_material.emission = Color.BLACK
		ARMED:
			_puff_timer = 0.0
		BURNING:
			_grate_material.emission = GRATE_COLOR * 3.0
			GameFeel.impact(global_position + Vector3.UP * 0.5, Color(1.0, 0.6, 0.15, 0.8), plate_size * 1.6, 0.25)


func _on_hit_landed(hb: HurtBox, _info: DamageInfo) -> void:
	var e := enemy_hit(hb)
	if e != null:
		e.apply_burn(enemy_burn_dps, enemy_burn_duration, null)
