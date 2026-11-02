class_name CoalBeetle
extends Enemy
## Coal Beetle: a slow, heavy area-denier with a furnace for a gut and chimneys on its
## shell. Pattern: crawl toward the target, dropping a patch of live coals (CoalEmber)
## every ember_drop_interval while it moves -> in range: stoke (glows, swells) -> belch:
## lobs belch_count coals from its chimneys at and around where the target is heading;
## each leaves embers where it lands -> recover. Up close it scorches instead:
## scorch_windup (glows, squats) -> a burst of heat around itself -> recover.
## Counterplay: fire does nothing to it (no burn), but frost quenches it: while chill is
## at least quench_chill it drops no embers, and chilling it mid-stoke douses the
## furnace: quenched (steam, no belch, exposed for expose_time).

const MODEL: PackedScene = preload("res://assets/enemies/coal_beetle/Coal_Beetle.glb")
const COAL_COLOR := Color(1.0, 0.42, 0.1)
const STEAM_COLOR := Color(0.92, 0.95, 1.0)

@export_group("Crawl")
## Stops closing in at this distance (it would rather belch than bite).
@export var hold_distance: float = 6.0
@export var ember_drop_interval: float = 1.1
@export var ember_radius: float = 1.0
@export var ember_damage: float = 4.0
@export var ember_lifetime: float = 5.0
@export_group("Belch")
@export var belch_range: float = 14.0
@export var belch_cooldown: float = 2.6
@export var stoke_time: float = 0.9
@export var belch_count: int = 3
## Distance of the extra coals from the centre one.
@export var belch_spread: float = 2.6
@export var lob_flight_time: float = 1.2
@export var lob_damage: float = 14.0
@export var lob_radius: float = 1.6
## 0 = aim at the target's position, 1 = full lead on its velocity.
@export var lead_factor: float = 0.5
@export_group("Scorch")
@export var scorch_range: float = 3.2
@export var scorch_windup_time: float = 0.6
@export var scorch_radius: float = 3.4
@export var scorch_damage: float = 16.0
@export var scorch_knockback: float = 12.0
@export var recover_time: float = 0.7
@export_group("Quench")
@export_range(0.0, 1.0) var quench_chill: float = 0.4
@export var quench_time: float = 1.6
@export var expose_time: float = 4.0

## Coal patches dropped while crawling, and coals belched (tests, debugging).
var embers_dropped: int = 0
var coals_belched: int = 0
var _ember_timer: float = 0.0


func _init() -> void:
	display_name = "Coal Beetle"
	body_shape = BodyShape.BOX
	body_size = Vector3(1.7, 1.2, 2.0)
	color = Color(0.25, 0.2, 0.2)
	max_health = 110.0
	move_speed = 2.6
	acceleration = 12.0
	turn_speed_deg = 150.0
	xp_value = 30
	knockback_resistance = 0.6
	# Dim eyes in a hot shell: short sight, good ears.
	sight_range = 15.0
	hearing_range = 9.0


func _make_model() -> Node3D:
	return fit_model(MODEL, body_size)


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"crawl")
		&"crawl":
			face_toward(target_position(), delta)
			var d := distance_to_target()
			desired_velocity = forward() * move_speed if d > hold_distance else Vector3.ZERO
			_drop_embers(delta)
			if d <= scorch_range and state_time >= 0.4:
				enter_state(&"scorch_windup")
			elif state_time >= belch_cooldown and d <= belch_range:
				enter_state(&"stoke")
		&"stoke":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			if is_quenched():
				enter_state(&"quenched")
				return
			var t := clampf(state_time / stoke_time, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3(1.0 + 0.12 * t, 1.0 + 0.22 * t, 1.0 + 0.08 * t)
			if state_time >= stoke_time:
				_belch()
				enter_state(&"recover")
		&"scorch_windup":
			desired_velocity = Vector3.ZERO
			var t := clampf(state_time / scorch_windup_time, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3(1.0 + 0.15 * t, 1.0 - 0.2 * t, 1.0 + 0.15 * t)
			if state_time >= scorch_windup_time:
				_scorch()
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= recover_time:
				enter_state(&"crawl")
		&"quenched":
			desired_velocity = Vector3.ZERO
			visual_scale = Vector3(1.0, 0.92, 1.0)
			if state_time >= quench_time:
				enter_state(&"crawl")


func _on_enter_state(new_state: StringName) -> void:
	if new_state == &"quenched":
		expose(expose_time)
		Sfx.play(&"hiss", get_aim_point())
		GameFeel.impact(global_position + Vector3.UP * (extents().y + 0.3), STEAM_COLOR, 2.2, 0.5)


## Chilled enough that the furnace is out (no embers, a stoke fizzles).
func is_quenched() -> bool:
	return chill >= quench_chill or is_frozen()


func _drop_embers(delta: float) -> void:
	if desired_velocity.length() < 0.1 or is_quenched():
		return
	_ember_timer += delta
	if _ember_timer < ember_drop_interval:
		return
	_ember_timer = 0.0
	embers_dropped += 1
	var behind := global_position - forward() * (extents().z * 0.5 + ember_radius * 0.6)
	CoalEmber.spawn(get_parent(), ground_point(behind), ember_radius, ember_damage, ember_lifetime)


## Where the belched coals come down: the lead point, then the others spread round it.
func belch_points() -> Array[Vector3]:
	var center := lead_target(lob_flight_time * lead_factor)
	var points: Array[Vector3] = [center]
	var side := direction_to_target().cross(Vector3.UP)
	for i: int in belch_count - 1:
		var a := TAU * float(i) / float(maxi(1, belch_count - 1))
		points.append(center + side.rotated(Vector3.UP, a) * belch_spread)
	return points


func _belch() -> void:
	var chimney := global_position + Vector3.UP * (extents().y + 0.2)
	for p: Vector3 in belch_points():
		var lob := LobProjectile.launch(self, chimney, ground_point(p), lob_flight_time, lob_damage, lob_radius, COAL_COLOR)
		lob.landed.connect(_on_coal_landed)
		coals_belched += 1
	visual_scale = Vector3(0.9, 0.85, 0.9)
	GameFeel.impact(chimney, Color(0.3, 0.28, 0.28), 1.4, 0.4)


func _on_coal_landed(lob: LobProjectile, at: Vector3) -> void:
	if lob.reflected or not is_inside_tree():
		return
	CoalEmber.spawn(get_parent(), at, ember_radius, ember_damage, ember_lifetime)


func _scorch() -> void:
	var center := global_position + Vector3.UP * extents().y * 0.5
	Explosion.detonate(self, center, scorch_radius, Layers.PLAYER_HURTBOX, func() -> DamageInfo:
		var info := DamageInfo.create(scorch_damage, global_position, scorch_knockback)
		info.knockback_up = 4.0
		return info)
	GameFeel.impact(center, COAL_COLOR, scorch_radius * 2.0, 0.3)
	GameFeel.shake(0.25)
	Sfx.play(&"explosion", center)


## Made of coal: fire does nothing.
func apply_burn(_dps: float, _duration: float, _source: Weapon) -> void:
	pass


func _can_flinch() -> bool:
	return false


## Breathing furnace: a slow swell, the shell lifting a touch on each breath.
func _idle_flavour(_delta: float) -> void:
	var p := 0.5 - 0.5 * cos(state_time * TAU / 2.4)
	visual_scale = Vector3(1.0 + 0.03 * p, 1.0 + 0.05 * p, 1.0)
