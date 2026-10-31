class_name LightningBarrier
extends Hazard
## Two galvanic pylons that arc lightning between them on a cycle. The
## barrier runs along local X (pylons at +/- span/2); cross it while it is off.
##
## Telegraph: a glass tube on each pylon fills with light over `charge_time`
## (`charge` 0..1), the top orbs brighten, and for the last stretch weak arcs
## sputter across the gap. The floor strip marks the line even while off.
## Hits push straight back out the side you came from; enemies are staggered.
## States: off -> charging -> on -> off.

const OFF := &"off"
const CHARGING := &"charging"
const ON := &"on"
const ARC_COLOR := Color(0.55, 0.85, 1.0)
const BOLT_COUNT := 3
const BOLT_SEGMENTS := 8
const PYLON_WIDTH := 0.6
## Arcs start sputtering at this fraction of the charge.
const SPUTTER_FROM := 0.6
const DRAIN_TIME := 0.4

## Gap between the pylon centres.
@export var span: float = 6.0
@export var height: float = 2.4
@export var off_time: float = 2.0
@export var charge_time: float = 1.2
@export var on_time: float = 1.5
## Delays the first charge so neighbouring barriers can alternate.
@export var phase_offset: float = 0.0
@export var damage: float = 20.0
@export var knockback: float = 10.0
@export var knockback_up: float = 4.0
@export var enemy_stagger: float = 0.8

var hit_box: HitBox
## Charge indicator level, 0..1 (full while on, drains when it switches off).
var charge: float = 0.0

var _fill: Array[MeshInstance3D] = []
var _fill_material: StandardMaterial3D
var _orb_material: StandardMaterial3D
var _strip_material: StandardMaterial3D
var _bolt_material: StandardMaterial3D
var _bolts: Array[Array] = []
var _bolt_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _setup() -> void:
	var half := span * 0.5
	var pylon_height := height + 0.5
	_orb_material = glow_material(ARC_COLOR)
	_fill_material = glow_material(ARC_COLOR)
	var glass := flat_material(Color(0.8, 0.95, 1.0, 0.25), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var orb := SphereMesh.new()
	orb.radius = 0.3
	orb.height = 0.6
	for side: float in [-1.0, 1.0]:
		var pylon := Block.new()
		pylon.size = Vector3(PYLON_WIDTH, pylon_height, PYLON_WIDTH)
		pylon.color = Color(0.45, 0.35, 0.2)
		pylon.position = Vector3(side * half, pylon_height * 0.5, 0)
		add_child(pylon)
		add_mesh(orb, Vector3(side * half, pylon_height + 0.25, 0), _orb_material)
		# Charge tube on the inner face of the pylon.
		var tube_x := side * (half - PYLON_WIDTH * 0.5 - 0.1)
		add_box(Vector3(0.18, height, 0.18), Vector3(tube_x, height * 0.5 + 0.1, 0), glass)
		var fill := add_box(Vector3(0.12, 1.0, 0.12), Vector3(tube_x, 0.1, 0), _fill_material)
		_fill.append(fill)

	_strip_material = glow_material(Color(0.15, 0.18, 0.22))
	add_box(Vector3(span, 0.04, 0.25), Vector3(0, 0.02, 0), _strip_material)

	_bolt_material = glow_material(Color(ARC_COLOR, 0.9), true)
	_bolt_material.emission = ARC_COLOR * 3.0
	var segment := BoxMesh.new()
	segment.size = Vector3(0.07, 0.07, 1.0)
	for _b: int in BOLT_COUNT:
		var bolt: Array[MeshInstance3D] = []
		for _s: int in BOLT_SEGMENTS:
			var mi := add_mesh(segment, Vector3.ZERO, _bolt_material)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			bolt.append(mi)
		_bolts.append(bolt)

	hit_box = make_hit_box("ArcHitBox", Vector3(span - PYLON_WIDTH, height, 0.5),
			Vector3(0, height * 0.5, 0), damage, knockback, knockback_up)
	hit_box.repeat_interval = 0.5
	hit_box.damage_modifier = _push_out_sideways
	hit_box.hit_landed.connect(_on_hit_landed)
	enter_state(OFF)
	state_time = -phase_offset
	_update_charge_visuals()


func _tick_state(delta: float) -> void:
	match state:
		OFF:
			charge = maxf(0.0, charge - delta / DRAIN_TIME)
			if state_time >= off_time:
				enter_state(CHARGING)
		CHARGING:
			charge = clampf(state_time / charge_time, 0.0, 1.0)
			if state_time >= charge_time:
				enter_state(ON)
		ON:
			charge = 1.0
			if state_time >= on_time:
				enter_state(OFF)
	_update_charge_visuals()
	_update_bolts(delta)


func _on_enter_state(new_state: StringName) -> void:
	hit_box.active = new_state == ON
	if new_state == ON:
		_bolt_timer = 0.0
		GameFeel.impact(global_position + Vector3.UP * height * 0.5, Color(ARC_COLOR, 0.6), span * 0.6, 0.2)


func _update_charge_visuals() -> void:
	for fill: MeshInstance3D in _fill:
		var h := maxf(0.001, charge * height)
		fill.scale.y = h
		fill.position.y = 0.1 + h * 0.5
	var flicker := 1.0
	if state == ON:
		flicker = 0.8 + 0.4 * absf(sin(_age * 37.0))
	elif state == CHARGING:
		flicker = 0.85 + 0.15 * sin(_age * lerpf(6.0, 30.0, charge))
	_fill_material.emission = ARC_COLOR * (0.5 + 2.5 * charge) * flicker * (1.0 if charge > 0.0 else 0.0)
	_orb_material.emission = ARC_COLOR * (0.15 + 2.5 * charge * charge) * flicker
	_strip_material.emission = ARC_COLOR * (0.08 + 0.6 * charge * charge) * flicker


## Full bolts while on; faint, intermittent ones near the end of the charge.
func _update_bolts(delta: float) -> void:
	var sputter := state == CHARGING and charge >= SPUTTER_FROM
	if state != ON and not sputter:
		for bolt: Array in _bolts:
			for mi: MeshInstance3D in bolt:
				mi.visible = false
		return
	_bolt_timer -= delta
	if _bolt_timer > 0.0:
		return
	_bolt_timer = 0.05
	var strength := 1.0
	if sputter:
		strength = inverse_lerp(SPUTTER_FROM, 1.0, charge)
	_bolt_material.albedo_color.a = 0.9 if state == ON else lerpf(0.15, 0.5, strength)
	var inner := span * 0.5 - PYLON_WIDTH * 0.5 - 0.1
	for b: int in _bolts.size():
		var bolt: Array = _bolts[b]
		var lit := state == ON or _rng.randf() < 0.25 + 0.5 * strength
		var y := height * (float(b) + 0.5) / BOLT_COUNT
		var prev := Vector3(-inner, y + _rng.randf_range(-0.2, 0.2), 0)
		for s: int in BOLT_SEGMENTS:
			var mi := bolt[s] as MeshInstance3D
			mi.visible = lit
			if not lit:
				continue
			var t := float(s + 1) / BOLT_SEGMENTS
			var jitter := 0.0 if s == BOLT_SEGMENTS - 1 else 0.3
			var next := Vector3(lerpf(-inner, inner, t), y + _rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter) * 0.6)
			var d := next - prev
			mi.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length())), (prev + next) * 0.5)
			prev = next


## Knock victims straight back out of the barrier, not away from its centre.
func _push_out_sideways(hb: HurtBox, info: DamageInfo) -> void:
	var local := to_local(hb.center())
	var side := 1.0 if local.z >= 0.0 else -1.0
	info.source_position = to_global(Vector3(local.x, local.y, -side))


func _on_hit_landed(hb: HurtBox, _info: DamageInfo) -> void:
	var e := enemy_hit(hb)
	if e != null:
		e.stagger(enemy_stagger)
	GameFeel.impact(hb.center(), Color(ARC_COLOR, 0.8), 1.2, 0.15)
