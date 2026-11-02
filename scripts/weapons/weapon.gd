class_name Weapon
extends Node3D
## Base weapon: ammo, cooldown, XP and levelling. Subclasses implement _fire()
## (one shot) and optionally _trigger_update() (continuous weapons).
## Weapons level up from the XP of enemies they kill.

signal fired
signal ammo_changed(current: int, maximum: int)
signal xp_changed(xp: int, needed: int)
signal leveled_up(level: int)

var data: WeaponData
var level: int = 1
var xp: int = 0
var ammo: int = 0
## The body holding the weapon. Spawned projectiles go into its parent.
var wielder: Node3D
var hit_mask: int = Layers.WORLD | Layers.ENEMY_HURTBOX

var _cooldown: float = 0.0
var _trigger_held: bool = false
## 0..1 while a charge weapon is held (see trigger); _fire reads it.
var charge: float = 0.0
var _charging: bool = false


func setup(p_data: WeaponData, p_wielder: Node3D) -> void:
	data = p_data
	wielder = p_wielder
	name = String(data.id)
	ammo = stats().max_ammo


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func stats() -> WeaponLevelStats:
	return data.stats_for(level)


func max_ammo() -> int:
	return stats().max_ammo


func is_max_level() -> bool:
	return level >= data.max_level()


func xp_needed() -> int:
	return 0 if is_max_level() else data.xp_to_next_level[level - 1]


func add_xp(amount: int) -> void:
	if is_max_level() or amount <= 0:
		return
	xp += amount
	while not is_max_level() and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		ammo = max_ammo()
		_on_level_changed()
		leveled_up.emit(level)
		ammo_changed.emit(ammo, max_ammo())
	if is_max_level():
		xp = 0
	xp_changed.emit(xp, xp_needed())


func add_ammo(amount: int) -> void:
	ammo = mini(max_ammo(), ammo + amount)
	ammo_changed.emit(ammo, max_ammo())


func can_fire() -> bool:
	return _cooldown <= 0.0 and ammo >= data.ammo_per_shot


## Called every physics frame by the wielder while this weapon is equipped.
## Charge weapons (data.charge_time > 0) build `charge` while held and fire on
## release if it reached data.min_charge; everything else fires while held.
func trigger(held: bool, aim: AimInfo) -> void:
	_trigger_held = held
	if data.charge_time > 0.0:
		if held and can_fire():
			_charging = true
			var was_full := charge >= 1.0
			charge = minf(1.0, charge + get_physics_process_delta_time() / data.charge_time)
			if charge >= 1.0 and not was_full and _wielded_by_player():
				Sfx.play(&"charge_ready")
				GameFeel.rumble(0.3, 0.0, 0.08)
		elif not held and _charging:
			_charging = false
			if charge >= data.min_charge and aim != null:
				_shoot(aim)
			charge = 0.0
	elif held and can_fire():
		_shoot(aim)
	_trigger_update(held, aim)


func _shoot(aim: AimInfo) -> void:
	ammo -= data.ammo_per_shot
	_cooldown = stats().fire_interval
	_fire(aim)
	NoiseEvent.emit(global_position, data.noise_radius, self)
	if _wielded_by_player():
		if data.fire_sound != &"":
			Sfx.play(data.fire_sound)
		GameFeel.rumble(data.fire_rumble.x, data.fire_rumble.y, data.fire_rumble.z)
	fired.emit()
	ammo_changed.emit(ammo, max_ammo())


func _wielded_by_player() -> bool:
	return wielder != null and wielder.is_in_group(&"player")


## Drop a charge without firing (dodge, staff, wheel while the trigger is held).
func cancel_charge() -> void:
	_charging = false
	charge = 0.0


func on_unequipped() -> void:
	_trigger_held = false
	_charging = false
	charge = 0.0
	_trigger_update(false, null)


func make_damage(amount: float, from: Vector3) -> DamageInfo:
	var info := DamageInfo.create(amount, from, stats().knockback)
	info.source_weapon = self
	return info


func spawn_parent() -> Node:
	if wielder != null and wielder.get_parent() != null:
		return wielder.get_parent()
	return get_tree().current_scene


func _fire(_aim: AimInfo) -> void:
	pass


func _trigger_update(_held: bool, _aim: AimInfo) -> void:
	pass


func _on_level_changed() -> void:
	pass


## Ground point `distance` metres in front of the wielder along the aim (for
## deployables: sentries, decoys, walls).
func deploy_point(aim: AimInfo, distance: float) -> Vector3:
	var base := wielder.global_position if wielder != null else aim.origin
	var flat := aim.direction
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var p := base + flat * distance
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 6.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return p if hit.is_empty() else (hit["position"] as Vector3)
