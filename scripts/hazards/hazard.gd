class_name Hazard
extends Node3D
## Base for traps and environmental hazards. Hazards are neutral: their
## HitBoxes hit the player AND enemies (HIT_MASK), so luring enemies into
## them is a tactic. Kills by hazards credit no weapon. Crates sit on
## ENEMY_HURTBOX too, so keep them out of hazard volumes.
##
## Like Enemy, behaviour is a small state machine run from _tick_state() and
## every transition is logged in `state_log` ("state@seconds") for tests.
## Origin is at ground level; build visuals and hitboxes in _setup().

const HIT_MASK := Layers.PLAYER_HURTBOX | Layers.ENEMY_HURTBOX
## Bodies that can trigger pressure plates and be targeted.
const BODY_MASK := Layers.PLAYER | Layers.ENEMY

var state: StringName = &""
var state_time: float = 0.0
var state_log: PackedStringArray = PackedStringArray()

var _age: float = 0.0


func _ready() -> void:
	add_to_group(&"hazards")
	_setup()


func _physics_process(delta: float) -> void:
	_age += delta
	state_time += delta
	_tick_state(delta)


func enter_state(new_state: StringName) -> void:
	state = new_state
	state_time = 0.0
	state_log.append("%s@%.2f" % [new_state, _age])
	_on_enter_state(new_state)


## A HitBox that hurts players and enemies. Starts inactive.
func make_hit_box(box_name: String, size: Vector3, offset: Vector3, damage: float, knockback: float, knockback_up: float, parent: Node = self) -> HitBox:
	var hb := HitBox.new()
	hb.name = box_name
	hb.collision_mask = HIT_MASK
	hb.damage = damage
	hb.knockback = knockback
	hb.knockback_up = knockback_up
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	hb.add_child(cs)
	parent.add_child(hb)
	return hb


## An Area3D that detects player/enemy bodies (pressure plates, lava contact).
## Gets a (white) debug outline like the hit/hurt boxes.
func make_trigger(trigger_name: String, size: Vector3, offset: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = trigger_name
	area.collision_layer = 0
	area.collision_mask = BODY_MASK
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	area.add_child(cs)
	add_child(area)
	DebugOutline.attach(area)
	return area


## Living, ground-touching creatures (player and enemies) standing in `area`.
static func creatures_in(area: Area3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for body: Node3D in area.get_overlapping_bodies():
		if body.is_in_group(&"player") or body.is_in_group(&"enemies"):
			out.append(body)
	return out


## Enemy hits by hazards can add a status on top of the damage.
static func enemy_hit(hb: HurtBox) -> Enemy:
	var e := Enemy.from_hurt_box(hb)
	return e if e != null and not e.health.is_dead else null


func add_mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func add_box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return add_mesh(box, pos, mat, parent)


static func flat_material(c: Color, roughness: float = 0.7, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	m.metallic = metallic
	return m


## Emission starts at black; drive it with `m.emission = colour * strength`.
static func glow_material(c: Color, transparent: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color.BLACK
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- Virtuals -----------------------------------------------------------------

func _setup() -> void:
	pass


func _tick_state(_delta: float) -> void:
	pass


func _on_enter_state(_new_state: StringName) -> void:
	pass
