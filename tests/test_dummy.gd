class_name TestDummy
extends CharacterBody3D
## Player stand-in for enemy tests. Static unless `velocity` is set by a test.

var health: Health
var hurt_box: HurtBox
var hits: Array[DamageInfo] = []
var move_with_velocity: bool = false
## Pocket money for thieves (Raccoon Rogue), like Player.glimmer.
var glimmer: int = 0


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = capsule
	cs.position.y = 0.9
	add_child(cs)
	health = Health.new()
	health.max_health = 1000.0
	add_child(health)
	hurt_box = HurtBox.new()
	hurt_box.collision_layer = Layers.PLAYER_HURTBOX
	hurt_box.health = health
	var hcs := CollisionShape3D.new()
	hcs.shape = capsule
	hcs.position.y = 0.9
	hurt_box.add_child(hcs)
	add_child(hurt_box)
	hurt_box.hurt.connect(func(info: DamageInfo) -> void: hits.append(info))


func _physics_process(_delta: float) -> void:
	if move_with_velocity:
		move_and_slide()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP


func spend_glimmer(amount: int) -> bool:
	if amount < 0 or amount > glimmer:
		return false
	glimmer -= amount
	return true


func damage_taken() -> float:
	return health.max_health - health.current
