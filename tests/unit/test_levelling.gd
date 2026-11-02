extends TestCase
## Weapon levelling: every level says what it adds, level-ups announce it, and
## each max-level signature perk changes behaviour (not just numbers).

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"
const MUZZLE := Vector3(0, 1, 0)


func before_each() -> void:
	add_floor()


func _equip(id: String, level: int) -> Weapon:
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


func _still(path: String, at: Vector3) -> Enemy:
	var e := spawn_enemy(path, at, Player.yaw_of(-at))
	e.set_physics_process(false)
	return e


func _aim_at(point: Vector3, from: Vector3 = MUZZLE) -> AimInfo:
	var aim := AimInfo.create(from, point - from, null)
	aim.point = point
	aim.raw_point = point
	return aim


func _damage(e: Enemy) -> float:
	return e.health.max_health - e.health.current


func test_every_level_names_its_perk_and_signatures_sit_at_max() -> void:
	var signatures := 0
	for f: String in DirAccess.get_files_at("res://data/weapons"):
		if not f.ends_with(".tres"):
			continue
		var data := load("res://data/weapons/" + f) as WeaponData
		for i: int in data.levels.size():
			var s := data.levels[i]
			if i > 0:
				assert_true(s.perk != "", "%s Lv%d has perk text" % [data.id, i + 1])
			if s.signature:
				assert_eq(i, data.levels.size() - 1, "%s signature only at max level" % data.id)
				signatures += 1
	assert_true(signatures >= 7, "signature perks exist (%d)" % signatures)


func test_level_up_announces_the_perk() -> void:
	var player := Player.new()
	player.input_provider = ScriptedInputProvider.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	var hud := Hud.new()
	add_child(hud)
	await wait_frames(2)
	hud.bind(player, null)
	player.debug_level_current_weapon()
	var w := player.current_weapon()
	var popup := hud.get(&"_popup") as Label
	var detail := hud.get(&"_popup_detail") as Label
	assert_true(popup.text.contains(w.data.display_name), "popup names the weapon: %s" % popup.text)
	assert_eq(detail.text, w.stats().perk, "popup shows what the level adds")
	assert_true(Sfx.played(&"level_up"), "level-up sound")


func test_rifle_signature_crit_staggers() -> void:
	# One bull per level: a level 3 crit alone kills a bull.
	var b3 := _still(BULL, Vector3(-4, 0, -6)) as BrassBull
	var b4 := _still(BULL, Vector3(4, 0, -6)) as BrassBull
	await wait_frames(2)
	b3.health.max_health = 1000.0
	b3.health.current = 1000.0
	b4.health.max_health = 1000.0
	b4.health.current = 1000.0
	# Straight down onto the boiler on each bull's back.
	_equip("owl_lens_rifle", 3).trigger(true, AimInfo.create(b3.weak_spot.center() + Vector3.UP * 5.0, Vector3.DOWN))
	_equip("owl_lens_rifle", 4).trigger(true, AimInfo.create(b4.weak_spot.center() + Vector3.UP * 5.0, Vector3.DOWN))
	await wait_frames(1)
	assert_true(_damage(b3) > 0.0 and _damage(b4) > 0.0, "both shots landed")
	assert_false(b3.is_staggered(), "level 3 crit does not stagger")
	assert_true(b4.is_staggered(), "level 4 crit staggers")

func test_lash_signature_tip_exposes() -> void:
	var w := _equip("kraken_lash", 4)
	var tip := w.stats().max_range * 0.95
	var rat := _still(RAT, Vector3(0, 0, -tip))
	var near := _still(RAT, Vector3(1.0, 0, -2.0))
	await wait_frames(2)
	w.trigger(true, _aim_at(Vector3(0, 1, -tip)))
	await wait_seconds(0.3)
	assert_true(rat.is_exposed(), "tip hit exposes")
	assert_false(near.is_exposed(), "a hit near the fox does not")


func test_silk_signature_exposes_webbed_enemies() -> void:
	var rat := _still(RAT, Vector3(0, 0, -6))
	var w3 := _equip("silk_launcher", 3)
	var w4 := _equip("silk_launcher", 4)
	await wait_frames(2)
	w3.call(&"burst", rat.global_position, 2.0, 1.0)
	assert_true(rat.is_rooted() and not rat.is_exposed(), "level 3 roots only")
	w4.call(&"burst", rat.global_position, 2.0, 1.0)
	assert_true(rat.is_exposed(), "level 4 also exposes")


func test_frost_signature_shatters_frozen_kills() -> void:
	var victim := _still(BULL, Vector3(0, 0, -10))
	var neighbour := _still(BULL, Vector3(2.5, 0, -10))
	await wait_frames(2)
	victim.freeze(5.0)
	victim.health.apply_damage(DamageInfo.create(victim.health.current - 1.0, Vector3.ZERO))
	var w := _equip("frost_narwhal", 4)
	w.trigger(true, _aim_at(victim.get_aim_point()))
	var dead := await wait_until(func() -> bool: return victim.health.is_dead, 1.0)
	assert_true(dead, "lance killed the frozen bull")
	await wait_frames(1)
	assert_true(neighbour.chill > 0.0 or neighbour.is_frozen(), "shatter chilled the neighbour")


func test_echo_signature_reflects_projectiles() -> void:
	var toad := _still(TOAD, Vector3(0, 0, -12))
	await wait_frames(2)
	var lob := LobProjectile.launch(toad, Vector3(0, 1.5, -6), Vector3(0, 0, 0), 2.0, 10.0, 2.0)
	var w3 := _equip("echo_horn", 3)
	w3.trigger(true, _aim_at(Vector3(0, 1, -6)))
	assert_false(lob.reflected, "level 3 does not reflect")
	var w4 := _equip("echo_horn", 4)
	await wait_frames(1)
	w4.trigger(true, _aim_at(Vector3(0, 1, -6)))
	assert_true(lob.reflected, "level 4 reflects the lob")
	assert_eq(int(w4.get(&"last_reflected")), 1, "one projectile reflected")
	var hit := await wait_until(func() -> bool: return _damage(toad) > 0.0, 2.0)
	assert_true(hit, "reflected lob hits the toad")


func test_salamander_signature_stokes_while_held() -> void:
	var w := _equip("salamander_breath", 4)
	var s := w.stats()
	await wait_frames(2)
	var aim := _aim_at(Vector3(0, 1, -5))
	for _i: int in ceili(s.sub_interval * 60.0) + 5:
		w.trigger(true, aim)
		await get_tree().physics_frame
	assert_near(float(w.get(&"stoke")), 1.0, 0.001, "fully stoked after sub_interval")
	assert_near(w.call(&"stoke_multiplier"), 1.0 + s.status_power, 0.001, "max multiplier")
	w.trigger(false, aim)
	assert_near(float(w.get(&"stoke")), 0.0, 0.001, "letting go resets")
	var w3 := _equip("salamander_breath", 3)
	for _i: int in 30:
		w3.trigger(true, aim)
		await get_tree().physics_frame
	assert_near(w3.call(&"stoke_multiplier"), 1.0, 0.001, "no stoking below max level")


func test_repeater_signature_ricochets() -> void:
	var first := _still(BULL, Vector3(0, 0, -10))
	var second := _still(BULL, Vector3(4, 0, -10))
	await wait_frames(2)
	var w3 := _equip("woodpecker_repeater", 3)
	w3.trigger(true, _aim_at(first.get_aim_point()))
	await wait_seconds(0.5)
	assert_true(_damage(first) > 0.0, "level 3 rivet hit")
	assert_near(_damage(second), 0.0, 0.001, "no ricochet at level 3")
	var w4 := _equip("woodpecker_repeater", 4)
	w4.trigger(true, _aim_at(first.get_aim_point()))
	var bounced := await wait_until(func() -> bool: return _damage(second) > 0.0, 1.0)
	assert_true(bounced, "level 4 rivet ricocheted into the second bull")
