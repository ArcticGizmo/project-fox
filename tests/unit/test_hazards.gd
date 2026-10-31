extends TestCase
## Traps and hazards. Timings come from each hazard's exports.

const BULL := "res://scenes/enemies/brass_bull.tscn"


func before_each() -> void:
	add_floor()


func _add_hazard(h: Hazard, at: Vector3, yaw: float = 0.0) -> Hazard:
	h.position = at
	h.rotation.y = yaw
	add_child(h)
	return h


## A bull standing still (AI off) as a hazard damage sponge.
func _parked_bull(at: Vector3) -> Enemy:
	var bull := spawn_enemy(BULL, at)
	bull.set_physics_process(false)
	return bull


# --- Fire trap ------------------------------------------------------------------

func test_fire_trap_arms_on_step_then_burns_after_delay() -> void:
	var trap := _add_hazard(FireTrap.new(), Vector3.ZERO) as FireTrap
	var dummy := add_dummy_target(Vector3(0, 0.05, 0))
	await wait_until(func() -> bool: return trap.state == FireTrap.ARMED, 0.5)
	assert_eq(trap.state, FireTrap.ARMED, "stepping on the plate arms it")
	await wait_seconds(trap.arm_time - 0.1)
	assert_eq(trap.state, FireTrap.ARMED, "still arming just before arm_time")
	assert_eq(dummy.damage_taken(), 0.0, "no damage while the trap telegraphs")
	await wait_seconds(0.3)
	assert_eq(trap.state, FireTrap.BURNING, "erupts after arm_time")
	var armed_at := state_time_in_log(trap.state_log, "armed")
	var burn_at := state_time_in_log(trap.state_log, "burning")
	assert_near(burn_at - armed_at, trap.arm_time, 0.05, "arm delay")
	assert_true(dummy.damage_taken() >= trap.damage, "flame hurts whoever is on it")


func test_fire_trap_ignores_nearby_and_rearms_while_occupied() -> void:
	var trap := _add_hazard(FireTrap.new(), Vector3.ZERO) as FireTrap
	var dummy := add_dummy_target(Vector3(trap.plate_size + 1.0, 0.05, 0))
	await wait_seconds(0.3)
	assert_eq(trap.state, FireTrap.IDLE, "standing beside the plate does nothing")
	dummy.global_position = Vector3(0, 0.05, 0)
	var cycle := trap.arm_time + trap.burn_time + trap.cooldown_time
	await wait_seconds(cycle + 0.3)
	assert_eq(state_time_in_log(trap.state_log, "armed", 1) > 0.0, true, "re-arms after cooldown while still occupied: %s" % str(trap.state_log))


func test_fire_trap_burns_enemies_that_step_on_it() -> void:
	var trap := _add_hazard(FireTrap.new(), Vector3.ZERO) as FireTrap
	var bull := _parked_bull(Vector3.ZERO)
	await wait_until(func() -> bool: return trap.state == FireTrap.BURNING, trap.arm_time + 0.5)
	await wait_frames(3)
	assert_true(bull.health.current < bull.health.max_health, "enemy takes flame damage")
	assert_true(bull._burn_left > 0.0, "enemy is set alight")


# --- Lightning barrier ----------------------------------------------------------

func test_lightning_barrier_cycles_off_charging_on() -> void:
	var b := _add_hazard(LightningBarrier.new(), Vector3.ZERO) as LightningBarrier
	await wait_seconds(b.off_time + b.charge_time + b.on_time + 0.2)
	var charging_at := state_time_in_log(b.state_log, "charging")
	var on_at := state_time_in_log(b.state_log, "on")
	var off_again := state_time_in_log(b.state_log, "off", 1)
	assert_near(charging_at, b.off_time, 0.05, "starts charging after off_time")
	assert_near(on_at - charging_at, b.charge_time, 0.05, "charge duration")
	assert_near(off_again - on_at, b.on_time, 0.05, "on duration")


func test_lightning_charge_indicator_fills_before_it_fires() -> void:
	var b := _add_hazard(LightningBarrier.new(), Vector3.ZERO) as LightningBarrier
	await wait_until(func() -> bool: return b.state == LightningBarrier.CHARGING, b.off_time + 0.5)
	assert_true(b.charge < 0.1, "indicator starts empty, %.2f" % b.charge)
	await wait_seconds(b.charge_time * 0.5)
	assert_near(b.charge, 0.5, 0.1, "half charged halfway through")
	await wait_seconds(b.charge_time * 0.5 + 0.1)
	assert_eq(b.state, LightningBarrier.ON, "fires when full")
	assert_eq(b.charge, 1.0, "full while on")


func test_lightning_only_hurts_while_on_and_pushes_out_sideways() -> void:
	var b := _add_hazard(LightningBarrier.new(), Vector3.ZERO) as LightningBarrier
	var dummy := add_dummy_target(Vector3(1.0, 0.05, 0.1))
	var hits: Array[DamageInfo] = []
	b.hit_box.hit_landed.connect(func(_hb: HurtBox, info: DamageInfo) -> void: hits.append(info))
	await wait_seconds(b.off_time + b.charge_time - 0.1)
	assert_eq(dummy.damage_taken(), 0.0, "safe while off and charging")
	await wait_seconds(0.3)
	assert_true(dummy.damage_taken() >= b.damage, "zapped once it is on")
	if not hits.is_empty():
		var away := dummy.hurt_box.center() - hits[0].source_position
		assert_true(absf(away.x) < 0.01 and away.z > 0.0, "knockback is straight out of the barrier (+Z side), got %s" % str(away))


func test_lightning_staggers_enemies_and_phase_offset_delays_it() -> void:
	var b := LightningBarrier.new()
	b.phase_offset = 1.0
	_add_hazard(b, Vector3.ZERO)
	var bull := _parked_bull(Vector3(0, 0, 0))
	await wait_seconds(b.off_time + b.charge_time + 0.2)
	assert_eq(b.state, LightningBarrier.CHARGING, "phase offset holds it back")
	await wait_seconds(b.phase_offset)
	assert_eq(b.state, LightningBarrier.ON, "then fires")
	assert_true(bull.is_staggered(), "enemy caught in the arc is staggered")
	assert_true(bull.health.current < bull.health.max_health, "and damaged")
