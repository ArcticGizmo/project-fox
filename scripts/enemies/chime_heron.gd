class_name ChimeHeron
extends Enemy
## Chime Heron: support. A tall brass wading bird whose back resonator hums a
## shield over every other enemy within shield_radius (Enemy.grant_shield:
## they take SHIELDED_DAMAGE_MULTIPLIER damage, a bubble shows it, tethers run
## back to the heron). Fragile itself, so the answer is to kill it first, or to
## stagger/freeze it (no shield while disabled or flinching), or to drag allies
## out of range. Pattern: tend (stay near the allies' centre, keep away from the
## target) -> if cornered, peck_windup -> peck -> recover.

const RESONATOR_COLOR := Color(0.95, 0.8, 0.35)

@export_group("Shield")
@export var shield_radius: float = 7.0
## How long a grant lasts; renewed every frame the heron covers an ally.
@export var shield_hold: float = 0.15
@export_group("Spacing")
@export var keep_away_min: float = 10.0
@export var keep_away_max: float = 16.0
@export_group("Peck")
@export var peck_range: float = 2.6
@export var peck_windup_time: float = 0.5
@export var peck_active_time: float = 0.15
@export var peck_recover_time: float = 0.6
@export var peck_damage: float = 10.0

## Allies covered this frame (tests, debug).
var covered: Array[Enemy] = []
var peck_box: HitBox
var _resonator_mat: StandardMaterial3D
var _tethers: MeshInstance3D
var _tether_mesh: ImmediateMesh


func _init() -> void:
	display_name = "Chime Heron"
	body_shape = BodyShape.CAPSULE
	body_size = Vector3(0.8, 1.6, 0.8)
	color = Color(0.62, 0.72, 0.74)
	max_health = 60.0
	move_speed = 4.2
	acceleration = 18.0
	turn_speed_deg = 260.0
	xp_value = 30
	knockback_resistance = 0.2
	flinch_on_hit = true
	flinch_time = 0.35
	sight_range = 20.0
	notice_time = 1.0


func _setup() -> void:
	var e := extents()
	# Stilt legs, long neck, beak.
	for sx: float in [-1.0, 1.0]:
		add_visual_box(Vector3(0.08, 0.7, 0.08), Vector3(sx * 0.42, 0.35, 0.05), color.darkened(0.4))
	add_visual_box(Vector3(0.14, 0.8, 0.14), Vector3(0, e.y + 0.3, -0.25), color.lightened(0.1))
	add_visual_box(Vector3(0.1, 0.1, 0.55), Vector3(0, e.y + 0.7, -0.55), RESONATOR_COLOR.darkened(0.2))
	# Resonator disc on the back.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.08
	disc.mesh = cyl
	_resonator_mat = StandardMaterial3D.new()
	_resonator_mat.albedo_color = RESONATOR_COLOR
	_resonator_mat.metallic = 0.7
	_resonator_mat.emission_enabled = true
	disc.material_override = _resonator_mat
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(0, e.y * 0.75, e.z * 0.5 + 0.05)
	visual.add_child(disc)
	_tether_mesh = ImmediateMesh.new()
	_tethers = MeshInstance3D.new()
	_tethers.mesh = _tether_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color(SHIELD_COLOR, 0.5)
	_tethers.material_override = tm
	_tethers.top_level = true
	_tethers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tethers)
	peck_box = make_hit_box("PeckHitBox", Vector3(0.6, 0.6, 1.2), Vector3(0, e.y * 0.8, -e.z * 0.5 - 0.6), peck_damage, 6.0, 2.0)


## Whether the resonator is humming (it falls silent while disabled or flinching).
func is_shielding() -> bool:
	return not health.is_dead and not is_disabled() and state != FLINCH


## Allies inside shield_radius, other herons included (two herons cover each other).
func allies_in_range() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in Enemy.in_radius(get_tree(), global_position, shield_radius):
		if e != self:
			out.append(e)
	return out


func _physics_process(delta: float) -> void:
	super(delta)
	covered.clear()
	if is_shielding():
		for e: Enemy in allies_in_range():
			e.grant_shield(shield_hold)
			covered.append(e)
	var hum := 0.6 + 0.4 * sin(age_seconds() * 6.0) if not covered.is_empty() else 0.1
	_resonator_mat.emission = RESONATOR_COLOR * (hum if is_shielding() else 0.0)
	_draw_tethers()


func _draw_tethers() -> void:
	_tether_mesh.clear_surfaces()
	if covered.is_empty():
		return
	_tether_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var from := global_position + Vector3.UP * extents().y * 0.75
	for e: Enemy in covered:
		_tether_mesh.surface_add_vertex(from)
		_tether_mesh.surface_add_vertex(e.get_aim_point())
	_tether_mesh.surface_end()


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"tend")
		&"tend":
			face_toward(target_position(), delta)
			var d := distance_to_target()
			if d <= peck_range:
				enter_state(&"peck_windup")
				return
			desired_velocity = _tend_velocity(d)
		&"peck_windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			telegraph = clampf(state_time / peck_windup_time, 0.0, 1.0)
			visual_pitch = 0.3 * telegraph
			if state_time >= peck_windup_time:
				enter_state(&"peck")
		&"peck":
			visual_pitch = -0.4
			if state_time >= peck_active_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= peck_recover_time:
				enter_state(&"tend")


## Drift toward the allies' centre while holding keep_away from the target.
func _tend_velocity(d: float) -> Vector3:
	var to_target := direction_to_target()
	var v := Vector3.ZERO
	if d < keep_away_min:
		v -= to_target
	elif d > keep_away_max:
		v += to_target
	var allies := allies_in_range()
	var centre := Vector3.ZERO
	var count := 0
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e != self and not e.health.is_dead and e.global_position.distance_to(global_position) < shield_radius * 2.5:
			centre += e.global_position
			count += 1
	if count > 0:
		var to_centre := centre / count - global_position
		to_centre.y = 0.0
		# Stay close enough that the bubble reaches them all.
		if to_centre.length() > shield_radius * 0.5 or allies.size() < count:
			v += to_centre.normalized()
	return v.normalized() * move_speed if v.length_squared() > 0.01 else Vector3.ZERO


func _on_enter_state(new_state: StringName) -> void:
	peck_box.active = new_state == &"peck"


func _state_after_flinch() -> StringName:
	return &"tend"


func _can_flinch() -> bool:
	return state != &"peck"


func _on_death() -> void:
	_tether_mesh.clear_surfaces()


## Preening: the head dips to the resonator now and then.
func _idle_flavour(_delta: float) -> void:
	var t := fmod(state_time, 3.0)
	var dip := smoothstep(1.6, 2.0, t) * (1.0 - smoothstep(2.4, 2.8, t))
	visual_yaw = 0.6 * dip
	visual_pitch = 0.15 * dip
