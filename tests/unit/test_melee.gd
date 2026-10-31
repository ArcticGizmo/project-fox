extends TestCase
## Staff combo, slam and pounce driven by scripted input. Expectations derive
## from PlayerTuning so retuning does not break the tests.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"

var player: Player
var pad: ScriptedInputProvider
var swings: Array[int] = []
var slams: int = 0


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	player.melee.swung.connect(func(i: int) -> void: swings.append(i))
	player.melee.slammed.connect(func(_at: Vector3) -> void: slams += 1)
	await wait_frames(10)


## A sturdy, stationary target in front of the fox (-Z).
func _frozen_enemy(path: String, at: Vector3) -> Enemy:
	var e := spawn_enemy(path, at, PI)
	await wait_frames(2)
	e.set_physics_process(false)
	return e


func _damage(e: Enemy) -> float:
	return e.health.max_health - e.health.current


func test_three_hit_combo_chains_with_buffered_presses() -> void:
	var bull := await _frozen_enemy(BULL, Vector3(0, 0, -2.4))
	for _i: int in 3:
		pad.next.melee_pressed = true
		await wait_seconds(0.15)
	await wait_seconds(0.8)
	assert_eq(swings, [0, 1, 2] as Array[int], "combo order")
	var t := player.tuning
	assert_near(_damage(bull), t.melee_damage[0] + t.melee_damage[1] + t.melee_damage[2], 0.01, "each swing hit once")
	assert_false(player.melee.is_busy(), "combo finished")


func test_mashing_never_overruns_the_combo() -> void:
	for _i: int in 8:
		pad.next.melee_pressed = true
		await wait_frames(3)
	await wait_seconds(1.5)
	assert_eq(swings, [0, 1, 2] as Array[int], "extra presses are dropped after the finisher")
	assert_false(player.melee.is_busy(), "returns to idle")


func test_combo_resets_after_pause() -> void:
	pad.next.melee_pressed = true
	await wait_seconds(1.0)
	pad.next.melee_pressed = true
	await wait_frames(2)
	assert_eq(swings, [0, 0] as Array[int], "late press restarts the combo")


func test_press_within_grace_continues_combo() -> void:
	pad.next.melee_pressed = true
	await wait_seconds(player.tuning.melee_swing_time[0] + 0.1)
	assert_false(player.melee.is_busy(), "first swing over")
	pad.next.melee_pressed = true
	await wait_frames(2)
	assert_eq(swings, [0, 1] as Array[int], "grace window chains")


func test_swing_snaps_toward_nearby_enemy() -> void:
	await _frozen_enemy(RAT, Vector3(2.5, 0, -1.5))
	pad.next.melee_pressed = true
	await wait_frames(2)
	var to := Vector3(2.5, 0, -1.5) - player.global_position
	assert_near(player.facing_yaw, Player.yaw_of(to), 0.15, "faces the rat")


func test_dodge_cancels_swing_and_firing_is_blocked() -> void:
	var w := player.current_weapon()
	var ammo := w.ammo
	pad.next.melee_pressed = true
	pad.next.fire_held = true
	await wait_frames(3)
	assert_true(player.melee.is_busy(), "swinging")
	assert_eq(w.ammo, ammo, "no shots while swinging")
	pad.next.fire_held = false
	pad.next.dodge_pressed = true
	await wait_frames(2)
	assert_false(player.melee.is_busy(), "dodge cancelled the swing")
	assert_true(player.is_dodging(), "dodging")


func test_ground_slam_hits_area_on_landing() -> void:
	var rat := await _frozen_enemy(RAT, Vector3(2.5, 0, 0))
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_seconds(0.3)
	pad.next.melee_pressed = true
	var landed := await wait_until(func() -> bool: return slams > 0, 2.0)
	assert_true(landed, "slam landed")
	assert_near(player.global_position.x, 0.0, 0.05, "neutral slam goes straight down")
	await wait_frames(3)
	assert_near(_damage(rat), minf(player.tuning.slam_damage, rat.max_health), 0.01, "rat inside slam radius takes slam damage")


func test_pounce_launches_forward_and_slams() -> void:
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_seconds(0.25)
	pad.next.move = Vector2(0, -1)
	pad.next.melee_pressed = true
	var landed := await wait_until(func() -> bool: return slams > 0, 3.0)
	assert_true(landed, "pounce ended in a slam")
	assert_true(player.global_position.z < -6.0, "long-jump distance, z=%.2f" % player.global_position.z)


func test_pounce_can_be_disabled() -> void:
	player.tuning = player.tuning.duplicate() as PlayerTuning
	player.tuning.pounce_enabled = false
	player.melee.tuning = player.tuning
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_seconds(0.3)
	pad.next.move = Vector2(0, -1)
	pad.next.melee_pressed = true
	await wait_frames(1)
	assert_eq(player.melee.phase, StaffMelee.Phase.SLAM_HOVER, "falls back to a straight slam")
