class_name DamageInfo
extends RefCounted
## One instance per hit. HurtBox.receive() may scale `amount`, so never share
## an instance between two hurtboxes.

var amount: float = 0.0
## Where the hit came from; knockback pushes away from this point.
var source_position: Vector3 = Vector3.ZERO
var knockback: float = 0.0
var knockback_up: float = 0.0
## Weapon credited with the hit (gets XP on kill). May be null or freed.
var source_weapon: Weapon = null
var is_critical: bool = false
## Damage-over-time ticks skip flinch, knockback and damage numbers.
var is_dot: bool = false


static func create(p_amount: float, p_source_position: Vector3, p_knockback: float = 0.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.source_position = p_source_position
	info.knockback = p_knockback
	return info
