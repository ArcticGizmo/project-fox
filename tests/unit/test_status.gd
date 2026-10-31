extends TestCase
## Enemy status effects: chill/freeze, root, stagger, exposed, poison, lures.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"


func before_each() -> void:
	add_floor()


func _damage(e: Enemy) -> float:
	return e.health.max_health - e.health.current


func test_chill_slows_then_freezes() -> void:
	var rat := spawn_enemy(RAT, Vector3(0, 0, -10))
	await wait_frames(2)
	rat.add_chill(0.5, 2.0)
	assert_near(rat.move_multiplier(), 1.0 - 0.5 * Enemy.CHILL_MAX_SLOW, 0.001, "half chill slows")
	assert_near(rat.ai_speed(), rat.move_multiplier(), 0.001, "AI clock slows too")
	await wait_frames(1)
	assert_false(rat.ice_block.visible, "no ice block while only chilled")
	rat.add_chill(0.5, 2.0)
	assert_true(rat.is_frozen(), "full chill freezes")
	assert_eq(rat.move_multiplier(), 0.0, "frozen enemies don't move")
	await wait_frames(1)
	assert_true(rat.ice_block.visible, "frozen enemies are encased in ice")


func test_frozen_pauses_ai_takes_bonus_damage_and_thaws() -> void:
	add_dummy_target(Vector3.ZERO)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -12), PI) as BrassBull
	var charging := await wait_until(func() -> bool: return bull.state == &"charge", 4.0)
	assert_true(charging, "bull charging")
	bull.freeze(2.0)
	await wait_frames(2)
	assert_false(bull.horn_box.active, "freezing cancels the charge hitbox")
	assert_near(Vector3(bull.velocity.x, 0, bull.velocity.z).length(), 0.0, 0.01, "stopped dead")
	var t := bull.state_time
	await wait_seconds(0.5)
	assert_eq(bull.state_time, t, "AI clock paused while frozen")
	bull.hurt_box.receive(DamageInfo.create(10.0, Vector3.ZERO))
	assert_near(_damage(bull), 10.0 * Enemy.FROZEN_DAMAGE_MULTIPLIER, 0.01, "frozen bonus damage")
	# Bull resistance 0.5 halves the 2s freeze.
	await wait_seconds(0.6)
	assert_false(bull.is_frozen(), "thawed after the resisted duration")
	assert_eq(bull.chill, 0.0, "chill cleared on thaw")
	await wait_frames(2)
	assert_false(bull.ice_block.visible, "ice block gone on thaw")
	assert_ne_state(bull, &"charge")


func assert_ne_state(e: Enemy, s: StringName) -> void:
	assert_true(e.state != s, "resumed in a fresh state, not %s" % s)


func test_root_stops_movement_but_not_the_ai() -> void:
	add_dummy_target(Vector3.ZERO)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -10), PI)
	await wait_frames(2)
	rat.root(1.0)
	var start := rat.global_position
	var t := rat.state_time
	await wait_seconds(0.5)
	assert_true(rat.global_position.distance_to(start) < 0.05, "rooted rat stays put")
	assert_true(rat.state_time > t, "but its AI keeps running")
	await wait_seconds(0.7)
	assert_true(rat.global_position.distance_to(start) > 0.5, "moves again after the root")


func test_stagger_interrupts_and_resumes() -> void:
	add_dummy_target(Vector3.ZERO)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -9), PI) as ClockworkRat
	var winding := await wait_until(func() -> bool: return rat.state == &"windup", 6.0)
	assert_true(winding, "rat winding up a lunge")
	rat.stagger(0.5)
	await wait_frames(2)
	assert_true(rat.is_staggered(), "staggered")
	assert_eq(rat.telegraph, 0.0, "telegraph cancelled")
	var log_size := rat.state_log.size()
	await wait_seconds(0.55)
	assert_true(rat.state_log.size() > log_size, "state changed after the stagger")
	if rat.state_log.size() > log_size:
		assert_eq(rat.state_log[log_size].split("@")[0], String(rat._state_after_flinch()), "resumes from a neutral state")


func test_exposed_and_resistance_zero_immunity() -> void:
	var bull := spawn_enemy(BULL, Vector3(0, 0, -6))
	await wait_frames(2)
	bull.expose(2.0)
	bull.hurt_box.receive(DamageInfo.create(10.0, Vector3.ZERO))
	assert_near(_damage(bull), 10.0 * Enemy.EXPOSED_DAMAGE_MULTIPLIER, 0.01, "exposed bonus damage")
	bull.status_resistance = 0.0
	bull.add_chill(1.0, 2.0)
	bull.root(2.0)
	bull.stagger(2.0)
	assert_false(bull.is_frozen() or bull.is_rooted() or bull.is_staggered(), "resistance 0 is immune")


func test_poison_stacks_ticks_and_expires() -> void:
	var bull := spawn_enemy(BULL, Vector3(0, 0, -6))
	await wait_frames(2)
	bull.add_poison(2, null)
	await wait_seconds(2.1)  # 4 ticks at 0.5s (+ margin for float accumulation)
	assert_near(_damage(bull), 2 * Enemy.POISON_DPS_PER_STACK * 2.0, 0.6, "2 stacks for 2s")
	bull.add_poison(100, null)
	assert_eq(bull.poison_stacks, Enemy.POISON_MAX_STACKS, "stacks cap")
	await wait_seconds(Enemy.POISON_DURATION + 0.1)
	assert_eq(bull.poison_stacks, 0, "poison wears off")


func test_contagious_poison_spreads_on_death() -> void:
	var carrier := spawn_enemy(RAT, Vector3(0, 0, -6))
	var neighbour := spawn_enemy(BULL, Vector3(2.5, 0, -6))
	var far := spawn_enemy(BULL, Vector3(15, 0, -6))
	await wait_frames(2)
	carrier.add_poison(4, null, true)
	carrier.hurt_box.receive(DamageInfo.create(999.0, Vector3.ZERO))
	assert_eq(neighbour.poison_stacks, 2, "half the stacks jump to a neighbour")
	assert_eq(far.poison_stacks, 0, "out of range")


func test_lure_overrides_player_target() -> void:
	var dummy := add_dummy_target(Vector3.ZERO)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -10), PI)
	var malformed := Node3D.new()
	malformed.add_to_group(&"lures")
	add_child(malformed)
	var out_of_range := TestLure.new()
	out_of_range.lure_radius = 2.0
	out_of_range.position = Vector3(6, 0, -10)
	add_child(out_of_range)
	await wait_frames(2)
	assert_eq(rat.target, dummy, "malformed and out-of-range lures are ignored")
	var real_lure := TestLure.new()
	real_lure.position = Vector3(6, 0, -10)
	add_child(real_lure)
	await wait_frames(2)
	assert_eq(rat.target, real_lure, "lure in range wins")
	real_lure.queue_free()
	await wait_frames(2)
	assert_eq(rat.target, dummy, "back to the player when the lure is gone")


class TestLure extends Node3D:
	var lure_radius: float = 20.0

	func _ready() -> void:
		add_to_group(&"lures")
