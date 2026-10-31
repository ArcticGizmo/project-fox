extends TestCase

const HORNET := "res://data/weapons/hornet_swarm.tres"
const SALAMANDER := "res://data/weapons/salamander_breath.tres"
const RIFLE := "res://data/weapons/owl_lens_rifle.tres"
const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"


## A wielder at the origin facing -Z with the weapon 1m up.
func _equip(data_path: String) -> Weapon:
	var holder := Node3D.new()
	add_child(holder)
	var data := load(data_path) as WeaponData
	var w := data.weapon_script.new() as Weapon
	w.setup(data, holder)
	w.position = Vector3(0, 1, 0)
	holder.add_child(w)
	return w


func test_all_weapon_data_valid() -> void:
	for path: String in [HORNET, SALAMANDER, RIFLE]:
		var data := load(path) as WeaponData
		assert_true(data != null, "%s loads as WeaponData" % path)
		if data == null:
			continue
		var problems := data.validate()
		assert_true(problems.is_empty(), "%s: %s" % [path, ", ".join(problems)])
		var instance: Object = data.weapon_script.new()
		assert_true(instance is Weapon, "%s script extends Weapon" % path)
		instance.free()


func test_levelling_thresholds_and_ammo_refill() -> void:
	var w := _equip(HORNET)
	assert_eq(w.level, 1, "starts at 1")
	assert_eq(w.ammo, 30, "level 1 ammo")
	w.ammo = 5
	w.add_xp(59)
	assert_eq(w.level, 1, "59 xp is not enough")
	w.add_xp(1)
	assert_eq(w.level, 2, "60 xp levels up")
	assert_eq(w.xp, 0, "xp carried")
	assert_eq(w.ammo, 36, "level-up refills to new max")
	w.add_xp(100000)
	assert_eq(w.level, 4, "caps at max level")
	assert_true(w.is_max_level(), "is max")
	assert_eq(w.xp, 0, "no xp at max")


func test_cooldown_and_ammo_use() -> void:
	var w := _equip(RIFLE)
	await wait_frames(1)
	var aim := AimInfo.create(Vector3(0, 1, 0), Vector3.FORWARD)
	w.trigger(true, aim)
	w.trigger(true, aim)
	assert_eq(w.ammo, 9, "only one shot within cooldown")
	await wait_seconds(w.stats().fire_interval + 0.05)
	w.trigger(true, aim)
	assert_eq(w.ammo, 8, "fires again after cooldown")
	w.ammo = 0
	await wait_seconds(1.0)
	w.trigger(true, aim)
	assert_eq(w.ammo, 0, "cannot fire empty")


func test_rifle_kill_grants_xp_to_weapon() -> void:
	add_floor()
	var rat := spawn_enemy(RAT, Vector3(0, 0, -10))
	var w := _equip(RIFLE)
	await wait_frames(2)
	var origin := Vector3(0, 1, 0)
	w.trigger(true, AimInfo.create(origin, rat.get_aim_point() - origin))
	await wait_frames(2)
	assert_true(rat.health.is_dead, "45 damage kills a 24hp rat")
	assert_eq(w.xp, rat.xp_value, "kill XP credited to the weapon")


func test_rifle_weak_spot_crits() -> void:
	add_floor()
	var bull := spawn_enemy(BULL, Vector3(0, 0, -10)) as BrassBull
	var w := _equip(RIFLE)
	await wait_frames(2)
	# Shoot straight down onto the boiler on the bull's back.
	var spot_shape := bull.get_node("WeakSpot").get_child(0) as CollisionShape3D
	var above := spot_shape.global_position + Vector3.UP * 5.0
	w.trigger(true, AimInfo.create(above, Vector3.DOWN))
	await wait_frames(1)
	var expected := 45.0 * 1.5 * bull.weak_spot_multiplier
	assert_near(bull.health.max_health - bull.health.current, expected, 0.01, "weak spot damage")


func test_hornets_home_onto_off_axis_target() -> void:
	add_floor()
	var rat := spawn_enemy(RAT, Vector3(-8, 0, -8))
	var w := _equip(HORNET)
	await wait_frames(2)
	# Fire straight ahead; the rat is 45 degrees to the left.
	w.trigger(true, AimInfo.create(Vector3(0, 1, 0), Vector3.FORWARD, rat))
	var hit := await wait_until(func() -> bool: return rat.health.current < rat.health.max_health, 2.0)
	assert_true(hit, "homing hornets reached the target")


func test_salamander_ticks_and_burns_at_level_3() -> void:
	add_floor()
	var bull := spawn_enemy(BULL, Vector3(0, 0, -3.5))
	var w := _equip(SALAMANDER)
	w.add_xp(80 + 180)
	assert_eq(w.level, 3, "levelled to 3")
	await wait_frames(2)
	var aim := AimInfo.create(Vector3(0, 1, 0), Vector3.FORWARD)
	for _i: int in 60:
		w.trigger(true, aim)
		await get_tree().physics_frame
	w.trigger(false, aim)
	var dealt := bull.health.max_health - bull.health.current
	assert_true(dealt >= 45.0 and dealt <= 75.0, "about 10 ticks of 5.5 plus burn in 1s, got %.1f" % dealt)
	assert_true(bull._burn_left > 0.0, "target is burning")
	var shot_ammo := w.ammo
	assert_true(shot_ammo <= 200 - 9 and shot_ammo >= 200 - 11, "about 10 ammo used, %d left" % shot_ammo)
