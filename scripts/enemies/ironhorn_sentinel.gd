class_name IronhornSentinel
extends Enemy
## Ironhorn Sentinel: a towering armoured brawler with a three-blow combo.
## Pattern: advance (walks; strides when far) -> in reach: jab_windup -> jab ->
## hook_windup -> hook -> slam_windup (rears up, longest glow) -> slam: a blow in front
## plus a Shockwave ring you jump -> winded (long recovery: the opening).
## Every windup stops tracking near its end, so each blow can be sidestepped or dodged.
## Heavy: barely moves when hit, never flinches, shrugs off half of every status.
## The art is a rigged Meshy character driven by FoxModel's baked clips (the swings
## are its punches).

const MODEL: PackedScene = preload("res://assets/enemies/ironhorn_sentinel/Ironhorn_Sentinel.glb")
const MODEL_HEIGHT := 2.2

@export_group("Advance")
@export var combo_range: float = 3.0
## Further than this it strides (runs) instead of walking.
@export var stride_range: float = 9.0
@export var stride_speed: float = 5.0
@export_group("Combo")
## Stop turning this long before each blow.
@export var lock_time: float = 0.15
@export var jab_windup: float = 0.45
@export var hook_windup: float = 0.35
@export var slam_windup: float = 0.8
## How long each blow's hitbox is live.
@export var strike_time: float = 0.25
## Forward lunge during the jab and hook.
@export var lunge_speed: float = 4.0
@export var jab_damage: float = 12.0
@export var hook_damage: float = 14.0
@export var slam_damage: float = 22.0
@export var blow_knockback: float = 7.0
@export var slam_knockback: float = 12.0
@export var shockwave_damage: float = 14.0
@export var shockwave_speed: float = 8.0
@export var shockwave_radius: float = 9.0
@export var winded_time: float = 1.6

var rig: FoxModel
var fist_box: HitBox
var slam_box: HitBox
## The last slam's ring (tests).
var last_shockwave: Shockwave


func _init() -> void:
	display_name = "Ironhorn Sentinel"
	body_shape = BodyShape.CAPSULE
	body_size = Vector3(1.1, MODEL_HEIGHT, 1.1)
	color = Color(0.45, 0.43, 0.45)
	max_health = 220.0
	move_speed = 2.6
	acceleration = 18.0
	turn_speed_deg = 200.0
	xp_value = 50
	knockback_resistance = 0.9
	status_resistance = 0.5
	sight_range = 20.0
	notice_time = 1.5


func _make_model() -> Node3D:
	rig = FoxModel.new(MODEL_HEIGHT, null, MODEL)
	rig.name = "Rig"
	return rig


func _setup() -> void:
	var e := extents()
	fist_box = make_hit_box("FistHitBox", Vector3(1.6, 1.2, 1.6), Vector3(0, e.y * 0.55, -e.z * 0.5 - 0.7), jab_damage, blow_knockback, 3.0)
	fist_box.hit_stop = 0.05
	slam_box = make_hit_box("SlamHitBox", Vector3(2.4, 1.2, 2.2), Vector3(0, 0.6, -e.z * 0.5 - 1.0), slam_damage, slam_knockback, 6.0)
	slam_box.hit_stop = 0.08


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"advance")
		&"advance":
			face_toward(target_position(), delta)
			var d := distance_to_target()
			desired_velocity = forward() * (stride_speed if d > stride_range else move_speed)
			if d <= combo_range:
				enter_state(&"jab_windup")
		&"jab_windup":
			_windup(delta, jab_windup, &"jab")
		&"jab":
			_strike(&"hook_windup")
		&"hook_windup":
			_windup(delta, hook_windup, &"hook")
		&"hook":
			_strike(&"slam_windup")
		&"slam_windup":
			desired_velocity = Vector3.ZERO
			if state_time < slam_windup - lock_time:
				face_toward(target_position(), delta, 360.0)
			var t := clampf(state_time / slam_windup, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3(1.0 - 0.05 * t, 1.0 + 0.1 * t, 1.0 - 0.05 * t)
			if state_time >= slam_windup:
				enter_state(&"slam")
		&"slam":
			desired_velocity = Vector3.ZERO
			if state_time >= strike_time:
				enter_state(&"winded")
		&"winded":
			desired_velocity = Vector3.ZERO
			visual_pitch = -0.2 * (1.0 - state_time / winded_time)
			if state_time >= winded_time:
				enter_state(&"advance")


func _windup(delta: float, length: float, next: StringName) -> void:
	desired_velocity = Vector3.ZERO
	if state_time < length - lock_time:
		face_toward(target_position(), delta, 360.0)
	var t := clampf(state_time / length, 0.0, 1.0)
	telegraph = t
	visual_yaw = 0.25 * t * (1.0 if next == &"jab" else -1.0)
	if state_time >= length:
		enter_state(next)


func _strike(next: StringName) -> void:
	desired_velocity = forward() * lunge_speed
	if state_time >= strike_time:
		enter_state(next)


func _on_enter_state(new_state: StringName) -> void:
	fist_box.active = new_state == &"jab" or new_state == &"hook"
	slam_box.active = new_state == &"slam"
	match new_state:
		&"jab":
			fist_box.damage = jab_damage
			rig.play_action(&"SwingRight", strike_time + 0.1)
			Sfx.play(&"swing", get_aim_point())
		&"hook":
			fist_box.damage = hook_damage
			rig.play_action(&"SwingLeft", strike_time + 0.1)
			Sfx.play(&"swing", get_aim_point())
		&"slam":
			rig.play_action(&"SwingOverhead", strike_time + 0.15)
			_slam()


func _slam() -> void:
	var at := ground_point(global_position + forward() * (extents().z * 0.5 + 1.0))
	last_shockwave = Shockwave.spawn(get_parent(), at)
	last_shockwave.speed = shockwave_speed
	last_shockwave.max_radius = shockwave_radius
	last_shockwave.damage = shockwave_damage
	GameFeel.shake(0.4)
	GameFeel.impact(at + Vector3.UP * 0.2, Color(0.8, 0.75, 0.65), 2.5, 0.3)
	Sfx.play(&"impact_heavy", at)


func _can_flinch() -> bool:
	return false


## Stands guard: a slow look left and right.
func _idle_flavour(_delta: float) -> void:
	var t := fmod(state_time, 6.0)
	visual_yaw = 0.4 * smoothstep(1.0, 2.0, t) * (1.0 - smoothstep(2.6, 3.4, t)) \
			- 0.4 * smoothstep(3.6, 4.4, t) * (1.0 - smoothstep(5.0, 5.8, t))
