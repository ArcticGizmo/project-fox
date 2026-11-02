class_name RaccoonRogue
extends Enemy
## Raccoon Rogue: a glimmer thief.
## Pattern: dart in, weaving side to side -> snatch_windup (crouches and glows; stops
## turning near the end so a sidestep or dodge works) -> snatch: a quick dash with a
## swipe. A swipe that lands on someone carrying glimmer steals up to steal_amount and
## the rogue flees: runs straight away from the target, shedding drop_per_hit of its loot
## every time it is hit. Killed, it spills the rest along with its own glimmer. After
## fleeing for escape_time while at least escape_distance away it vanishes in a puff of
## smoke, loot and all. An empty-handed swipe (a miss, or nothing to steal) recovers and
## darts in again.
## The art is a rigged Meshy character driven by FoxModel's baked clips.

const MODEL: PackedScene = preload("res://assets/enemies/raccoon_rogue/racoon_rouge.glb")
const MODEL_HEIGHT := 1.35
const SMOKE_COLOR := Color(0.45, 0.42, 0.48)

@export_group("Dart")
@export var snatch_trigger_range: float = 3.6
@export var min_dart_time: float = 0.8
## Side-to-side weave while darting in: amplitude (fraction of speed) and frequency.
@export var weave_amount: float = 0.7
@export var weave_frequency: float = 2.2
@export_group("Snatch")
@export var snatch_windup: float = 0.45
## Stop turning this long before the dash.
@export var snatch_lock_time: float = 0.15
@export var snatch_speed: float = 15.0
@export var snatch_time: float = 0.28
@export var snatch_damage: float = 8.0
@export var snatch_knockback: float = 4.0
@export var steal_amount: int = 40
@export var recover_time: float = 0.6
@export_group("Flee")
@export var flee_speed: float = 7.5
@export var drop_per_hit: int = 10
@export var escape_time: float = 5.0
@export var escape_distance: float = 14.0

## Glimmer stolen and still carried.
var loot: int = 0
var escaped: bool = false
var rig: FoxModel
var swipe_box: HitBox
var _dash_dir: Vector3 = Vector3.FORWARD
var _flee_dir: Vector3 = Vector3.BACK


func _init() -> void:
	display_name = "Raccoon Rogue"
	body_shape = BodyShape.CAPSULE
	body_size = Vector3(0.7, MODEL_HEIGHT, 0.7)
	color = Color(0.45, 0.4, 0.38)
	max_health = 45.0
	move_speed = 6.0
	acceleration = 40.0
	turn_speed_deg = 540.0
	xp_value = 20
	flinch_on_hit = true
	flinch_time = 0.2
	# Sharp-eyed; it means to be seen only when it wants to be.
	sight_range = 20.0
	notice_time = 0.9


func _make_model() -> Node3D:
	rig = FoxModel.new(MODEL_HEIGHT, null, MODEL)
	rig.name = "Rig"
	return rig


func _setup() -> void:
	var e := extents()
	swipe_box = make_hit_box("SwipeHitBox", Vector3(1.0, e.y * 0.7, 1.0), Vector3(0, e.y * 0.5, -e.z * 0.5 - 0.35), snatch_damage, snatch_knockback, 2.0)
	swipe_box.hit_landed.connect(_on_swipe_hit)
	health.damaged.connect(_on_hurt)


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"dart")
		&"dart":
			face_toward(target_position(), delta)
			var to := direction_to_target()
			var weave := to.cross(Vector3.UP) * sin(state_time * TAU * weave_frequency * 0.5) * weave_amount
			desired_velocity = (to + weave).normalized() * move_speed
			if state_time >= min_dart_time and distance_to_target() <= snatch_trigger_range:
				enter_state(&"snatch_windup")
		&"snatch_windup":
			desired_velocity = Vector3.ZERO
			if state_time < snatch_windup - snatch_lock_time:
				face_toward(target_position(), delta, 720.0)
			var t := clampf(state_time / snatch_windup, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3(1.0 + 0.1 * t, 1.0 - 0.18 * t, 1.0 + 0.1 * t)
			if state_time >= snatch_windup:
				enter_state(&"snatch")
		&"snatch":
			snap_velocity(_dash_dir * snatch_speed)
			if state_time >= snatch_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if has_target():
				face_toward(target_position(), delta)
			if state_time >= recover_time:
				enter_state(&"dart")
		&"flee":
			if has_target():
				var away := global_position - target_position()
				away.y = 0.0
				if away.length() > 0.1:
					_flee_dir = away.normalized()
			face_toward(global_position + _flee_dir, delta, 720.0)
			desired_velocity = _flee_dir * flee_speed
			var far := not has_target() or distance_to_target() >= escape_distance
			if state_time >= escape_time and far:
				_escape()


func _on_enter_state(new_state: StringName) -> void:
	swipe_box.active = new_state == &"snatch"
	if new_state == &"snatch":
		_dash_dir = forward()
		rig.play_action(&"SwingRight", snatch_time + 0.1)
		Sfx.play(&"swing", get_aim_point())
	elif new_state == &"recover":
		snap_velocity(Vector3.ZERO)


func _on_swipe_hit(hb: HurtBox, _info: DamageInfo) -> void:
	var victim := hb.get_parent()
	if state != &"snatch" or victim == null or not victim.has_method(&"spend_glimmer"):
		return
	var amount := mini(steal_amount, int(victim.get(&"glimmer")))
	if amount <= 0 or not bool(victim.call(&"spend_glimmer", amount)):
		return
	loot += amount
	Sfx.play(&"snatch", get_aim_point())
	GameFeel.impact(get_aim_point(), Color(1.0, 0.85, 0.4), 0.9, 0.2)
	snap_velocity(Vector3.ZERO)
	enter_state(&"flee")


func _on_hurt(_amount: float, _info: DamageInfo) -> void:
	if health.is_dead:
		return
	rig.play_action(&"Hurt")
	if loot > 0:
		var n := mini(drop_per_hit, loot)
		loot -= n
		Glimmer.spill(get_parent(), get_aim_point(), n, maxi(1, random_seed + loot + 1))


## Gone with the loot: no death, no glimmer.
func _escape() -> void:
	escaped = true
	Sfx.play(&"poof", get_aim_point())
	GameFeel.impact(get_aim_point(), SMOKE_COLOR, 2.4, 0.5)
	remove_from_group(&"aim_targets")
	remove_from_group(&"enemies")
	queue_free()


func glimmer_drop() -> int:
	return super() + loot


## A thief on the run ignores its leash and doesn't forget who it robbed.
func _should_give_up(delta: float) -> bool:
	return false if state == &"flee" else super(delta)


## Only the wind-up flinches; a fleeing rogue keeps running.
func _can_flinch() -> bool:
	return state == &"snatch_windup" or state == &"dart"


func _state_after_flinch() -> StringName:
	return &"flee" if loot > 0 else &"dart"


## Glances about, shifting its weight; the clip does most of the work.
func _idle_flavour(_delta: float) -> void:
	visual_yaw = 0.35 * sin(state_time * 0.9) * smoothstep(0.0, 1.0, fmod(state_time, 4.0) - 1.0)
