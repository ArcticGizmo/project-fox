extends TestCase
## Behaviour tests for the second batch of weapons. Weapons are held by a
## bare Node3D at the origin (muzzle 1m up) and fired with hand-built AimInfo.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"
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


## Spawned facing the origin with AI off: a stationary target dummy.
func _frozen(path: String, at: Vector3) -> Enemy:
	var e := spawn_enemy(path, at, Player.yaw_of(-at))
	e.set_physics_process(false)
	return e


func _aim_at(point: Vector3, target: Node3D = null) -> AimInfo:
	var aim := AimInfo.create(MUZZLE, point - MUZZLE, target)
	aim.point = point
	aim.raw_point = point
	return aim


func _damage(e: Enemy) -> float:
	return e.health.max_health - e.health.current


# --- Woodpecker Repeater -------------------------------------------------------

func test_repeater_has_no_lock_on_and_blooms() -> void:
	var data := load("res://data/weapons/woodpecker_repeater.tres") as WeaponData
	assert_false(data.uses_aim_assist, "blaster ignores aim assist")
	var w := _equip("woodpecker_repeater")
	await wait_frames(2)
	var aim := _aim_at(Vector3(0, 1, -30))
	for _i: int in 90:
		w.trigger(true, aim)
		await get_tree().physics_frame
	assert_true(w.get(&"bloom") > 0.9, "spread bloomed to max while held")
	w.trigger(false, aim)
	await wait_seconds(0.5)
	assert_near(float(w.get(&"bloom")), 0.0, 0.001, "bloom recovers on release")


func test_repeater_first_shot_is_dead_accurate() -> void:
	var rat := _frozen(RAT, Vector3(0, 0, -25))
	var w := _equip("woodpecker_repeater")
	await wait_frames(2)
	w.trigger(true, _aim_at(rat.get_aim_point()))
	w.trigger(false, null)
	var hit := await wait_until(func() -> bool: return _damage(rat) > 0.0, 1.0)
	assert_true(hit, "unbloomed rivet hits a small target at 25m")


# --- Kraken Lash ---------------------------------------------------------------

func test_lash_hits_whole_line_and_tip_crits() -> void:
	var near := _frozen(BULL, Vector3(0, 0, -2.5))
	var far := _frozen(BULL, Vector3(0, 0, -6.4))
	var w := _equip("kraken_lash")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 1, -10)))
	await wait_seconds(0.3)
	var s := w.stats()
	assert_near(_damage(near), s.damage, 0.01, "shaft hit is normal damage")
	assert_near(_damage(far), s.damage * s.crit_multiplier, 0.01, "tip hit is a crit")


func test_lash_pulls_enemies_from_level_3() -> void:
	var toad := spawn_enemy(TOAD, Vector3(0, 0, -5), 0.0)  # no player in the scene, so it idles
	var w := _equip("kraken_lash")
	w.add_xp(60 + 150)
	assert_eq(w.level, 3, "levelled")
	assert_true(w.stats().knockback < 0.0, "level 3 knockback is a pull")
	await wait_frames(5)
	var start_z := toad.global_position.z
	w.trigger(true, _aim_at(Vector3(0, 1, -10)))
	await wait_seconds(0.5)
	assert_true(toad.global_position.z > start_z + 0.5, "toad pulled toward the fox (%.2f -> %.2f)" % [start_z, toad.global_position.z])


# --- Pufferfish Mortar ---------------------------------------------------------

func test_mortar_mine_arms_and_triggers_on_enemy() -> void:
	var w := _equip("pufferfish_mortar")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 0, -10)))
	await wait_seconds(1.5)
	var mines := find_children("*", "PufferMine", true, false)
	assert_eq(mines.size(), 1, "one mine on the ground")
	if mines.is_empty():
		return
	var mine := mines[0] as PufferMine
	assert_eq(mine.state, PufferMine.State.ARMED, "mine armed after landing")
	assert_near(mine.global_position.z, -10.0, 0.6, "landed at the aim point")
	var bull := _frozen(BULL, Vector3(0, 0, -12.6))
	var boom := await wait_until(func() -> bool: return _damage(bull) > 0.0, 1.0)
	assert_true(boom, "enemy in range set the mine off")
	assert_near(_damage(bull), w.stats().damage, 0.01, "blast damage")


func test_mortar_direct_hit_detonates_immediately() -> void:
	var bull := _frozen(BULL, Vector3(0, 0, -9))
	var w := _equip("pufferfish_mortar")
	await wait_frames(2)
	w.trigger(true, _aim_at(bull.get_aim_point()))
	var boom := await wait_until(func() -> bool: return _damage(bull) > 0.0, 1.5)
	assert_true(boom, "direct hit exploded")
	assert_eq(find_children("*", "PufferMine", true, false).size(), 0, "no mine left behind")


func test_mortar_fuse_expires() -> void:
	var w := _equip("pufferfish_mortar")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 0, -8)))
	var gone := await wait_until(func() -> bool: return find_children("*", "PufferMine", true, false).is_empty(), w.stats().duration + 2.5)
	assert_true(gone, "unattended mine detonates after its fuse")


# --- Galvanic Eel --------------------------------------------------------------

func test_eel_chains_between_nearby_enemies() -> void:
	var a := _frozen(BULL, Vector3(0, 0, -6))
	var b := _frozen(BULL, Vector3(4, 0, -8))
	var c := _frozen(BULL, Vector3(8, 0, -10))
	var far := _frozen(BULL, Vector3(-20, 0, -10))
	var w := _equip("galvanic_eel")
	await wait_frames(2)
	w.trigger(true, _aim_at(a.get_aim_point(), a))
	var chain: Array[Node3D] = w.get(&"last_chain")
	assert_eq(chain.size(), w.stats().pierce + 1, "jumped the full chain")
	var s := w.stats()
	assert_near(_damage(a), s.damage, 0.01, "first target full damage")
	assert_near(_damage(b), s.damage * 0.85, 0.01, "second jump falls off")
	assert_near(_damage(c), s.damage * 0.85 * 0.85, 0.01, "third jump falls off again")
	assert_eq(_damage(far), 0.0, "out-of-range enemy untouched")


func test_eel_without_target_does_nothing() -> void:
	var w := _equip("galvanic_eel")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 1, -10)))
	assert_eq((w.get(&"last_chain") as Array[Node3D]).size(), 0, "no chain")
	assert_eq(w.ammo, w.max_ammo() - 1, "still costs ammo")


# --- Tortoise Sentry -----------------------------------------------------------

func test_sentry_shoots_enemies_and_credits_xp() -> void:
	var rat := _frozen(RAT, Vector3(0, 0, -10))
	var w := _equip("tortoise_sentry")
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 0, -10)))
	w.trigger(false, null)
	var killed := await wait_until(func() -> bool: return rat.health.is_dead, 4.0)
	assert_true(killed, "sentry killed the rat")
	assert_eq(w.xp, rat.xp_value, "sentry kills credit the weapon")


func test_sentry_count_is_capped_and_expires() -> void:
	var w := _equip("tortoise_sentry")
	await wait_frames(2)
	var aim := _aim_at(Vector3(0, 0, -10))
	w.trigger(true, aim)
	await wait_seconds(w.stats().fire_interval + 0.05)
	w.trigger(true, aim)
	w.trigger(false, null)
	await wait_seconds(0.5)
	assert_eq(find_children("*", "Sentry", true, false).size(), w.stats().projectile_count, "oldest sentry retired at the cap")
	var gone := await wait_until(func() -> bool: return find_children("*", "Sentry", true, false).is_empty(), w.stats().duration + 1.0)
	assert_true(gone, "sentry expires after its lifetime")
