@tool
class_name GlimmerJar
extends SavedPickup
## A brass-capped glass jar of glimmer. Any player hit breaks it (staff, shots,
## blasts) and spills `value` glimmer. Saved (SavedPickup): broken once per save.

const GLASS := Color(0.55, 0.95, 0.9, 0.45)
const BRASS := Color(0.8, 0.6, 0.28)
const HEIGHT := 0.7

@export var value: int = 60

var health: Health
var hurt_box: HurtBox


func _ready() -> void:
	var body := MeshInstance3D.new()
	var glass := CylinderMesh.new()
	glass.top_radius = 0.22
	glass.bottom_radius = 0.26
	glass.height = HEIGHT * 0.8
	body.mesh = glass
	body.position.y = HEIGHT * 0.4
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = GLASS
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.emission_enabled = true
	glass_mat.emission = Glimmer.LOOKS[1][1] as Color
	glass_mat.emission_energy_multiplier = 0.8
	glass_mat.roughness = 0.1
	body.material_override = glass_mat
	add_child(body)
	var cap := MeshInstance3D.new()
	var lid := CylinderMesh.new()
	lid.top_radius = 0.16
	lid.bottom_radius = 0.24
	lid.height = HEIGHT * 0.2
	cap.mesh = lid
	cap.position.y = HEIGHT * 0.9
	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.7
	brass.roughness = 0.35
	cap.material_override = brass
	add_child(cap)
	if Engine.is_editor_hint():
		return
	health = Health.new()
	health.max_health = 1.0
	add_child(health)
	health.died.connect(_on_broken)
	hurt_box = HurtBox.new()
	hurt_box.collision_layer = Layers.ENEMY_HURTBOX
	hurt_box.health = health
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = HEIGHT
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	hurt_box.add_child(cs)
	add_child(hurt_box)


func kind() -> StringName:
	return &"jar"


func _on_broken(_info: DamageInfo) -> void:
	var at := global_position + Vector3.UP * HEIGHT * 0.5
	Glimmer.spill(get_parent(), at, value)
	Sfx.play(&"jar_break", at)
	GameFeel.impact(at, GLASS, 1.4, 0.25)
	_take()
	queue_free()
