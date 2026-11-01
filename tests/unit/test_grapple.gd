extends TestCase
## Brass Grapple-Tail (GrappleTail + GrappleRing). A 6 m pillar 8 m ahead of the
## fox (camera yaw 0 looks down -Z) with a ring on top; expectations come from
## the "Grapple" group of PlayerTuning.

const PILLAR_HEIGHT := 6.0
const PILLAR_Z := -8.0

var player: Player
var pad: ScriptedInputProvider
var pillar: Block
var ring: GrappleRing


func before_each() -> void:
	add_floor()
	pillar = add_wall(Vector3(0, PILLAR_HEIGHT * 0.5, PILLAR_Z), Vector3(4, PILLAR_HEIGHT, 4))
	ring = GrappleRing.new()
	ring.position = Vector3(0, PILLAR_HEIGHT * 0.5 + GadgetGate.RING_HEIGHT, 0)
	pillar.add_child(ring)
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)


## Jump (held) and wait until rising well clear of the floor.
func _jump_and_rise(frames: int = 12) -> void:
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(frames)


func test_no_highlight_without_gadget() -> void:
	await _jump_and_rise()
	assert_true(player.grapple.target == null, "no target while locked")
	assert_eq(ring.highlight, GrappleRing.Highlight.NONE, "ring not highlighted")
	assert_false(player.grapple.is_ready(), "not ready")
	pad.next.jump_pressed = true
	await wait_frames(1)
	assert_false(player.grapple.is_active(), "jump does not grapple")
	assert_true(player.velocity.y > player.tuning.double_jump_velocity() * 0.9, "double jump instead (vy %.2f)" % player.velocity.y)


func test_highlight_when_unlocked_in_range_with_sight() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	await wait_frames(1)
	assert_eq(player.grapple.target, ring, "ring targeted from the ground")
	assert_eq(ring.highlight, GrappleRing.Highlight.IN_REACH, "dim highlight on the ground")
	assert_false(player.grapple.is_ready(), "jump on the ground still jumps")
	await _jump_and_rise()
	assert_eq(ring.highlight, GrappleRing.Highlight.READY, "bright highlight in the air")
	assert_true(player.grapple.is_ready(), "ready in the air")


func test_no_highlight_out_of_range() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	player.global_position = Vector3(0, 0.05, player.tuning.grapple_range + 2.0)
	await wait_frames(2)
	assert_true(player.grapple.target == null, "out of range")
	assert_eq(ring.highlight, GrappleRing.Highlight.NONE, "not highlighted")


func test_no_highlight_without_line_of_sight() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	add_wall(Vector3(0, 6, -3), Vector3(6, 12, 0.5))
	await wait_frames(2)
	await _jump_and_rise()
	assert_true(player.grapple.target == null, "wall blocks the ring")


func test_no_highlight_behind_camera() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	player.camera_rig.yaw = PI
	await wait_frames(2)
	assert_true(player.grapple.target == null, "ring behind the camera is ignored")


func test_jump_grapples_and_lands_on_top() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	await _jump_and_rise()
	pad.next.jump_pressed = true
	await wait_frames(1)
	assert_true(player.grapple.is_active(), "jump in the air grapples")
	await wait_frames(int(player.tuning.grapple_throw_time / FRAME) + 3)
	assert_eq(player.grapple.phase, GrappleTail.Phase.REEL, "reeling after the throw")
	assert_true(player.velocity.length() > player.tuning.grapple_reel_start_speed * 0.9, "pulled toward the ring")
	var arrived := await wait_until(func() -> bool: return not player.grapple.is_active(), player.tuning.grapple_max_time + 0.5)
	assert_true(arrived and player.grapple.just_released, "released at the ring")
	var landed := await wait_until(func() -> bool: return player.is_on_floor(), 2.0)
	assert_true(landed, "landed")
	var p := player.global_position
	assert_near(p.y, PILLAR_HEIGHT, 0.1, "on top of the pillar")
	assert_true(absf(p.x) < 2.0 and absf(p.z - PILLAR_Z) < 2.0, "inside the top face (%.2f, %.2f)" % [p.x, p.z])


func test_reel_speed_follows_tuning() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	await _jump_and_rise()
	pad.next.jump_pressed = true
	var top := 0.0
	for _i: int in 90:
		await get_tree().physics_frame
		if player.grapple.phase == GrappleTail.Phase.REEL:
			top = maxf(top, player.velocity.length())
	assert_true(top <= player.tuning.grapple_reel_speed + 0.01, "never faster than reel speed (%.2f)" % top)
	assert_true(top > player.tuning.grapple_reel_speed * 0.6, "gets up to speed (%.2f)" % top)


func test_double_jump_unchanged_without_ring_in_reach() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	ring.queue_free()
	await _jump_and_rise()
	pad.next.jump_pressed = true
	await wait_frames(1)
	assert_false(player.grapple.is_active(), "nothing to grapple")
	assert_true(player.velocity.y > player.tuning.double_jump_velocity() * 0.9, "double jump (vy %.2f)" % player.velocity.y)


func test_dodge_cancels_the_reel() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	await _jump_and_rise()
	pad.next.jump_pressed = true
	await wait_frames(int(player.tuning.grapple_throw_time / FRAME) + 4)
	assert_true(player.grapple.is_active(), "reeling")
	pad.next.move = Vector2(1, 0)
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_false(player.grapple.is_active(), "dodge lets go")
	assert_true(player.is_dodging(), "and dodges")
	assert_true(player.velocity.x > player.tuning.dodge_speed * 0.9, "dodging sideways")


func _start_reel() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	await _jump_and_rise()
	pad.next.jump_pressed = true
	await wait_frames(int(player.tuning.grapple_throw_time / FRAME) + 3)


func test_small_hit_does_not_knock_off() -> void:
	await _start_reel()
	var small := player.tuning.grapple_cancel_knockback * 0.5
	assert_true(player.hurt_box.receive(DamageInfo.create(5.0, player.global_position + Vector3(2, 0, 0), small)), "small hit lands")
	await wait_frames(1)
	assert_true(player.grapple.is_active(), "still on the line after a small hit")


func test_big_hit_knocks_off() -> void:
	await _start_reel()
	var big := player.tuning.grapple_cancel_knockback
	assert_true(player.hurt_box.receive(DamageInfo.create(5.0, player.global_position + Vector3(2, 0, 0), big)), "big hit lands")
	assert_false(player.grapple.is_active(), "big hit knocks the fox off")


func test_no_firing_while_reeling() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	var w := player.current_weapon()
	var ammo := w.ammo
	await _jump_and_rise()
	pad.next.jump_pressed = true
	await wait_frames(2)
	pad.next.fire_held = true
	await wait_frames(10)
	assert_true(player.grapple.is_active(), "still reeling")
	assert_eq(w.ammo, ammo, "no shots while reeling")
	pad.next.fire_held = false
