class_name ClockworkSweeper
extends Hazard
## A brass hub with hazard-striped arms sweeping round at shin height. Jump
## the arms (top at ARM_HEIGHT + ARM_THICKNESS / 2) or stay outside the floor
## disc. Every `surge_interval` it surges to `surge_multiplier` speed for
## `surge_time`, telegraphed by the hub and floor disc glowing and the arms juddering for
## `surge_warning`. Hits fling victims along the sweep, slightly outward.
## States: spin -> surge_warn -> surge -> spin (no surges if surge_interval <= 0).

const SPIN := &"spin"
const SURGE_WARN := &"surge_warn"
const SURGE := &"surge"
const ARM_HEIGHT := 0.45
const ARM_THICKNESS := 0.35
const HUB_RADIUS := 0.6
const WARN_COLOR := Color(1.0, 0.55, 0.1)

## Arm reach from the hub centre.
@export var radius: float = 4.0
@export var arm_count: int = 2
## Positive spins anticlockwise seen from above.
@export var spin_speed_deg: float = 100.0
@export var surge_interval: float = 6.0
@export var surge_warning: float = 1.0
@export var surge_time: float = 2.0
@export var surge_multiplier: float = 2.0
@export var damage: float = 15.0
@export var knockback: float = 10.0
@export var knockback_up: float = 5.0

var hit_boxes: Array[HitBox] = []
## Total rotation in radians (pivot.rotation.y wraps).
var angle: float = 0.0
var pivot: Node3D

var _hub_material: StandardMaterial3D
var _disc_material: StandardMaterial3D


func _setup() -> void:
	var hub := StaticBody3D.new()
	hub.collision_layer = Layers.WORLD
	hub.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = HUB_RADIUS
	shape.height = 1.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.7
	hub.add_child(cs)
	add_child(hub)
	_hub_material = glow_material(Color(0.7, 0.5, 0.2))
	_hub_material.metallic = 0.8
	_hub_material.roughness = 0.35
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = HUB_RADIUS * 0.8
	hub_mesh.bottom_radius = HUB_RADIUS
	hub_mesh.height = 1.4
	add_mesh(hub_mesh, Vector3(0, 0.7, 0), _hub_material)

	# Danger zone on the floor.
	var disc := CylinderMesh.new()
	disc.top_radius = radius + 0.2
	disc.bottom_radius = radius + 0.2
	disc.height = 0.02
	_disc_material = glow_material(Color(0.2, 0.18, 0.16))
	var disc_mesh := add_mesh(disc, Vector3(0, 0.01, 0), _disc_material)
	disc_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	var yellow := flat_material(Color(0.95, 0.75, 0.1), 0.5)
	var black := flat_material(Color(0.1, 0.1, 0.1), 0.5)
	var brass := flat_material(Color(0.8, 0.6, 0.25), 0.35, 0.8)
	var length := radius - HUB_RADIUS
	var stripes := maxi(2, roundi(length / 0.5))
	var cog := CylinderMesh.new()
	cog.top_radius = 0.3
	cog.bottom_radius = 0.3
	cog.height = 0.5
	for i: int in arm_count:
		var arm := Node3D.new()
		arm.rotation.y = TAU * float(i) / arm_count
		pivot.add_child(arm)
		# Arms point along local +X.
		for s: int in stripes:
			var w := length / stripes
			add_box(Vector3(w, ARM_THICKNESS, ARM_THICKNESS), Vector3(HUB_RADIUS + w * (s + 0.5), ARM_HEIGHT, 0),
					yellow if s % 2 == 0 else black, arm)
		var tip := add_mesh(cog, Vector3(radius - 0.15, ARM_HEIGHT, 0), brass, arm)
		tip.rotation.z = PI * 0.5
		var hb := make_hit_box("ArmHitBox%d" % i, Vector3(length, ARM_THICKNESS + 0.15, ARM_THICKNESS + 0.2),
				Vector3(HUB_RADIUS + length * 0.5, ARM_HEIGHT, 0), damage, knockback, knockback_up, arm)
		hb.repeat_interval = 0.4
		hb.damage_modifier = _fling_along_sweep
		hb.active = true
		hit_boxes.append(hb)
	enter_state(SPIN)


func current_speed_deg() -> float:
	return spin_speed_deg * (surge_multiplier if state == SURGE else 1.0)


func _tick_state(delta: float) -> void:
	angle += deg_to_rad(current_speed_deg()) * delta
	pivot.rotation.y = wrapf(angle, -PI, PI)
	match state:
		SPIN:
			_hub_material.emission = Color.BLACK
			_disc_material.emission = Color.BLACK
			if surge_interval > 0.0 and state_time >= surge_interval:
				enter_state(SURGE_WARN)
		SURGE_WARN:
			var t := state_time / surge_warning
			var pulse := WARN_COLOR * t * (0.6 + 0.4 * sin(_age * 30.0))
			_hub_material.emission = pulse * 2.5
			_disc_material.emission = pulse * 0.5
			pivot.position.y = 0.04 * sin(_age * 60.0) * t
			if state_time >= surge_warning:
				enter_state(SURGE)
		SURGE:
			_hub_material.emission = WARN_COLOR * (2.5 + 0.5 * sin(_age * 20.0))
			_disc_material.emission = WARN_COLOR * 0.35
			if state_time >= surge_time:
				enter_state(SPIN)


func _on_enter_state(_new_state: StringName) -> void:
	pivot.position.y = 0.0


## Push along the arm's direction of travel, a little outward.
func _fling_along_sweep(hb: HurtBox, info: DamageInfo) -> void:
	var r := hb.center() - global_position
	r.y = 0.0
	if r.length_squared() < 0.0001:
		return
	var tangent := Vector3(r.z, 0.0, -r.x).normalized() * signf(spin_speed_deg)
	info.source_position = hb.center() - tangent - r.normalized() * 0.4
