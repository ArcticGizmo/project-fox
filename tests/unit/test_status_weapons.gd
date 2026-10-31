extends TestCase
## Status-effect weapons, held by a bare Node3D at the origin (muzzle 1m up).

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const MUZZLE := Vector3(0, 1, 0)


func before_each() -> void:
	add_floor()


func _equip(id: String) -> Weapon:
	var holder := Node3D.new()
	add_child(holder)
	var data := load("res://data/weapons/%s.tres" % id) as WeaponData
	var w := data.weapon_script.new() as Weapon
	w.setup(data, holder)
	w.position = MUZZLE
	holder.add_child(w)
	return w


func _frozen_ai(path: String, at: Vector3) -> Enemy:
	var e := spawn_enemy(path, at, Player.yaw_of(-at))
	e.set_physics_process(false)
	return e


func _aim_at(point: Vector3) -> AimInfo:
	var aim := AimInfo.create(MUZZLE, point - MUZZLE)
	aim.point = point
	aim.raw_point = point
	return aim


func _fire_until(w: Weapon, aim: AimInfo, condition: Callable, timeout: float) -> bool:
	for _i: int in ceili(timeout / FRAME):
		w.trigger(true, aim)
		await get_tree().physics_frame
		if condition.call():
			w.trigger(false, aim)
			return true
	w.trigger(false, aim)
	return false


func test_frost_lances_chill_then_freeze() -> void:
	# A bull survives long enough to freeze; no player in the scene, so it idles.
	var bull := spawn_enemy(BULL, Vector3(0, 0, -10))
	var w := _equip("frost_narwhal")
	await wait_frames(2)
	w.trigger(true, _aim_at(bull.get_aim_point()))
	w.trigger(false, null)
	var chilled := await wait_until(func() -> bool: return bull.chill > 0.0, 1.0)
	assert_true(chilled, "one lance chills")
	assert_near(bull.chill, w.stats().status_power * bull.status_resistance, 0.02, "chill per hit, scaled by resistance")
	var frozen := await _fire_until(w, _aim_at(bull.get_aim_point()), func() -> bool: return bull.is_frozen(), 6.0)
	assert_true(frozen, "repeated lances freeze")


func test_venom_puddle_stacks_poison_and_level3_is_contagious() -> void:
	var bull := _frozen_ai(BULL, Vector3(0, 0, -10))
	bull.set_physics_process(true)  # statuses need the physics tick; no player so it idles
	var w := _equip("viper_spitter")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 0, -10)))
	w.trigger(false, null)
	var poisoned := await wait_until(func() -> bool: return bull.poison_stacks > 0, 2.0)
	assert_true(poisoned, "standing in the puddle poisons")
	await wait_seconds(1.6)
	assert_true(bull.poison_stacks >= 3, "stacks build while standing in it (%d)" % bull.poison_stacks)
	assert_false(bull.get(&"_poison_contagious"), "level 1 poison is not contagious")
	w.add_xp(60 + 150)
	assert_true(w.stats().upgrade_flag, "level 3 unlocks contagion")
	w.trigger(true, _aim_at(Vector3(0, 0, -10)))
	w.trigger(false, null)
	var contagious := await wait_until(func() -> bool: return bool(bull.get(&"_poison_contagious")), 2.5)
	assert_true(contagious, "level 3 puddle applies contagious poison")


func test_poison_kill_credits_the_spitter() -> void:
	var rat := spawn_enemy(RAT, Vector3(0, 0, -8))
	var w := _equip("viper_spitter")
	await wait_frames(2)
	rat.add_poison(8, w)
	var dead := await wait_until(func() -> bool: return rat.health.is_dead, 3.0)
	assert_true(dead, "poison killed the rat")
	assert_eq(w.xp, rat.xp_value, "poison kill credits the weapon")
