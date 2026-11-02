extends TestCase
## slice_02: gadgets in combination, gravity rifts, the new enemies and the
## boss as a finale. Each gated step is crossed with real input (and shown to
## need its tool where that is testable).

const SLICE := "res://scenes/levels/slice_02.tscn"

var level: LevelRoot
var player: Player
var pad: ScriptedInputProvider


func _load(strip_enemies: bool = true) -> void:
	level = (load(SLICE) as PackedScene).instantiate() as LevelRoot
	if strip_enemies:
		var node := level.get_node(^"Enemies")
		level.remove_child(node)
		node.free()
	add_child(level)
	player = level.player
	pad = ScriptedInputProvider.new()
	player.input_provider = pad
	await wait_frames(3)


func _block(path: String) -> Block:
	return level.get_node(NodePath(path)) as Block


func _top(b: Block) -> float:
	return b.global_position.y + b.size.y * 0.5


func _place(at: Vector3, yaw: float) -> void:
	pad.next = PlayerInputState.new()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = yaw
	player.visual.rotation.y = yaw
	player.camera_rig.yaw = yaw
	await wait_frames(5)


func test_layout_beats_and_starting_gadgets() -> void:
	await _load(false)
	for id: StringName in Gadgets.ALL:
		assert_true(player.has_gadget(id), "starts with %s" % id)
	assert_eq(level.find_children("Checkpoint*", "", false).size(), 5, "five checkpoints")
	assert_eq(get_tree().get_nodes_in_group(&"bosses").size(), 1, "the stag waits at the end")
	var herons := level.find_children("*", "ChimeHeron", true, false)
	assert_eq(herons.size(), 1, "a heron in the choir")
	var door := level.get_node(^"Level/Choke/BossDoor") as GadgetGate
	assert_false(door.is_open_for(player), "the boss door starts shut")
	var terminal := level.get_node(^"Level/Choke/DoorTerminal") as ConduitTerminal
	assert_eq(terminal.target_node(), door, "terminal powers the door")
	var south := level.get_node(^"Level/Choke/SoilSouth") as SoilPatch
	assert_true(south.partner() != null, "burrow tunnel under the choke wall")


func test_cliff_needs_the_rift_lift() -> void:
	await _load()
	var floor_top := _top(_block("Level/Choir/Floor"))
	var terrace_top := _top(_block("Level/Cliff/Terrace"))
	assert_true(terrace_top - floor_top > LevelMetrics.GATE_LEDGE_MIN, "cliff too tall to jump (%.1f m)" % (terrace_top - floor_top))
	var lift := level.get_node(^"Level/Cliff/RiftLift") as GravityRift
	assert_true(lift.gravity_direction().is_equal_approx(Vector3.UP), "the lift pulls up")
	# Step into the lift's foot, ride it up, then push north onto the terrace.
	await _place(Vector3(lift.global_position.x, floor_top + 0.05, lift.global_position.z), 0.0)
	var up := await wait_until(func() -> bool: return player.global_position.y > terrace_top + 0.5, 4.0)
	assert_true(up, "floated above the terrace (y=%.1f)" % player.global_position.y)
	pad.next.move = Vector2(0, -1)
	var landed := await wait_until(func() -> bool: return player.is_on_floor() and absf(player.global_position.y - terrace_top) < 0.3, 3.0)
	assert_true(landed, "stepped onto the terrace (y=%.1f)" % player.global_position.y)


func test_pillar_needs_the_grapple() -> void:
	await _load()
	var pillar := level.get_node(^"Level/Skyway/Pillar") as GadgetGate
	var terrace := _block("Level/Cliff/Terrace")
	assert_true(pillar.ring != null, "a ring tops the pillar")
	var pillar_top := _top(pillar)
	assert_true(pillar_top - _top(terrace) > 3.7, "pillar above double-jump height")
	var edge_z := terrace.global_position.z - terrace.size.z * 0.5 + 1.0
	await _place(Vector3(0, _top(terrace) + 0.05, edge_z), 0.0)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	pad.next.move = Vector2(0, -1)
	var grappled := false
	for _f: int in 360:
		if not grappled and not player.is_on_floor() and player.grapple.is_ready():
			grappled = true
			pad.next.dodge_pressed = true
		await get_tree().physics_frame
		if player.is_on_floor() and absf(player.global_position.y - pillar_top) < 0.3:
			break
	pad.next = PlayerInputState.new()
	assert_true(grappled, "the ring highlighted from the terrace edge")
	assert_near(player.global_position.y, pillar_top, 0.3, "landed on the pillar top")


func test_glide_from_the_pillar_to_island_b() -> void:
	await _load()
	var pillar := level.get_node(^"Level/Skyway/Pillar") as GadgetGate
	var island := _block("Level/Skyway/IslandB")
	var gap := (pillar.global_position.z - pillar.size.z * 0.5) - (island.global_position.z + island.size.z * 0.5)
	assert_true(gap > LevelMetrics.GATE_GAP_MIN, "gap too wide to jump (%.1f m)" % gap)
	await _place(Vector3(0, _top(pillar) + 0.05, pillar.global_position.z), 0.0)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	pad.next.move = Vector2(0, -1)
	var doubled := false
	for _f: int in 600:
		if not doubled and player.velocity.y <= 0.0 and not player.is_on_floor():
			doubled = true
			pad.next.jump_pressed = true
		# Over the middle of the island: let go of the stick and the cloak to drop onto it.
		if player.global_position.z < island.global_position.z + 2.0:
			pad.next.move = Vector2.ZERO
			pad.next.jump_held = false
		await get_tree().physics_frame
		if player.is_on_floor() and player.global_position.y > _top(island) - 0.3:
			break
	pad.next = PlayerInputState.new()
	assert_near(player.global_position.y, _top(island), 0.3, "glided onto island B (z=%.1f)" % player.global_position.z)


func test_rift_current_carries_across_to_island_c() -> void:
	await _load()
	var b := _block("Level/Skyway/IslandB")
	var c := _block("Level/Choke/IslandC")
	var gap := (b.global_position.z - b.size.z * 0.5) - (c.global_position.z + c.size.z * 0.5)
	assert_true(gap > LevelMetrics.GATE_GAP_MIN, "gap too wide to jump (%.1f m)" % gap)
	var current := level.get_node(^"Level/Skyway/RiftCurrent") as GravityRift
	assert_true(current.gravity_direction().is_equal_approx(Vector3.FORWARD), "the current pulls north (-Z): %s" % current.gravity_direction())
	await _place(Vector3(0, _top(b) + 0.05, b.global_position.z - b.size.z * 0.5 + 1.5), 0.0)
	pad.next.move = Vector2(0, -1)
	var across := await wait_until(func() -> bool: return player.is_on_floor() and player.global_position.z < c.global_position.z + c.size.z * 0.5 - 0.5, 5.0)
	pad.next = PlayerInputState.new()
	assert_true(across, "the current carried the fox over (z=%.1f, y=%.1f)" % [player.global_position.z, player.global_position.y])
	assert_near(player.global_position.y, _top(c), 0.3, "standing on island C")


func test_boss_door_opens_with_a_conduit_charge() -> void:
	await _load()
	var door := level.get_node(^"Level/Choke/BossDoor") as GadgetGate
	var terminal := level.get_node(^"Level/Choke/DoorTerminal") as ConduitTerminal
	player.conduit.charges = 1
	terminal.conduit_struck(player.conduit, true)
	var open := await wait_until(func() -> bool: return door.is_open_for(player), 3.0)
	assert_true(open, "powered door opens into the arena")
