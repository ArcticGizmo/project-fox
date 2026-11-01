extends TestCase
## Copper Conduit Gauntlet (ConduitGauntlet, ConduitTerminal, ConduitSocket, the
## LightningBarrier absorb and the conduit GadgetGate door). The fox stands at
## the origin facing -Z; things to strike sit north of it. Expectations come
## from the "Conduit" group of PlayerTuning and the barrier's exports.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
## Fox-to-barrier-line distance for a swing: outside the arc (0.25 m half
## thickness + 0.45 m body + the 0.84 m swing lunge) but within the staff's reach.
const SWING_DISTANCE := 1.9

var player: Player
var pad: ScriptedInputProvider


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)


## A barrier across the fox's path, SWING_DISTANCE north, held in `state`.
func _add_barrier(state: StringName) -> LightningBarrier:
	var b := LightningBarrier.new()
	b.position = Vector3(0, 0, -SWING_DISTANCE)
	add_child(b)
	b.off_time = 100.0
	b.charge_time = 100.0
	b.on_time = 100.0
	b.enter_state(state)
	return b


func _add_terminal(at: Vector3 = Vector3(0, 0, -1.6)) -> ConduitTerminal:
	var t := ConduitTerminal.new()
	t.position = at
	add_child(t)
	return t


## A conduit door across the way north (4 m wide, 8 m tall) driven by `terminal`.
func _add_door(terminal: ConduitTerminal) -> GadgetGate:
	var door := GadgetGate.new()
	door.requires = Gadgets.CONDUIT
	door.size = Vector3(4, 8, 1)
	door.position = Vector3(0, 4, -6)
	add_child(door)
	terminal.target = terminal.get_path_to(door)
	return door


## One staff swing with real input; waits until it is over.
func _swing() -> void:
	pad.next.melee_pressed = true
	await wait_frames(1)
	await wait_until(func() -> bool: return not player.melee.is_busy(), 1.0)
	await wait_frames(2)


func _blocked_north(from_z: float, to_z: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 1, from_z), Vector3(0, 1, to_z), Layers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func test_live_barrier_charges_the_gauntlet() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var b := _add_barrier(LightningBarrier.ON)
	var hp := player.health.current
	assert_false(player.conduit.is_charged(), "starts empty")
	assert_false(player.conduit.crackle_visible(), "no glow while empty")
	await wait_frames(2)
	await _swing()
	assert_eq(player.conduit.charges, 1, "one charge stored")
	assert_eq(b.state, LightningBarrier.OFF, "the barrier is drained")
	assert_false(b.hit_box.active, "arc off")
	assert_near(player.health.current, hp, 0.01, "the absorbing swing doesn't hurt")
	await wait_frames(2)
	assert_true(player.conduit.crackle_visible(), "tip orb and crackle while charged")
	assert_true(player.melee.staff_material.emission.b > 0.2, "staff glows arc-blue")


func test_charging_barrier_absorbs_only_once_the_tubes_fill() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var b := _add_barrier(LightningBarrier.CHARGING)
	b.charge_time = 1.0
	b.state_time = b.absorb_min_charge * b.charge_time * 0.5
	await wait_frames(1)
	await _swing()
	assert_eq(player.conduit.charges, 0, "too early: nothing to catch (charge %.2f)" % b.charge)
	assert_eq(b.state, LightningBarrier.CHARGING, "still charging")
	b.charge_time = 100.0
	b.state_time = b.absorb_min_charge * 100.0 + 5.0
	await wait_frames(1)
	await _swing()
	assert_eq(player.conduit.charges, 1, "caught it while charging")
	assert_eq(b.state, LightningBarrier.OFF, "drained before it went live")


func test_off_barrier_gives_no_charge() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var b := _add_barrier(LightningBarrier.OFF)
	await wait_frames(2)
	await _swing()
	assert_eq(player.conduit.charges, 0, "nothing to absorb")
	assert_false(player.conduit.crackle_visible(), "no glow")


func test_locked_swing_absorbs_nothing_and_the_arc_still_hurts() -> void:
	var b := _add_barrier(LightningBarrier.ON)
	await wait_frames(2)
	await _swing()
	assert_eq(player.conduit.charges, 0, "no gauntlet, no charge")
	assert_eq(b.state, LightningBarrier.ON, "barrier keeps arcing")
	assert_false(player.conduit.cuff_visible(), "no copper cuff without the gadget")
	var hp := player.health.current
	player.global_position = Vector3(0, 0.05, -SWING_DISTANCE)  # in the arc
	await wait_frames(3)
	assert_near(player.health.current, hp - b.damage, 0.01, "normal barrier damage")


func test_full_gauntlet_leaves_the_barrier_alone() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var b := _add_barrier(LightningBarrier.ON)
	player.conduit.charges = player.tuning.conduit_max_charges
	await wait_frames(2)
	await _swing()
	assert_eq(player.conduit.charges, player.tuning.conduit_max_charges, "no overcharge")
	assert_eq(b.state, LightningBarrier.ON, "not drained")


func test_only_the_staff_swing_reaches_sockets() -> void:
	var b := _add_barrier(LightningBarrier.ON)
	assert_eq(b.socket.collision_layer, Layers.CONDUCTOR, "socket on CONDUCTOR")
	assert_true(player.melee.hit_box.collision_mask & Layers.CONDUCTOR != 0, "the staff swing masks it")
	assert_eq(player.melee.slam_box.collision_mask & Layers.CONDUCTOR, 0, "the slam doesn't")
	assert_eq(Hazard.HIT_MASK & Layers.CONDUCTOR, 0, "hazards don't")
	assert_eq(b.hit_box.collision_mask & Layers.CONDUCTOR, 0, "the arc itself doesn't")
	var bull := spawn_enemy(BULL, Vector3(4, 0, -4))
	for hb: HitBox in bull.find_children("*", "HitBox", true, false):
		assert_eq(hb.collision_mask & Layers.CONDUCTOR, 0, "enemy %s doesn't" % hb.name)
	assert_true(b.socket.get_node_or_null(^"DebugOutline") != null, "socket has a debug outline")


func test_terminal_without_charge_clanks() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var t := _add_terminal()
	var door := _add_door(t)
	var clanks := [0]
	t.clanked.connect(func() -> void: clanks[0] += 1)
	await wait_frames(2)
	await _swing()
	assert_eq(clanks[0], 1, "a dull clank")
	assert_false(t.is_powered, "stays dead")
	assert_false(door.is_open, "door shut")


func test_locked_gauntlet_cannot_spend_a_charge() -> void:
	var t := _add_terminal()
	player.conduit.charges = 1  # e.g. the gadget got locked again (debug)
	await wait_frames(2)
	await _swing()
	assert_false(t.is_powered, "no gadget, no power")
	assert_eq(player.conduit.charges, 1, "charge untouched")


func test_charged_swing_powers_the_terminal_and_opens_the_door() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var t := _add_terminal()
	var door := _add_door(t)
	var powered := [0]
	t.powered.connect(func() -> void: powered[0] += 1)
	player.conduit.charges = 1
	await wait_frames(2)
	assert_true(_blocked_north(-4.0, -8.0), "door blocks the way")
	assert_false(door.is_open_for(player), "closed even with the gadget")
	var top := door.position.y
	await _swing()
	assert_true(t.is_powered, "terminal powered")
	assert_eq(powered[0], 1, "powered signal once")
	assert_eq(player.conduit.charges, 0, "charge spent")
	assert_true(door.is_open and door.is_open_for(player), "door opening")
	await wait_seconds(GadgetGate.DOOR_OPEN_TIME + 0.5)
	assert_true(door.is_fully_open(), "door fully open")
	assert_true(door.position.y + door.size.y * 0.5 <= top - door.size.y * 0.5 + 0.01, "sunk into the floor (y %.2f from %.2f)" % [door.position.y, top])
	await wait_frames(2)
	assert_false(_blocked_north(-4.0, -8.0), "collision followed the door")
	await _swing()
	assert_eq(powered[0], 1, "a powered terminal stays powered (no second signal)")


func test_charge_lasts_until_spent_but_not_through_death() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	player.conduit.charges = 1
	await wait_seconds(5.0)
	assert_eq(player.conduit.charges, 1, "no timeout")
	player.health.apply_damage(DamageInfo.create(9999.0, Vector3.ZERO))
	await wait_frames(1)
	assert_eq(player.conduit.charges, 0, "lost on death")


func test_charged_swing_on_an_enemy_chains_and_staggers() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -2.6), 0.0, 3)
	var rat_near := spawn_enemy(RAT, Vector3(3.5, 0, -4.5), 0.0, 4)
	var rat_far := spawn_enemy(RAT, Vector3(-20, 0, -20), 0.0, 5)
	for e: Enemy in [bull, rat_near, rat_far]:
		e.set_physics_process(false)
	player.conduit.charges = 1
	await wait_frames(3)
	var bull_hp := bull.health.current
	var rat_hp := rat_near.health.current
	await _swing()
	assert_eq(player.conduit.charges, 0, "discharged")
	assert_eq(player.conduit.last_chain.size(), 2, "bull, then the near rat")
	assert_eq(player.conduit.last_chain[0], bull, "starts at the enemy hit")
	assert_true(bull.is_staggered() and rat_near.is_staggered(), "both staggered")
	assert_false(rat_far.is_staggered(), "out of chain range")
	assert_true(bull_hp - bull.health.current >= player.tuning.conduit_chain_damage + 1.0, "staff + chain damage on the bull")
	assert_near(rat_hp - rat_near.health.current, player.tuning.conduit_chain_damage, 0.01, "chain damage on the rat")


func test_uncharged_swing_on_an_enemy_does_not_chain() -> void:
	player.unlock_gadget(Gadgets.CONDUIT)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -2.6), 0.0, 3)
	bull.set_physics_process(false)
	await wait_frames(3)
	await _swing()
	assert_true(player.conduit.last_chain.is_empty(), "no chain without a charge")
	assert_false(bull.is_staggered(), "a plain staff hit")
