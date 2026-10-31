class_name MothLanternDecoy
extends Node3D
## A glowing lantern decoy. Enemies within lure_radius target it instead of
## the fox (see Enemy._resolve_target). It has a player-side hurtbox, so
## enemy attacks hit it; when destroyed or when its time runs out it bursts,
## damaging nearby enemies and crediting the weapon.

const BLAST_RADIUS := 3.5
const GLOW := Color(1.0, 0.85, 0.5)

var weapon: Weapon = null
var lure_radius: float = 14.0
var lifetime: float = 8.0
var blast_damage: float = 30.0
var max_health: float = 40.0
var health: Health
var hurt_box: HurtBox

var _age: float = 0.0
var _done: bool = false
var _light: OmniLight3D


func _ready() -> void:
	add_to_group(&"lures")
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, 1.2, 0.12)
	post.mesh = post_mesh
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.3)
	post.material_override = brass
	post.position.y = 0.6
	add_child(post)
	var lamp := MeshInstance3D.new()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.3
	lamp_mesh.height = 0.6
	lamp.mesh = lamp_mesh
	var glow := StandardMaterial3D.new()
	glow.albedo_color = GLOW
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 2.5
	lamp.material_override = glow
	lamp.position.y = 1.4
	add_child(lamp)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.omni_range = 6.0
	_light.position.y = 1.4
	add_child(_light)

	health = Health.new()
	health.max_health = max_health
	add_child(health)
	health.died.connect(func(_info: DamageInfo) -> void: burst())
	# Same size and layer as the fox's hurtbox so every enemy attack connects.
	hurt_box = HurtBox.new()
	hurt_box.collision_layer = Layers.PLAYER_HURTBOX
	hurt_box.health = health
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	cs.shape = capsule
	cs.position.y = 0.9
	hurt_box.add_child(cs)
	add_child(hurt_box)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP


func _physics_process(delta: float) -> void:
	_age += delta
	_light.light_energy = 1.5 + 0.5 * sin(_age * 9.0)
	if _age >= lifetime:
		burst()


func burst() -> void:
	if _done:
		return
	_done = true
	remove_from_group(&"lures")
	Explosion.detonate(self, get_aim_point(), BLAST_RADIUS, Layers.ENEMY_HURTBOX, _make_damage)
	GameFeel.impact(get_aim_point(), GLOW, BLAST_RADIUS * 2.0, 0.3)
	GameFeel.shake(0.2)
	queue_free()


func _make_damage() -> DamageInfo:
	var info: DamageInfo
	if is_instance_valid(weapon):
		info = weapon.make_damage(blast_damage, global_position)
	else:
		info = DamageInfo.create(blast_damage, global_position)
	info.knockback = 8.0
	info.knockback_up = 4.0
	return info
