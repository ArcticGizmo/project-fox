extends TestCase
## Level infrastructure: LevelRoot, checkpoints, placed-enemy reset on respawn,
## gadget registry and gates, level select.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const SLICE := "res://scenes/levels/slice_01.tscn"


func _kill(health: Health, amount: float = 100000.0) -> void:
	health.apply_damage(DamageInfo.create(amount, Vector3.ZERO))


func _make_player(at: Vector3) -> Player:
	var p := Player.new()
	p.input_provider = ScriptedInputProvider.new()
	p.position = at
	add_child(p)
	return p


func _make_checkpoint(at: Vector3, yaw: float = 0.0) -> Checkpoint:
	var c := Checkpoint.new()
	c.position = at
	c.rotation.y = yaw
	add_child(c)
	return c


func _placed_enemy(parent: Node, path: String, at: Vector3, yaw: float, seed_value: int) -> Enemy:
	var e := (load(path) as PackedScene).instantiate() as Enemy
	e.position = at
	e.rotation.y = yaw
	e.random_seed = seed_value
	parent.add_child(e)
	return e


## A code-built level: floor, spawn, Enemies/{Bull, Bull2 + patrol, Rat}.
func _make_level() -> LevelRoot:
	var level := LevelRoot.new()
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.05, 20)
	level.add_child(spawn)
	var floor_block := Block.new()
	floor_block.size = Vector3(200, 1, 200)
	floor_block.position.y = -0.5
	level.add_child(floor_block)
	var group := Node3D.new()
	group.name = "Enemies"
	level.add_child(group)
	_placed_enemy(group, BULL, Vector3(-6, 0, -10), 0.5, 3).name = "Bull"
	var patroller := _placed_enemy(group, BULL, Vector3(6, 0, -10), -0.5, 4)
	patroller.name = "Bull2"
	patroller.max_health = 200.0
	for x: float in [3.0, -3.0]:
		var m := Marker3D.new()
		m.position = Vector3(x, 0, 0)
		patroller.add_child(m)
	_placed_enemy(group, RAT, Vector3(0, 0, -14), 0.0, 5).name = "Rat"
	add_child(level)
	return level


func test_checkpoint_sets_spawn_point_and_latest_wins() -> void:
	add_floor()
	var player := _make_player(Vector3(0, 0.05, 0))
	var a := _make_checkpoint(Vector3(0, 0, 8), 1.0)
	var b := _make_checkpoint(Vector3(10, 0, 8), -2.0)
	await wait_frames(3)
	assert_false(a.active or b.active, "nothing lit before touching")
	player.global_position = Vector3(0, 0.05, 8)
	await wait_frames(3)
	assert_true(a.active, "first checkpoint lit")
	assert_true(player.spawn_point.distance_to(a.spawn_position()) < 0.01, "spawn point moved to checkpoint A")
	assert_near(player.spawn_yaw, 1.0, 0.001, "facing follows the checkpoint")
	player.global_position = Vector3(10, 0.05, 8)
	await wait_frames(3)
	assert_true(b.active and not a.active, "most recent checkpoint wins")
	assert_true(player.spawn_point.distance_to(b.spawn_position()) < 0.01, "spawn point moved to checkpoint B")
	_kill(player.health)
	assert_true(player.is_dead, "player died")
	await wait_until(func() -> bool: return not player.is_dead, Player.RESPAWN_DELAY + 1.0)
	assert_true(player.global_position.distance_to(b.spawn_position()) < 0.3, "respawned at checkpoint B")
	assert_near(player.facing_yaw, -2.0, 0.001, "respawned facing the checkpoint's way")


func test_respawn_resets_placed_enemies_but_not_wave_enemies() -> void:
	var level := _make_level()
	await wait_frames(3)
	assert_eq(level.placed.size(), 3, "three placed enemies recorded")
	var player := level.player
	var originals := level.placed_enemies()
	var original_ids: Array[int] = []
	for e: Enemy in originals:
		original_ids.append(e.get_instance_id())
	var bull := originals[0]
	var patroller := originals[1]
	var rat := originals[2]
	assert_eq(patroller.patrol_points.size(), 2, "patrol markers present")
	# Wave enemy: added after the level started.
	var wave := (load(BULL) as PackedScene).instantiate() as Enemy
	wave.position = Vector3(20, 0, 0)
	wave.make_always_aware()
	level.add_child(wave)
	await wait_frames(2)

	_kill(rat.health)
	bull.health.apply_damage(DamageInfo.create(30.0, bull.global_position))
	bull.global_position += Vector3(4, 0, 4)
	assert_true(bull.aware, "hit bull is aware")
	wave.health.apply_damage(DamageInfo.create(25.0, wave.global_position))
	var wave_hp := wave.health.current

	_kill(player.health)
	await wait_frames(2)
	assert_false(bull.has_target(), "aware enemies drop a dead player as target")
	var reset := await wait_until(func() -> bool: return not player.is_dead, Player.RESPAWN_DELAY + 1.0)
	assert_true(reset, "player respawned")
	await wait_frames(2)

	var fresh := level.placed_enemies()
	assert_eq(fresh.size(), 3, "every placed enemy is back (dead rat included)")
	for e: Enemy in fresh:
		assert_false(e.get_instance_id() in original_ids, "%s is a new instance" % e.name)
		assert_true(e.is_inside_tree() and not e.health.is_dead, "%s alive" % e.name)
		assert_near(e.health.current, e.health.max_health, 0.001, "%s at full health" % e.name)
		assert_false(e.aware, "%s unaware" % e.name)
		assert_eq(e.get_parent().name, &"Enemies", "%s back under its group" % e.name)
	assert_true(fresh[0].global_position.distance_to(Vector3(-6, 0, -10)) < 0.3, "bull back home, at %s" % fresh[0].global_position)
	assert_near(fresh[0].rotation.y, 0.5, 0.01, "bull home yaw")
	assert_eq(String(fresh[0].name), "Bull", "name kept")
	assert_near(fresh[1].max_health, 200.0, 0.001, "per-instance export kept")
	assert_eq(fresh[1].patrol_points.size(), 2, "patrol markers rebuilt")
	assert_true(fresh[2] is ClockworkRat, "rat respawned as a rat")
	assert_true(is_instance_valid(wave) and wave.is_inside_tree(), "wave enemy untouched")
	assert_near(wave.health.current, wave_hp, 0.001, "wave enemy keeps its damage")
	assert_true(wave.aware, "wave enemy stays aware")


func test_falling_off_does_not_reset_enemies() -> void:
	var level := _make_level()
	await wait_frames(3)
	var before := level.placed_enemies()
	level.player.respawn()
	await wait_frames(1)
	assert_eq(level.placed_enemies(), before, "kill-plane respawn keeps enemies")


func test_gadget_registry() -> void:
	var g := Gadgets.new()
	var seen: Array[StringName] = []
	g.unlocked_gadget.connect(func(id: StringName) -> void: seen.append(id))
	assert_false(g.has(Gadgets.GRAPPLE), "starts locked")
	assert_true(g.unlock(Gadgets.GRAPPLE), "unlock grapple")
	assert_false(g.unlock(Gadgets.GRAPPLE), "second unlock is a no-op")
	assert_true(g.has(&"grapple"), "has grapple")
	assert_false(g.has(&"glide"), "glide still locked")
	g.unlock_all()
	for id: StringName in Gadgets.ALL:
		assert_true(g.has(id), "%s unlocked" % id)
	assert_eq(seen.size(), Gadgets.ALL.size(), "one signal per new unlock")


func test_pause_menu_unlocks_all_gadgets_on_player() -> void:
	add_floor()
	var player := _make_player(Vector3(0, 0.05, 0))
	var menu := PauseMenu.new()
	add_child(menu)
	await wait_frames(2)
	assert_false(player.has_gadget(&"conduit"), "locked at start")
	menu.call(&"_on_unlock_gadgets")
	for id: StringName in Gadgets.ALL:
		assert_true(player.has_gadget(id), "%s unlocked from the menu" % id)


func test_gadget_gates_have_distinct_colours() -> void:
	var seen: Array[Color] = []
	for id: StringName in Gadgets.ALL:
		var gate := GadgetGate.new()
		gate.requires = id
		add_child(gate)
		var c := gate.call(&"_display_color") as Color
		assert_false(c in seen, "%s has its own colour" % id)
		seen.append(c)
		assert_true(gate.get_node_or_null(^"GateMarker") != null, "%s has a marker" % id)
		assert_eq(gate.collision_layer, Layers.WORLD, "gate is solid world geometry")
	await wait_frames(1)
	var player := _make_player(Vector3(0, 0.05, 0))
	var gate := get_child(0) as GadgetGate
	await wait_frames(1)
	assert_false(gate.is_open_for(player), "closed without the gadget")
	player.unlock_gadget(gate.requires)
	assert_true(gate.is_open_for(player), "open with it")


func test_level_select_lists_and_names_levels() -> void:
	var levels := LevelRoot.available_levels()
	assert_eq(levels[0], LevelRoot.ARENA_PATH, "arena first")
	assert_true(SLICE in levels, "slice_01 listed")
	assert_eq(LevelRoot.level_path("slice_01"), SLICE, "name -> path")
	assert_eq(LevelRoot.level_path("arena"), LevelRoot.ARENA_PATH, "arena alias")
	assert_eq(LevelRoot.level_name(SLICE), "slice_01", "path -> name")
	var menu := PauseMenu.new()
	menu.current_level_path = LevelRoot.ARENA_PATH
	add_child(menu)
	await wait_frames(1)
	var requested: Array[String] = []
	var restarts: Array[int] = [0]
	menu.level_requested.connect(func(p: String) -> void: requested.append(p))
	menu.restart_requested.connect(func() -> void: restarts[0] += 1)
	menu.open()
	menu.call(&"_on_restart")
	assert_eq(restarts[0], 1, "unchanged selection restarts")
	menu.open()
	while menu.selected_level_path() != SLICE:
		menu.call(&"_on_cycle_level")
	menu.call(&"_on_restart")
	assert_eq(requested, [SLICE] as Array[String], "cycled selection loads that level")
	assert_false(get_tree().paused, "unpaused")


func test_slice_scene_instantiates_as_a_level() -> void:
	var level := (load(SLICE) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await wait_frames(3)
	assert_true(level.player != null and level.player.is_inside_tree(), "player built")
	assert_true(level.wave_manager == null, "no wave manager needed")
	var spawn := level.get_node(^"PlayerSpawn") as Marker3D
	assert_true(level.player.global_position.distance_to(spawn.global_position) < 0.3, "player at PlayerSpawn")
	assert_true(level.placed.size() >= 1, "placed enemies recorded")
	for e: Enemy in level.placed_enemies():
		assert_false(e.aware, "%s placed unaware" % e.name)
	assert_true(get_tree().get_nodes_in_group(&"checkpoints").size() >= 1, "has a checkpoint")
