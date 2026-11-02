class_name Crate
extends StaticBody3D
## Breakable 1m crate. Any player damage breaks it and grants its contents,
## then it respawns. Yellow = ammo, teal = health.

enum Kind { AMMO, HEALTH }

const SIZE := 1.0

@export var kind: Kind = Kind.AMMO
@export var respawn_time: float = 20.0
@export var ammo_fraction: float = 0.3
@export var heal_amount: float = 30.0
## Glimmer spilled each time it breaks.
@export var glimmer: int = 8

var health: Health
var hurt_box: HurtBox
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _respawn_left: float = -1.0


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.15) if kind == Kind.AMMO else Color(0.2, 0.85, 0.75)
	_mesh.material_override = mat
	_mesh.position.y = SIZE * 0.5
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	_shape.shape = shape
	_shape.position.y = SIZE * 0.5
	add_child(_shape)

	health = Health.new()
	health.max_health = 1.0
	add_child(health)
	health.died.connect(_on_broken)
	hurt_box = HurtBox.new()
	hurt_box.collision_layer = Layers.ENEMY_HURTBOX
	hurt_box.health = health
	var hcs := CollisionShape3D.new()
	var hshape := BoxShape3D.new()
	hshape.size = Vector3.ONE * SIZE * 1.05
	hcs.shape = hshape
	hcs.position.y = SIZE * 0.5
	hurt_box.add_child(hcs)
	add_child(hurt_box)


func _physics_process(delta: float) -> void:
	if _respawn_left < 0.0:
		return
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_respawn_left = -1.0
		_set_present(true)
		health.reset()


func _on_broken(_info: DamageInfo) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		if kind == Kind.AMMO:
			player.refill_ammo_fraction(ammo_fraction)
		else:
			player.health.heal(heal_amount)
	Glimmer.spill(get_parent(), global_position + Vector3.UP * 0.6, glimmer)
	GameFeel.impact(global_position + Vector3.UP * 0.5, (_mesh.material_override as StandardMaterial3D).albedo_color, 2.0, 0.25)
	_set_present(false)
	_respawn_left = respawn_time


func _set_present(present: bool) -> void:
	_mesh.visible = present
	_shape.set_deferred(&"disabled", not present)
	hurt_box.set_deferred(&"monitorable", present)
