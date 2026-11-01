extends TestCase
## Leaf-wing Cloak (LeafCloak + SteamVent). Expectations come from the "Glide"
## group of PlayerTuning. Most tests drop the fox from high up, spend the double
## jump and hold jump.

const DROP_HEIGHT := 20.0

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


## Put the fox high in the air, double jump (held) and wait until it falls.
func _airborne_and_falling(at: Vector3 = Vector3(0, DROP_HEIGHT, 0)) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await wait_frames(int(player.tuning.coyote_time / FRAME) + 3)  # coyote time from the floor runs out
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(1)
	await wait_until(func() -> bool: return player.velocity.y < 0.0, 2.0)
	await wait_frames(2)


func _glide(at: Vector3 = Vector3(0, DROP_HEIGHT, 0)) -> void:
	player.unlock_gadget(Gadgets.GLIDE)
	await _airborne_and_falling(at)


func test_no_glide_when_locked() -> void:
	await _airborne_and_falling()
	await wait_frames(30)
	assert_false(player.is_gliding(), "no cloak without the gadget")
	assert_true(player.velocity.y < -player.tuning.glide_fall_speed * 2.0, "falls fast (vy %.2f)" % player.velocity.y)


func test_no_glide_while_double_jump_remains() -> void:
	player.unlock_gadget(Gadgets.GLIDE)
	player.global_position = Vector3(0, DROP_HEIGHT, 0)
	pad.next.jump_held = true  # held, never pressed: the double jump is still there
	await wait_frames(30)
	assert_true(player.velocity.y < 0.0, "falling")
	assert_false(player.is_gliding(), "cloak waits for the double jump")


func test_fall_speed_capped_while_held() -> void:
	await _glide()
	assert_true(player.is_gliding(), "cloak opens when falling after the double jump")
	var slowest := 0.0
	for _i: int in 60:
		await get_tree().physics_frame
		slowest = minf(slowest, player.velocity.y)
	assert_true(slowest >= -player.tuning.glide_fall_speed - 0.01, "fall capped (min vy %.2f)" % slowest)
	assert_near(player.velocity.y, -player.tuning.glide_fall_speed, 0.05, "settles at glide fall speed")
	assert_true(player.cloak.unfold > 0.99, "wings unfolded")


func test_releasing_jump_closes() -> void:
	await _glide()
	assert_true(player.is_gliding(), "gliding")
	pad.next.jump_held = false
	await wait_frames(1)
	assert_false(player.is_gliding(), "let go: cloak shut")
	await wait_frames(20)
	assert_true(player.velocity.y < -player.tuning.glide_fall_speed * 2.0, "falls normally again")
	assert_true(player.cloak.unfold < 0.01, "wings folded")


func test_landing_closes() -> void:
	await _glide(Vector3(0, 4, 0))
	var landed := await wait_until(func() -> bool: return player.is_on_floor(), 4.0)
	assert_true(landed, "glided down to the floor")
	await wait_frames(1)
	assert_false(player.is_gliding(), "landing shuts the cloak")


func test_dodge_closes_until_pressed_again() -> void:
	await _glide()
	pad.next.dodge_pressed = true
	await wait_frames(1)
	assert_true(player.is_dodging(), "air dodge")
	assert_false(player.is_gliding(), "dodge shuts the cloak")
	await wait_frames(int(player.tuning.dodge_duration / FRAME) + 10)
	assert_false(player.is_gliding(), "still shut while jump stays held")
	pad.next.jump_held = false
	await wait_frames(1)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(2)
	assert_true(player.is_gliding(), "a fresh press-and-hold reopens it")


func test_knockback_hit_closes() -> void:
	await _glide()
	assert_true(player.hurt_box.receive(DamageInfo.create(5.0, player.global_position + Vector3(2, 0, 0), 8.0)), "hit lands")
	await wait_frames(1)
	assert_false(player.is_gliding(), "knocked out of the glide")


func test_steering_follows_camera_relative_input() -> void:
	await _glide()
	player.camera_rig.yaw = PI * 0.5  # camera looks down -X
	pad.next.move = Vector2(0, -1)  # stick forward
	await wait_frames(150)
	assert_true(player.is_gliding(), "gliding")
	var h := Vector3(player.velocity.x, 0, player.velocity.z)
	assert_near(h.length(), player.tuning.glide_speed, 0.1, "glide speed")
	assert_true(h.normalized().dot(Vector3(-1, 0, 0)) > 0.99, "heading follows the camera's forward (%s)" % h)
	# Gentle turning: a 90 degree turn takes a noticeable time.
	pad.next.move = Vector2(1, 0)  # camera right = world -Z
	await wait_frames(6)
	h = Vector3(player.velocity.x, 0, player.velocity.z)
	assert_true(h.normalized().dot(Vector3(0, 0, -1)) < 0.6, "turns gradually, not instantly")
	await wait_frames(60)
	h = Vector3(player.velocity.x, 0, player.velocity.z)
	assert_true(h.normalized().dot(Vector3(0, 0, -1)) > 0.99, "turned to the new direction")


func test_can_fire_while_gliding() -> void:
	await _glide()
	var w := player.current_weapon()
	var ammo := w.ammo
	pad.next.fire_held = true
	pad.next.strafe_held = true
	await wait_frames(20)
	assert_true(player.is_gliding(), "still gliding")
	assert_true(w.ammo < ammo, "shots fired while gliding")
	assert_false(player.is_strafing(), "no strafe while gliding")
	pad.next.fire_held = false
	pad.next.strafe_held = false


func _add_vent(at: Vector3) -> SteamVent:
	var v := SteamVent.new()
	v.position = at
	v.radius = 2.0
	v.lift_height = 8.0
	add_child(v)
	return v


func test_vent_lifts_a_glider() -> void:
	var vent := _add_vent(Vector3(0, 0, 0))
	await _glide(Vector3(0, 3, 0))
	assert_true(player.is_gliding(), "gliding over the vent")
	var top := 0.0
	for _i: int in 180:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
		player.global_position.x = 0.0  # stay in the column
		player.global_position.z = 0.0
	assert_true(top > vent.lift_height * vent.full_fraction, "carried up the column (top %.2f)" % top)
	assert_true(top < vent.lift_height + 0.5, "settles near the column top (%.2f)" % top)


func test_vent_barely_moves_a_non_glider() -> void:
	_add_vent(Vector3(0, 0, 0))
	await wait_frames(2)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	var apex := 0.0
	for _i: int in 90:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	assert_true(apex < player.tuning.jump_height * 1.2, "jump barely boosted (apex %.2f)" % apex)
	assert_true(player.is_on_floor(), "and comes back down")


func test_grapple_release_then_glide() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	player.unlock_gadget(Gadgets.GLIDE)
	var pillar := add_wall(Vector3(0, 3, -8), Vector3(4, 6, 4))
	var ring := GrappleRing.new()
	ring.position = Vector3(0, 3 + GadgetGate.RING_HEIGHT, 0)
	pillar.add_child(ring)
	await wait_frames(2)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(12)
	pad.next.dodge_pressed = true  # grapple; jump stays held through the release
	var released := await wait_until(func() -> bool: return player.grapple.just_released, 2.0)
	assert_true(released, "reeled and released")
	var falling := await wait_until(func() -> bool: return player.velocity.y < 0.0 or player.is_on_floor(), 1.0)
	assert_true(falling and not player.is_on_floor(), "falling from the release hop")
	await wait_frames(1)
	assert_false(player.is_gliding(), "holding jump through the release does not open the cloak")
	# Release refunded the double jump: press it, keep holding, glide when falling.
	pad.next.jump_pressed = true
	var glided := await wait_until(func() -> bool: return player.is_gliding(), 1.5)
	assert_true(glided, "double jump then hold glides")
