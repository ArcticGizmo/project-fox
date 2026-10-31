class_name HurtBox
extends Area3D
## Receives damage from HitBoxes, projectiles and hitscan, then forwards it to
## a Health node. Put the area on PLAYER_HURTBOX or ENEMY_HURTBOX.

signal hurt(info: DamageInfo)

@export var health: Health
@export var damage_multiplier: float = 1.0
## Weak spots mark hits as critical (bigger damage number, rifle bonus).
@export var is_weak_spot: bool = false

var invulnerable: bool = false
var _outline: DebugOutline


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0


func _ready() -> void:
	_outline = DebugOutline.attach(self)


## Returns true if the hit was accepted. Mutates `info` (multipliers).
func receive(info: DamageInfo) -> bool:
	if invulnerable or not monitorable:
		return false
	if health != null and health.is_dead:
		return false
	info.amount *= damage_multiplier
	if is_weak_spot:
		info.is_critical = true
	if health != null:
		health.apply_damage(info)
	hurt.emit(info)
	return true


## Key used to stop one attack hitting the same entity twice via two hurtboxes.
func entity_id() -> int:
	return health.get_instance_id() if health != null else get_instance_id()


## World-space centre of the hurtbox's first shape (the Area origin is usually
## at the entity's feet).
func center() -> Vector3:
	for child: Node in get_children():
		var cs := child as CollisionShape3D
		if cs != null:
			return cs.global_position
	return global_position


func refresh_outline() -> void:
	if _outline != null:
		_outline.rebuild()


func get_debug_color() -> Color:
	if invulnerable:
		return Color(0.2, 0.9, 1.0, 0.9)
	if is_weak_spot:
		return Color(1.0, 0.6, 0.1, 1.0)
	return Color(0.2, 1.0, 0.3, 0.9)
