extends TestCase
## Clockwork Swallow (curves round to hit from behind) and Rhino Beetle Ram
## (hold to charge, release to fire; a full charge upends).

const BULL := "res://scenes/enemies/brass_bull.tscn"
const PANGOLIN := "res://scenes/enemies/brass_pangolin.tscn"
const MUZZLE := Vector3(0, 1, 0)


func before_each() -> void:
	add_floor()


func _equip(id: String, level: int = 1) -> Weapon:
	var holder := Node3D.new()
	add_child(holder)
	var data := load("res://data/weapons/%s.tres" % id) as WeaponData
	var w := data.weapon_script.new() as Weapon
	w.setup(data, holder)
	w.position = MUZZLE
	holder.add_child(w)
	w.level = level
	w._on_level_changed()
	w.ammo = w.max_ammo()
	return w


## Facing the origin with AI off.
func _still(path: String, at: Vector3) -> Enemy:
	var e := spawn_enemy(path, at, Player.yaw_of(-at))
	e.set_physics_process(false)
	return e


func _aim_at(e: Enemy) -> AimInfo:
	var aim := AimInfo.create(MUZZLE, e.get_aim_point() - MUZZLE, e)
	aim.point = e.get_aim_point()
	aim.raw_point = aim.point
	return aim


func _damage(e: Enemy) -> float:
	return e.health.max_health - e.health.current


func _hold(w: Weapon, aim: AimInfo, frames: int) -> void:
	for _i: int in frames:
		w.trigger(true, aim)
		await get_tree().physics_frame


# --- Clockwork Swallow ----------------------------------------------------------

func test_swallow_loops_round_the_armour() -> void:
	var p := _still(PANGOLIN, Vector3(0, 0, -12)) as BrassPangolin
	await wait_frames(2)
	var w := _equip("clockwork_swallow")
	w.trigger(true, _aim_at(p))
	var darts: Array[SwallowDart] = w.get(&"last_darts")
	assert_eq(darts.size(), 1, "one swallow at level 1")
	var hit := await wait_until(func() -> bool: return _damage(p) > 0.0, 3.0)
	assert_true(hit, "swallow reached the pangolin")
	assert_eq(int(w.get(&"back_hits")), 1, "struck from behind")
	assert_eq(p.blocked_hits, 0, "armour never saw it")
	assert_near(_damage(p), w.stats().damage, 0.01, "full damage")


func test_swallow_alternates_sides_and_doubles_at_level_3() -> void:
	var bull := _still(BULL, Vector3(0, 0, -12))
	await wait_frames(2)
	var w := _equip("clockwork_swallow")
	w.trigger(true, _aim_at(bull))
	var first := (w.get(&"last_darts") as Array[SwallowDart])[0].side
	await wait_seconds(w.stats().fire_interval + 0.05)
	w.trigger(true, _aim_at(bull))
	var second := (w.get(&"last_darts") as Array[SwallowDart])[0].side
	assert_eq(second, -first, "next shot curves the other way")
	var w3 := _equip("clockwork_swallow", 3)
	w3.trigger(true, _aim_at(bull))
	var pair: Array[SwallowDart] = w3.get(&"last_darts")
	assert_eq(pair.size(), 2, "two swallows at level 3")
	assert_eq(pair[0].side, -pair[1].side, "one round each side")


func test_swallow_signature_back_hits_crit() -> void:
	var bull := _still(BULL, Vector3(0, 0, -12))
	await wait_frames(2)
	var w := _equip("clockwork_swallow", 4)
	var s := w.stats()
	w.trigger(true, _aim_at(bull))
	var hit := await wait_until(func() -> bool: return _damage(bull) >= s.damage * s.crit_multiplier * 2.0 - 0.01, 3.0)
	assert_true(hit, "both swallows crit in the back (damage %.1f, back hits %d)" % [_damage(bull), int(w.get(&"back_hits"))])


func test_swallow_without_target_flies_out_and_ends() -> void:
	var w := _equip("clockwork_swallow")
	var aim := AimInfo.create(MUZZLE, Vector3.FORWARD)
	aim.point = MUZZLE + Vector3.FORWARD * 15.0
	w.trigger(true, aim)
	var dart: WeakRef = weakref((w.get(&"last_darts") as Array[SwallowDart])[0])
	var gone := await wait_until(func() -> bool: return dart.get_ref() == null, 4.0)
	assert_true(gone, "dart expires after its curve")


# --- Rhino Beetle Ram -------------------------------------------------------------

func test_beetle_fires_on_release_scaled_by_charge() -> void:
	var bull := _still(BULL, Vector3(0, 0, -10))
	await wait_frames(2)
	var w := _equip("rhino_beetle_ram")
	var s := w.stats()
	var aim := _aim_at(bull)
	# A tap below min_charge does nothing.
	await _hold(w, aim, 2)
	w.trigger(false, aim)
	assert_eq(w.ammo, w.max_ammo(), "tap does not fire")
	# Half a charge.
	var frames := roundi(w.data.charge_time * 60.0 * 0.5)
	await _hold(w, aim, frames)
	var charge := w.charge
	assert_near(charge, 0.5, 0.03, "charge fills over charge_time")
	w.trigger(false, aim)
	assert_eq(w.charge, 0.0, "release empties the charge")
	assert_eq(w.ammo, w.max_ammo() - 1, "release fires")
	var hit := await wait_until(func() -> bool: return _damage(bull) > 0.0, 1.0)
	assert_true(hit, "slug hit")
	assert_near(_damage(bull), s.damage * lerpf(0.35, 1.0, charge), 0.01, "damage scales with charge")
	assert_false(bull.is_staggered(), "a partial charge does not upend")


func test_beetle_full_charge_upends_and_flips_a_pangolin() -> void:
	var bull := _still(BULL, Vector3(-3, 0, -10))
	var p := _still(PANGOLIN, Vector3(3, 0, -10)) as BrassPangolin
	await wait_frames(2)
	var w := _equip("rhino_beetle_ram")
	var frames := ceili(w.data.charge_time * 60.0) + 2
	await _hold(w, _aim_at(bull), frames)
	assert_eq(w.charge, 1.0, "fully charged")
	w.trigger(false, _aim_at(bull))
	var upended := await wait_until(func() -> bool: return bull.is_staggered(), 1.0)
	assert_true(upended, "full charge upends the bull")
	await wait_seconds(w.stats().fire_interval)
	await _hold(w, _aim_at(p), frames)
	w.trigger(false, _aim_at(p))
	p.set_physics_process(true)
	var flipped := await wait_until(func() -> bool: return p.state == &"dizzy", 1.0)
	assert_true(flipped, "a full charge flips the pangolin onto its back, even from the front")


func test_beetle_charge_cancels_without_firing() -> void:
	var w := _equip("rhino_beetle_ram")
	var aim := AimInfo.create(MUZZLE, Vector3.FORWARD)
	await _hold(w, aim, 40)
	w.cancel_charge()
	w.trigger(false, aim)
	assert_eq(w.ammo, w.max_ammo(), "cancelled charge does not fire")
	assert_eq(w.charge, 0.0, "charge dropped")


func test_beetle_signature_upends_the_crowd() -> void:
	var target := _still(BULL, Vector3(0, 0, -10))
	var near := _still(BULL, Vector3(2.5, 0, -10.5))
	var far := _still(BULL, Vector3(12, 0, -10))
	await wait_frames(2)
	var w := _equip("rhino_beetle_ram", 4)
	await _hold(w, _aim_at(target), ceili(w.data.charge_time * 60.0) + 2)
	w.trigger(false, _aim_at(target))
	var upended := await wait_until(func() -> bool: return target.is_staggered(), 1.0)
	assert_true(upended, "target upended")
	assert_true(near.is_staggered(), "neighbour upended too")
	assert_false(far.is_staggered(), "out of range untouched")


func test_player_charge_drops_when_dodging() -> void:
	var pad := ScriptedInputProvider.new()
	var player := Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)
	pad.next.weapon_slot = player.weapon_paths.find("res://data/weapons/rhino_beetle_ram.tres") % Player.WHEEL_PAGE_SIZE
	pad.next.weapon_next = true
	await wait_frames(2)
	var w := player.current_weapon()
	if w.data.id != &"rhino_beetle_ram":
		player.call(&"_select_weapon", player.weapon_paths.find("res://data/weapons/rhino_beetle_ram.tres"))
		await wait_frames(1)
		w = player.current_weapon()
	assert_eq(w.data.id, &"rhino_beetle_ram", "beetle equipped")
	pad.next.fire_held = true
	await wait_frames(30)
	assert_true(w.charge > 0.3, "charging while held")
	pad.next.dodge_pressed = true
	await wait_frames(2)
	assert_eq(w.charge, 0.0, "dodge drops the charge")
	assert_eq(w.ammo, w.max_ammo(), "and fires nothing")
	pad.next.fire_held = false
