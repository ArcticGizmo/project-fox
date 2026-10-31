extends TestCase
## The greybox slice (scenes/levels/slice_01.tscn): beats, gates, checkpoints,
## and the critical path. Path Blocks are in group "critical_path" with a
## `path_index` meta in walking order; every step between them must sit inside
## LevelMetrics (which test_jump_metrics checks against real jumps), and each
## jump is also made for real with the level's player and scripted input.

const SLICE := "res://scenes/levels/slice_01.tscn"
const PATH_GROUP := &"critical_path"


func _load_level(strip_actors: bool = false) -> LevelRoot:
	var level := (load(SLICE) as PackedScene).instantiate() as LevelRoot
	if strip_actors:
		for n: String in ["Enemies", "Hazards"]:
			var node := level.get_node(n)
			level.remove_child(node)
			node.free()
	add_child(level)
	return level


func _path_blocks() -> Array[Block]:
	var out: Array[Block] = []
	for n: Node in get_tree().get_nodes_in_group(PATH_GROUP):
		out.append(n as Block)
	out.sort_custom(func(a: Block, b: Block) -> bool: return int(a.get_meta(&"path_index")) < int(b.get_meta(&"path_index")))
	return out


static func _top(b: Block) -> float:
	return b.global_position.y + b.size.y * 0.5


## Top face as a flat rect (x, z, width, depth).
static func _rect(b: Block) -> Rect2:
	return Rect2(b.global_position.x - b.size.x * 0.5, b.global_position.z - b.size.z * 0.5, b.size.x, b.size.z)


## Edge-to-edge horizontal distance between two top faces (0 when touching).
static func _gap(a: Block, b: Block) -> float:
	var ra := _rect(a)
	var rb := _rect(b)
	var dx := maxf(0.0, maxf(ra.position.x - rb.end.x, rb.position.x - ra.end.x))
	var dz := maxf(0.0, maxf(ra.position.y - rb.end.y, rb.position.y - ra.end.y))
	return Vector2(dx, dz).length()


func _enemies_in(level: LevelRoot, group: String) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e: Enemy in level.placed_enemies():
		if e.get_parent().name == StringName(group):
			out.append(e)
	return out


func _has_type(list: Array[Enemy], script: Script) -> bool:
	return list.any(func(e: Enemy) -> bool: return e.get_script() == script)


func test_slice_beats_gates_and_checkpoints() -> void:
	var level := _load_level()
	await wait_frames(3)
	assert_true(level.wave_manager == null, "no wave manager")
	assert_eq(get_tree().get_nodes_in_group(&"checkpoints").size(), 3, "checkpoints after beats 2, 4 and 5")
	var gates: Dictionary = {}
	for n: Node in level.find_children("*", "GadgetGate", true, false):
		gates[(n as GadgetGate).requires] = true
	for id: StringName in Gadgets.ALL:
		assert_true(gates.has(id), "a %s gate in the slice" % id)
	for e: Enemy in level.placed_enemies():
		assert_false(e.aware, "%s starts unaware" % e.name)

	var pocket_a := _enemies_in(level, "PocketA")
	assert_true(_has_type(pocket_a, BrassBull), "pocket A has a bull")
	assert_true(pocket_a.filter(func(e: Enemy) -> bool: return e is ClockworkRat and e.wander_radius > 0.0).size() >= 2, "pocket A has wandering rats")
	var yard := _enemies_in(level, "Yard")
	assert_true(yard.any(func(e: Enemy) -> bool: return not e.patrol_points.is_empty()), "a patrol walks the hazard yard")
	var pocket_b := _enemies_in(level, "PocketB")
	assert_true(_has_type(pocket_b, SpitterToad) and _has_type(pocket_b, BombardierGull), "pocket B has toads and gulls")
	for e: Enemy in pocket_b:
		if e is SpitterToad:
			assert_true(e.global_position.y > 2.0, "%s up on a platform" % e.name)
	assert_true(_has_type(_enemies_in(level, "Ridge"), BrassFalcon), "falcons on the ridge")
	var finale := _enemies_in(level, "Finale")
	for s: Script in [ClockworkRat, BrassBull, SpitterToad, BombardierGull, BrassFalcon]:
		assert_true(_has_type(finale, s), "finale has a %s" % s.get_global_name())


func test_critical_path_within_jump_limits() -> void:
	var level := _load_level()
	await wait_frames(1)
	var path := _path_blocks()
	assert_true(path.size() >= 10, "critical path marked (%d blocks)" % path.size())
	for i: int in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var gap := _gap(a, b)
		var rise := _top(b) - _top(a)
		var label := "%s -> %s (gap %.2f, rise %.2f)" % [a.name, b.name, gap, rise]
		assert_true(gap <= LevelMetrics.GAP_MAX, "gap within a double jump: " + label)
		assert_true(rise <= LevelMetrics.LEDGE_MAX, "ledge within a double jump: " + label)
		if gap > LevelMetrics.SINGLE_GAP_MAX:
			assert_true(rise <= 0.0, "no climbing across a double-jump gap: " + label)
		elif gap > 0.05:
			assert_true(rise <= LevelMetrics.STEP_MAX, "only steps across a gap: " + label)
	# Gated spots must really need their gadget.
	var ledge := level.get_node(^"Level/Traversal/GrappleLedge") as GadgetGate
	for b: Block in path:
		if _gap(b, ledge) < LevelMetrics.GATE_GAP_MIN:
			assert_true(_top(ledge) - _top(b) >= LevelMetrics.GATE_LEDGE_MIN, "grapple ledge out of reach from %s" % b.name)
	var finale := level.get_node(^"Level/Finale/Floor") as Block
	var beyond := level.get_node(^"Level/Finale/BeyondPlatform") as Block
	assert_true(_gap(finale, beyond) >= LevelMetrics.GATE_GAP_MIN, "next area is a glide away (%.1f m)" % _gap(finale, beyond))


## Every jump on the critical path, made for real: run at it from the previous
## block, jump as the fox's centre passes the edge (or ~1 m before a wall), and
## double jump at the apex when a single jump is not meant to be enough.
func test_critical_path_jumps_with_real_input() -> void:
	var level := _load_level(true)
	var player := level.player
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	await wait_frames(3)
	var path := _path_blocks()
	var tried := 0
	for i: int in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var gap := _gap(a, b)
		var rise := _top(b) - _top(a)
		if gap < 0.05 and rise < 0.3:
			continue  # walk across or drop down
		tried += 1
		var needs_double := gap > LevelMetrics.SINGLE_GAP_MAX or rise > LevelMetrics.STEP_MAX
		var ok := await _jump_trial(player, pad, a, b, gap, needs_double)
		assert_true(ok, "made the jump %s -> %s (gap %.2f, rise %.2f)" % [a.name, b.name, gap, rise])
	assert_true(tried >= 6, "tried the path's jumps (%d)" % tried)


func _jump_trial(player: Player, pad: ScriptedInputProvider, a: Block, b: Block, gap: float, double: bool) -> bool:
	var ra := _rect(a)
	var rb := _rect(b)
	# Travel along whichever axis separates the two tops; line up on their overlap.
	var along_x := rb.position.x >= ra.end.x - 0.01 or rb.end.x <= ra.position.x + 0.01
	if gap < 0.05:
		along_x = absf(rb.get_center().x - ra.get_center().x) > absf(rb.get_center().y - ra.get_center().y)
	var dir := 1.0
	var start := Vector3.ZERO
	var edge: float
	var face: float
	if along_x:
		dir = signf(rb.get_center().x - ra.get_center().x)
		var lateral := (maxf(ra.position.y, rb.position.y) + minf(ra.end.y, rb.end.y)) * 0.5
		edge = ra.end.x if dir > 0.0 else ra.position.x
		face = rb.position.x if dir > 0.0 else rb.end.x
		start = Vector3(clampf(edge - dir * 4.0, ra.position.x + 0.6, ra.end.x - 0.6), _top(a) + 0.05, lateral)
	else:
		dir = signf(rb.get_center().y - ra.get_center().y)
		var lateral := (maxf(ra.position.x, rb.position.x) + minf(ra.end.x, rb.end.x)) * 0.5
		edge = ra.end.y if dir > 0.0 else ra.position.y
		face = rb.position.y if dir > 0.0 else rb.end.y
		start = Vector3(lateral, _top(a) + 0.05, clampf(edge - dir * 4.0, ra.position.y + 0.6, ra.end.y - 0.6))
	var heading := Vector3(dir, 0, 0) if along_x else Vector3(0, 0, dir)
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = atan2(-heading.x, -heading.z)
	pad.next = PlayerInputState.new()
	await wait_frames(3)
	var jumped := false
	var doubled := not double
	var apex := -INF
	for _f: int in 150:
		var p := player.global_position
		var along := p.x if along_x else p.z
		pad.next.move = Vector2(0, -1)
		if not jumped:
			var at_edge := (along - edge) * dir >= 0.0 if gap >= 0.05 else (face - along) * dir <= 1.0
			if at_edge:
				jumped = true
				pad.next.jump_pressed = true
				pad.next.jump_held = true
		else:
			apex = maxf(apex, p.y)
			if not doubled and player.velocity.y <= 0.0:
				doubled = true
				pad.next.jump_pressed = true
		await get_tree().physics_frame
		p = player.global_position
		var inside := rb.grow(-0.1).has_point(Vector2(p.x, p.z))
		if jumped and player.is_on_floor() and inside and absf(p.y - _top(b)) < 0.3:
			pad.next = PlayerInputState.new()
			return true
	pad.next = PlayerInputState.new()
	return false


## With the player idling on the landing pad (the safe zone) nobody notices, and
## placed enemies keep to their homes: patrols survive the hazard yard,
## wanderers don't stray, nobody falls off a platform.
func test_pad_is_safe_and_enemies_keep_home() -> void:
	var level := _load_level()
	level.player.input_provider = ScriptedInputProvider.new()
	await wait_seconds(20.0)
	for e: Enemy in level.placed_enemies():
		assert_false(e.health.is_dead, "%s alive" % e.name)
		assert_near(e.health.current, e.health.max_health, 0.01, "%s unhurt" % e.name)
		var reach := e.wander_radius + 1.5
		for p: Vector3 in e.patrol_points:
			reach = maxf(reach, Vector2(p.x - e.home_position.x, p.z - e.home_position.z).length() + 1.5)
		var off := Vector2(e.global_position.x - e.home_position.x, e.global_position.z - e.home_position.z).length()
		assert_true(off <= reach, "%s within %.1f m of home (%.1f)" % [e.name, reach, off])
		assert_true(e.global_position.y > e.home_position.y - 0.5, "%s still on its floor" % e.name)
		assert_false(e.aware or e.state == Enemy.SUSPICIOUS or e.state == Enemy.ALERT, "%s ignores the pad (%s)" % [e.name, e.state])
	assert_true(level.player.health.current >= level.player.health.max_health, "untouched on the pad")
