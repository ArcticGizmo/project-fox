extends TestCase
## Lure (Moth Lantern) and reflect (Hermit Bulwark) behaviours end to end.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"


func before_each() -> void:
	add_floor()


## A weapon held by a bare node at `at`, aiming along `dir`.
func _equip(id: String, at: Vector3) -> Weapon:
	var holder := Node3D.new()
	holder.position = at
	add_child(holder)
	var data := load("res://data/weapons/%s.tres" % id) as WeaponData
	var w := data.weapon_script.new() as Weapon
	w.setup(data, holder)
	w.position = Vector3.UP
	holder.add_child(w)
	return w


func _deploy(w: Weapon, dir: Vector3) -> void:
	await wait_frames(2)
	w.trigger(true, AimInfo.create(w.global_position, dir))
	w.trigger(false, null)
	await wait_frames(2)


func test_lantern_draws_enemies_and_bursts_when_broken() -> void:
	var dummy := add_dummy_target(Vector3(0, 0, 10))
	var rat := spawn_enemy(RAT, Vector3(0, 0, -6), 0.0)
	var w := _equip("moth_lantern", Vector3.ZERO)
	await _deploy(w, Vector3.FORWARD)
	var decoys := find_children("*", "MothLanternDecoy", true, false)
	assert_eq(decoys.size(), 1, "lantern planted")
	if decoys.is_empty():
		return
	var decoy := decoys[0] as MothLanternDecoy
	assert_eq(rat.target, decoy, "rat goes for the lantern, not the player")
	var attacked := await wait_until(func() -> bool: return decoy.health.current < decoy.health.max_health, 6.0)
	assert_true(attacked, "rat attacks the lantern")
	var bull := spawn_enemy(BULL, decoy.global_position + Vector3(2, 0, 0))
	bull.set_physics_process(false)
	await wait_frames(2)
	decoy.health.apply_damage(DamageInfo.create(9999.0, Vector3.ZERO))
	await wait_frames(2)
	assert_true(bull.health.current < bull.health.max_health, "lantern burst damages nearby enemies")
	assert_eq(get_tree().get_nodes_in_group(&"lures").size(), 0, "no longer a lure")
	if is_instance_valid(rat) and not rat.health.is_dead:
		assert_eq(rat.target, dummy, "rat returns to the player")


func test_bulwark_reflects_toad_lob_back_at_thrower() -> void:
	var dummy := add_dummy_target(Vector3.ZERO)
	var toad := spawn_enemy(TOAD, Vector3(0, 0, -13), PI) as SpitterToad
	var w := _equip("hermit_bulwark", Vector3.ZERO)
	await _deploy(w, Vector3.FORWARD)
	assert_eq(find_children("*", "Bulwark", true, false).size(), 1, "wall raised")
	var hurt := await wait_until(func() -> bool: return toad.health.current < toad.health.max_health, 6.0)
	assert_true(hurt, "reflected lob hit the toad")
	assert_eq(dummy.hits.size(), 0, "player behind the wall untouched")
	assert_near(toad.health.max_health - toad.health.current, w.stats().damage, 0.01, "reflected lob deals the bulwark's damage")


func test_bull_stuns_itself_on_bulwark() -> void:
	add_dummy_target(Vector3.ZERO)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -15), PI) as BrassBull
	var w := _equip("hermit_bulwark", Vector3.ZERO)
	await _deploy(w, Vector3.FORWARD)
	var stunned := await wait_until(func() -> bool: return bull.state == &"stunned", 5.0)
	assert_true(stunned, "charging into the shell wall stuns the bull; log=%s" % [bull.state_log])


func test_wall_count_is_capped() -> void:
	var w := _equip("hermit_bulwark", Vector3.ZERO)
	await _deploy(w, Vector3.FORWARD)
	await wait_seconds(w.stats().fire_interval + 0.05)
	await _deploy(w, Vector3.LEFT)
	await wait_seconds(0.4)
	assert_eq(find_children("*", "Bulwark", true, false).size(), w.stats().projectile_count, "oldest wall retracts")
