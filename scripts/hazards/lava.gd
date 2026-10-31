class_name Lava
extends Hazard
## A pool of lava laid on top of existing ground (it has no collision of its
## own; put a Block under it over a pit). Touching it burns and bounces you
## straight up: the player always gets launched (Player.launch_up, even during
## i-frames, so you can never stand in it) and takes damage when not
## invulnerable. Enemies take the same damage, bounce (scaled by their
## knockback resistance) and are set alight.
## No states: it is always dangerous.

const LAVA_COLOR := Color(1.0, 0.35, 0.05)
const CRUST_COLOR := Color(0.18, 0.08, 0.05)

## Pool footprint, metres (x, z).
@export var size: Vector2 = Vector2(6, 6)
@export var damage: float = 15.0
## Upward speed of the bounce (about 3.3m high at the default gravity).
@export var launch_speed: float = 14.0
## How often an enemy wading through gets burnt again.
@export var tick_interval: float = 0.6
@export var enemy_burn_dps: float = 6.0
@export var enemy_burn_duration: float = 2.0

var hit_box: HitBox
var contact: Area3D

var _material: StandardMaterial3D
var _bubble_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _setup() -> void:
	_rng.randomize()
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.5, 0.08, 0.02)
	_material.emission_enabled = true
	_material.emission = LAVA_COLOR
	_material.emission_energy_multiplier = 1.8
	var noise := FastNoiseLite.new()
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 128
	tex.height = 128
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.2, 0.02, 0.0))
	ramp.set_color(1, Color(1.0, 0.6, 0.15))
	tex.color_ramp = ramp
	_material.emission_texture = tex
	_material.uv1_scale = Vector3(size.x, size.y, 1.0) * 0.25
	var surface := add_box(Vector3(size.x, 0.06, size.y), Vector3(0, 0.03, 0), _material)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Dark crust rim so the edge reads at a glance.
	var crust := flat_material(CRUST_COLOR, 0.95)
	var t := 0.3
	add_box(Vector3(size.x + t * 2.0, 0.1, t), Vector3(0, 0.05, -size.y * 0.5 - t * 0.5), crust)
	add_box(Vector3(size.x + t * 2.0, 0.1, t), Vector3(0, 0.05, size.y * 0.5 + t * 0.5), crust)
	add_box(Vector3(t, 0.1, size.y), Vector3(-size.x * 0.5 - t * 0.5, 0.05, 0), crust)
	add_box(Vector3(t, 0.1, size.y), Vector3(size.x * 0.5 + t * 0.5, 0.05, 0), crust)

	var volume := Vector3(size.x, 0.4, size.y)
	hit_box = make_hit_box("LavaHitBox", volume, Vector3(0, 0.1, 0), damage, 0.0, launch_speed)
	hit_box.repeat_interval = tick_interval
	hit_box.hit_landed.connect(_on_hit_landed)
	hit_box.active = true
	contact = make_trigger("LavaContact", volume, Vector3(0, 0.1, 0))


func _tick_state(delta: float) -> void:
	_material.uv1_offset += Vector3(0.02, 0.012, 0.0) * delta
	_material.emission_energy_multiplier = 1.8 + 0.3 * sin(_age * 2.3)
	for body: Node3D in creatures_in(contact):
		var player := body as Player
		if player != null and player.velocity.y <= 0.0:
			player.launch_up(launch_speed)
			GameFeel.impact(player.global_position + Vector3.UP * 0.3, Color(1.0, 0.45, 0.1, 0.8), 1.6, 0.25)
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = _rng.randf_range(0.15, 0.4) * 36.0 / maxf(size.x * size.y, 1.0)
		var p := Vector3(_rng.randf_range(-0.45, 0.45) * size.x, 0.08, _rng.randf_range(-0.45, 0.45) * size.y)
		GameFeel.impact(to_global(p), Color(1.0, 0.55, 0.15, 0.9), _rng.randf_range(0.4, 0.8), 0.35)


func _on_hit_landed(hb: HurtBox, _info: DamageInfo) -> void:
	var e := enemy_hit(hb)
	if e != null:
		e.apply_burn(enemy_burn_dps, enemy_burn_duration, null)
