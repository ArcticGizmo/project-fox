extends TestCase
## Burrow Claws (BurrowClaws + SoilPatch). A soil patch at the origin under the
## fox; expectations come from the "Burrow" group of PlayerTuning. Camera yaw 0
## looks down -Z; enemies with yaw PI face +Z (toward the fox from the north).

const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const BULL := "res://scenes/enemies/brass_bull.tscn"

var player: Player
var pad: ScriptedInputProvider
var patch: SoilPatch


func before_each() -> void:
	add_floor()
	patch = _add_patch(Vector3.ZERO)
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)


func _add_patch(at: Vector3, radius: float = 1.5) -> SoilPatch:
	var p := SoilPatch.new()
	p.position = at
	p.radius = radius
	add_child(p)
	return p


## Unlock, dodge on the patch and wait until fully under.
func _burrow() -> void:
	player.unlock_gadget(Gadgets.BURROW)
	pad.next.dodge_pressed = true
	await wait_frames(1)
	await wait_until(func() -> bool: return player.burrow.is_under(), 1.0)


func _pop() -> void:
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(1)
	pad.next.jump_held = false


func test_locked_dodge_on_soil_is_a_dodge() -> void:
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_true(player.is_dodging(), "dodges")
	assert_false(player.is_burrowed(), "no burrow without the gadget")
	assert_eq(player.burrow.patch, null, "no patch")


func test_dodge_off_soil_is_a_dodge() -> void:
	player.unlock_gadget(Gadgets.BURROW)
	player.global_position = Vector3(6, 0.05, 0)
	await wait_frames(3)
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_true(player.is_dodging(), "dodges")
	assert_false(player.is_burrowed(), "nothing to dig into")


func test_dodge_on_soil_burrows() -> void:
	await _burrow()
	assert_true(player.is_burrowed(), "burrowed")
	assert_eq(player.burrow.patch, patch, "under the patch")
	assert_false(player.is_dodging(), "the dive replaces the dodge")
	assert_true(player.is_hidden(), "hidden")
	assert_eq(player.collision_layer, 0, "no body to bump into")
	assert_true(player.hurt_box.invulnerable, "hurtbox off")
	await wait_frames(2)
	assert_false(player.visual.visible, "fox hidden under the soil")


func test_dodge_onto_soil_burrows() -> void:
	player.unlock_gadget(Gadgets.BURROW)
	player.global_position = Vector3(0, 0.05, 3.5)  # south of the patch, dodging north onto it
	await wait_frames(3)
	pad.next.move = Vector2(0, -1)
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_true(player.is_dodging(), "dodging toward the patch")
	var dug := await wait_until(func() -> bool: return player.is_burrowed(), player.tuning.dodge_duration + 0.1)
	assert_true(dug, "dug in on reaching the patch")


func test_underground_movement_stays_on_the_patch() -> void:
	await _burrow()
	pad.next.move = Vector2(1, 0)
	await wait_frames(20)
	var h := Vector3(player.velocity.x, 0, player.velocity.z)
	assert_true(h.length() <= player.tuning.burrow_move_speed + 0.01, "slow underground (%.2f)" % h.length())
	await wait_frames(90)
	var off := Vector2(player.global_position.x, player.global_position.z).length()
	assert_true(off <= patch.radius - BurrowClaws.EDGE_MARGIN + 0.01, "kept on the patch (%.2f m out)" % off)
	assert_true(off > patch.radius * 0.5, "but moved under it (%.2f m out)" % off)
	assert_true(player.is_burrowed(), "still burrowed")


func test_hidden_from_enemy_staring_at_it() -> void:
	await _burrow()
	var rat := spawn_enemy(RAT, Vector3(0, 0, -2.5), PI, 3, false)  # point blank, looking right at it
	await wait_seconds(2.0)
	assert_false(rat.aware, "not noticed")
	assert_near(rat.suspicion, 0.0, 0.001, "no suspicion")
	assert_false(rat.sees_target, "no sight")
	assert_true(rat.target_hidden, "knows nothing but that it's hidden (debug)")
	assert_eq(rat.state, Enemy.REST, "keeps resting")


func test_suspicion_drains_after_burrowing() -> void:
	player.unlock_gadget(Gadgets.BURROW)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -10), PI, 3, false)
	var seen := await wait_until(func() -> bool: return rat.suspicion > 0.3, 3.0)
	assert_true(seen, "rat grows suspicious")
	assert_false(rat.aware, "not yet aware")
	pad.next.dodge_pressed = true
	await wait_frames(2)
	var peak := rat.suspicion
	await wait_seconds(peak / rat.suspicion_decay + 0.5)
	assert_near(rat.suspicion, 0.0, 0.001, "suspicion drained")
	assert_false(rat.aware, "never alerted")


func test_aware_enemy_loses_track() -> void:
	var bull := spawn_enemy(BULL, Vector3(0, 0, -16), PI, 4)
	bull.forget_time = 6.0
	await wait_frames(20)
	assert_true(bull.aware and bull.has_target(), "bull hunting the fox")
	var dive_at := player.global_position
	await _burrow()
	await wait_frames(2)
	assert_false(bull.aware, "lost track")
	assert_eq(bull.state, Enemy.INVESTIGATE, "investigates")
	assert_true(Enemy._flat_distance(bull.investigate_point, dive_at) < 1.0, "where it last saw the fox")
	assert_false(bull.has_target(), "no target while hidden")
	await wait_seconds(Enemy.LOST_TRACK_SUSPICION / bull.suspicion_decay + 0.2)
	assert_near(bull.suspicion, 0.0, 0.001, "suspicion drains while it searches")
	assert_near(player.health.current, player.health.max_health, 0.01, "untouched")


func test_tunnel_to_partner() -> void:
	add_wall(Vector3(0, 1.5, -3.5), Vector3(8, 3, 0.5))
	var exit_patch := _add_patch(Vector3(0, 0, -7))
	patch.exit = patch.get_path_to(exit_patch)
	assert_eq(exit_patch.partner(), patch, "linked from either side")
	await _burrow()
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_eq(player.burrow.phase, BurrowClaws.Phase.TUNNEL, "tunnelling")
	var time := maxf(player.tuning.burrow_tunnel_min_time, 7.0 / player.tuning.burrow_tunnel_speed)
	await wait_seconds(time + 0.05)
	assert_true(player.burrow.is_under(), "arrived, still underground")
	assert_eq(player.burrow.patch, exit_patch, "under the partner")
	assert_true(exit_patch.contains(player.global_position), "at the partner (%s)" % player.global_position)
	await _pop()
	var landed := await wait_until(func() -> bool: return player.is_on_floor() and not player.is_burrowed(), 1.5)
	assert_true(landed, "popped out")
	assert_true(player.global_position.z < -4.0, "on the far side of the wall (%s)" % player.global_position)


func test_pop_out_hop() -> void:
	await _burrow()
	await _pop()
	assert_false(player.is_burrowed(), "out")
	assert_eq(player.collision_layer, Layers.PLAYER, "body back")
	assert_true(player.is_hidden(), "still concealed for a moment")
	assert_true(player.is_sneak_ready(), "sneak window open")
	var apex := 0.0
	for _i: int in 60:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	assert_near(apex, player.tuning.burrow_pop_hop_height, 0.15, "small hop (released jump does not cut it)")
	assert_true(player.is_on_floor(), "landed")
	assert_true(player.visual.visible, "fox visible")
	await wait_seconds(player.tuning.burrow_surface_conceal_time)
	assert_false(player.is_hidden(), "visible again")


func test_dodge_on_standalone_patch_pops_out() -> void:
	await _burrow()
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_false(player.is_burrowed(), "nowhere to tunnel: out")
	assert_true(player.velocity.y > 0.0, "with the hop")


func test_no_firing_or_staff_while_burrowed() -> void:
	await _burrow()
	var w := player.current_weapon()
	var ammo := w.ammo
	pad.next.fire_held = true
	pad.next.melee_pressed = true
	await wait_frames(20)
	pad.next.fire_held = false
	assert_eq(w.ammo, ammo, "no shots")
	assert_eq(player.melee.phase, StaffMelee.Phase.IDLE, "no staff")
	assert_true(player.is_burrowed(), "still burrowed")


func test_damage_ignored_while_burrowed() -> void:
	await _burrow()
	assert_false(player.hurt_box.receive(DamageInfo.create(30.0, player.global_position + Vector3(2, 0, 0), 8.0)), "hit rejected")
	assert_near(player.health.current, player.health.max_health, 0.01, "no damage")
	assert_true(player.is_burrowed(), "stays under")


## Pop out behind an unaware bull (point blank, but concealed) and swing: the
## first hit gets the sneak multiplier.
func test_sneak_attack_on_unaware_enemy() -> void:
	await _burrow()
	var bull := spawn_enemy(BULL, Vector3(0, 0, -2.6), 0.0, 5, false)  # facing away, north
	await wait_frames(5)
	assert_false(bull.aware, "bull unaware")
	await _pop()
	pad.next.melee_pressed = true  # during the hop: waits for the landing, then swings
	var before := bull.health.current
	var hit := await wait_until(func() -> bool: return bull.health.current < before, 1.0)
	assert_true(hit, "swing landed")
	assert_near(before - bull.health.current, player.tuning.melee_damage[0] * player.tuning.burrow_sneak_multiplier, 0.01, "sneak damage")
	assert_eq(player.melee.combo_index, 0, "a ground swing, not a slam")
	await wait_frames(2)
	assert_false(player.is_sneak_ready(), "the bonus is spent")
	assert_true(bull.aware, "and now it knows")


func test_sneak_window_expires() -> void:
	await _burrow()
	var bull := spawn_enemy(BULL, Vector3(0, 0, -2.6), 0.0, 5, false)
	bull.point_blank_range = 0.0  # stays unaware with the fox behind it
	await _pop()
	await wait_seconds(player.tuning.burrow_sneak_window + 0.1)
	assert_false(player.is_sneak_ready(), "window closed")
	assert_false(bull.aware, "bull still unaware")
	var before := bull.health.current
	pad.next.melee_pressed = true
	await wait_until(func() -> bool: return bull.health.current < before, 1.0)
	assert_near(before - bull.health.current, player.tuning.melee_damage[0], 0.01, "normal damage after the window")


func test_no_sneak_bonus_on_an_aware_enemy() -> void:
	await _burrow()
	var bull := spawn_enemy(BULL, Vector3(0, 0, -2.6), 0.0, 5)
	bull.set_physics_process(false)  # aware, but held still
	await _pop()
	assert_true(bull.aware and player.is_sneak_ready(), "aware bull, window open")
	pad.next.melee_pressed = true
	var before := bull.health.current
	await wait_until(func() -> bool: return bull.health.current < before, 1.0)
	assert_near(before - bull.health.current, player.tuning.melee_damage[0], 0.01, "no bonus on an aware enemy")


## A sneak kill doesn't set off the group alert (the victim never gets to alert).
func test_sneak_kill_does_not_wake_neighbours() -> void:
	await _burrow()
	var victim := spawn_enemy(RAT, Vector3(0, 0, -1.6), 0.0, 6, false)
	var neighbour := spawn_enemy(RAT, Vector3(4, 0, -4), 0.0, 7, false)  # sees the victim, facing away from the fox
	neighbour.point_blank_range = 0.0
	assert_true(victim.health.max_health <= player.tuning.melee_damage[0] * player.tuning.burrow_sneak_multiplier, "one sneak hit kills a rat")
	await wait_frames(5)
	await _pop()
	pad.next.melee_pressed = true
	var killed := await wait_until(func() -> bool: return not is_instance_valid(victim) or victim.health.is_dead, 1.0)
	assert_true(killed, "sneak hit kills")
	await wait_seconds(1.0)
	assert_false(neighbour.aware, "neighbour still unaware")
	assert_false(neighbour.is_alert_pending() or neighbour.state == Enemy.ALERT, "no group alert")


func test_death_digs_the_fox_out() -> void:
	await _burrow()
	player.health.apply_damage(DamageInfo.create(player.health.current + 1.0, player.global_position))
	await wait_frames(1)
	assert_false(player.is_burrowed(), "death digs the fox out")
	assert_eq(player.collision_layer, Layers.PLAYER, "body restored")
	await wait_seconds(Player.RESPAWN_DELAY + 0.1)
	assert_false(player.is_dead, "respawned")
	assert_false(player.is_hidden(), "not hidden after respawn")


func test_staff_pressed_with_the_pop_swings_on_landing() -> void:
	await _burrow()
	pad.next.jump_pressed = true
	pad.next.melee_pressed = true
	await wait_frames(1)
	assert_false(player.is_burrowed(), "popped out")
	assert_eq(player.melee.phase, StaffMelee.Phase.IDLE, "no slam in the hop")
	var swung := await wait_until(func() -> bool: return player.melee.phase == StaffMelee.Phase.SWING, 1.0)
	assert_true(swung, "the press became a swing on landing")
	assert_true(player.is_on_floor(), "on the ground")
