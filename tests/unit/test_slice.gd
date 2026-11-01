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


## GrappleLedge with real input from the run below it (T2Step, facing north):
## jump + double jump falls short; with the Grapple-Tail, jump then jump at the
## highlighted ring reels the fox up and lands it on top.
func test_grapple_ledge_needs_and_takes_the_grapple() -> void:
	var level := _load_level(true)
	var player := level.player
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	await wait_frames(3)
	var ledge := level.get_node(^"Level/Traversal/GrappleLedge") as GadgetGate
	var start_block := level.get_node(^"Level/Traversal/T2Step") as Block
	assert_true(ledge.ring != null, "the grapple gate has a ring")
	assert_false(await _ledge_attempt(player, pad, start_block, ledge), "jump + double jump can't reach the ledge")
	player.unlock_gadget(Gadgets.GRAPPLE)
	assert_true(await _ledge_attempt(player, pad, start_block, ledge), "the grapple reaches the ledge top")


## Stand on the start block's north half under the ledge, jump, press jump again
## near the apex (double jump, or grapple if a ring is highlighted), and report
## whether the fox ends up standing on the ledge's top face.
func _ledge_attempt(player: Player, pad: ScriptedInputProvider, from: Block, ledge: Block) -> bool:
	var r := _rect(from)
	var lr := _rect(ledge)
	player.global_position = Vector3(clampf(lr.get_center().x, r.position.x + 0.6, r.end.x - 0.6), _top(from) + 0.05, r.position.y + 1.0)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = 0.0  # north, at the ledge
	pad.next = PlayerInputState.new()
	await wait_frames(5)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	pad.next.move = Vector2(0, -1)
	var second := false
	for _f: int in 240:
		if not second and player.velocity.y <= 1.0 and not player.is_on_floor():
			second = true
			pad.next.jump_pressed = true
		await get_tree().physics_frame
		var p := player.global_position
		if second and player.is_on_floor() and lr.grow(-0.1).has_point(Vector2(p.x, p.z)) and absf(p.y - _top(ledge)) < 0.3:
			pad.next = PlayerInputState.new()
			return true
		if second and player.is_on_floor() and p.y < _top(ledge) - 1.0:
			break  # landed back on the run
	pad.next = PlayerInputState.new()
	return false


## GlideVent -> BeyondPlatform (19 m gap, 4 m lower) with real input: standing
## on the vent, jump + double jump and run south falls into the void; with the
## Leaf-wing Cloak, holding jump rides the updraft, then stick south glides
## across and letting go over the platform drops the fox onto it.
func test_glide_vent_needs_and_takes_the_glide() -> void:
	var level := _load_level(true)
	var player := level.player
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	await wait_frames(3)
	var gate := level.get_node(^"Level/Finale/GlideVent") as GadgetGate
	var beyond := level.get_node(^"Level/Finale/BeyondPlatform") as Block
	assert_true(gate.vent != null, "the glide gate has a steam vent")
	assert_false(await _glide_attempt(player, pad, gate, beyond), "jump + double jump can't cross")
	player.unlock_gadget(Gadgets.GLIDE)
	assert_true(await _glide_attempt(player, pad, gate, beyond), "the glide crosses to the platform")


func _glide_attempt(player: Player, pad: ScriptedInputProvider, gate: GadgetGate, beyond: Block) -> bool:
	player.global_position = gate.global_position + Vector3.UP * (gate.size.y * 0.5 + 0.05)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = PI  # south (+Z), at the platform
	pad.next = PlayerInputState.new()
	await wait_frames(5)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	var doubled := false
	var rect := _rect(beyond).grow(-3.0)
	var top: float = gate.global_position.y + gate.vent.lift_height * gate.vent.full_fraction
	for _f: int in 900:
		var p := player.global_position
		if not doubled and player.velocity.y <= 0.0 and not player.is_on_floor():
			doubled = true
			pad.next.jump_pressed = true
		# Ride the updraft (stick neutral) until near its top, then head south.
		if doubled and (p.y >= top or not player.is_gliding()):
			pad.next.move = Vector2(0, -1)
		if rect.has_point(Vector2(p.x, p.z)):
			pad.next.jump_held = false
		await get_tree().physics_frame
		p = player.global_position
		if player.is_on_floor() and _rect(beyond).has_point(Vector2(p.x, p.z)) and absf(p.y - _top(beyond)) < 0.3:
			pad.next = PlayerInputState.new()
			return true
		if p.y < _top(beyond) - 2.0 or (doubled and player.is_on_floor()):
			break
	pad.next = PlayerInputState.new()
	return false


## BurrowIn -> BurrowOut with real input: without the Burrow Claws a dodge on
## the soil is just a dodge (the divider stays between them); with them, dodge
## digs in, dodge tunnels under the divider and jump pops out on the south lane,
## past the fire plates, sweeper and hammer.
func test_burrow_patches_need_and_take_the_burrow() -> void:
	var level := _load_level(true)
	var player := level.player
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	await wait_frames(3)
	var gate_in := level.get_node(^"Level/Yard/BurrowIn") as GadgetGate
	var gate_out := level.get_node(^"Level/Yard/BurrowOut") as GadgetGate
	var divider := level.get_node(^"Level/Yard/Divider") as Block
	assert_true(gate_in.soil != null and gate_out.soil != null, "burrow gates have soil")
	assert_eq(gate_in.soil.partner(), gate_out.soil, "BurrowIn tunnels to BurrowOut")
	assert_eq(gate_out.soil.partner(), gate_in.soil, "and back")
	assert_true(_top(divider) - _top(gate_in) > LevelMetrics.STEP_MAX, "the divider is no step")
	assert_false(await _burrow_attempt(player, pad, gate_in, gate_out), "a dodge on the soil does not cross")
	player.unlock_gadget(Gadgets.BURROW)
	assert_true(await _burrow_attempt(player, pad, gate_in, gate_out), "the burrow crosses under the divider")


func _burrow_attempt(player: Player, pad: ScriptedInputProvider, from: GadgetGate, to: GadgetGate) -> bool:
	player.global_position = from.global_position + Vector3.UP * (from.size.y * 0.5 + 0.05)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = PI  # south, at the divider
	pad.next = PlayerInputState.new()
	await wait_frames(5)
	pad.next.dodge_pressed = true
	await wait_frames(1)
	var burrowed := await wait_until(func() -> bool: return player.burrow.is_under(), 1.0)
	if burrowed:
		pad.next.dodge_pressed = true  # tunnel
		await wait_frames(1)
		await wait_until(func() -> bool: return player.burrow.is_under(), 2.0)
		pad.next.jump_pressed = true  # pop out
		pad.next.jump_held = true
		await wait_frames(1)
		pad.next.jump_held = false
	await wait_until(func() -> bool: return player.is_on_floor() and not player.is_burrowed() and not player.is_dodging(), 2.0)
	await wait_frames(3)
	var p := player.global_position
	pad.next = PlayerInputState.new()
	return player.is_on_floor() and _rect(to).has_point(Vector2(p.x, p.z)) and absf(p.y - _top(to)) < 0.3


## Pocket A's optional ambush: a tunnel from the soil behind the cover by the
## fence to a patch right behind the resting bull, close enough to swing at it.
func test_ambush_tunnel_reaches_behind_the_bull() -> void:
	var level := _load_level()
	await wait_frames(2)
	var from := level.get_node(^"Level/PocketA/AmbushSoil") as SoilPatch
	var to := level.get_node(^"Level/PocketA/AmbushSoilBull") as SoilPatch
	var bull := level.get_node(^"Enemies/PocketA/Bull") as Enemy
	assert_eq(from.partner(), to, "linked")
	var behind := (to.global_position - bull.global_position).normalized()
	assert_true(behind.dot(bull.forward()) < -0.9, "the patch is behind the bull")
	var reach := Enemy._flat_distance(to.global_position, bull.global_position) - (to.radius - BurrowClaws.EDGE_MARGIN) - bull.extents().z * 0.5
	assert_true(reach < 1.5, "a swing from the patch edge reaches the bull (%.2f m)" % reach)
	assert_true(reach > Player.RADIUS, "but the patch is not under it (%.2f m)" % reach)
