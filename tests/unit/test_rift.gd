extends TestCase
## Gravity rifts: the pull replaces gravity inside (lift up, current sideways),
## capped at max_speed; drift fades outside; enemies drift too.

var player: Player
var pad: ScriptedInputProvider


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(5)


func _rift(at: Vector3, size: Vector3, roll: float) -> GravityRift:
	var r := GravityRift.new()
	r.size = size
	r.position = at
	r.rotation.z = roll
	add_child(r)
	return r


func test_direction_and_containment_follow_rotation() -> void:
	var lift := _rift(Vector3(0, 4, 0), Vector3(4, 8, 4), PI)
	var current := _rift(Vector3(20, 2, 0), Vector3(4, 12, 4), PI * 0.5)
	await wait_frames(1)
	assert_true(lift.gravity_direction().is_equal_approx(Vector3.UP), "inverted rift pulls up: %s" % lift.gravity_direction())
	assert_true(current.gravity_direction().is_equal_approx(Vector3.RIGHT), "rolled rift pulls +X: %s" % current.gravity_direction())
	assert_eq(GravityRift.at(get_tree(), Vector3(0, 1, 0)), lift, "found by position")
	assert_eq(GravityRift.at(get_tree(), Vector3(25, 2, 0)), current, "rotated box contains along its long axis")
	assert_true(GravityRift.at(get_tree(), Vector3(20, 2, 5)) == null, "outside the box")


func test_lift_floats_the_fox_up() -> void:
	var lift := _rift(Vector3(0, 6, 0), Vector3(4, 12, 4), PI)
	var risen := await wait_until(func() -> bool: return player.global_position.y > 8.0, 3.0)
	assert_true(risen, "floated up (y=%.1f)" % player.global_position.y)
	assert_true(player.velocity.y <= lift.max_speed + 0.01, "rise capped at max_speed (%.2f)" % player.velocity.y)


func test_current_carries_then_fades() -> void:
	var current := _rift(Vector3(4, 1.5, 0), Vector3(3, 10, 6), PI * 0.5)
	await wait_seconds(0.6)
	assert_true(player.global_position.x > 1.0, "carried along +X (x=%.2f)" % player.global_position.x)
	assert_true(player.velocity.x <= current.max_speed + 0.5, "drift capped (%.2f)" % player.velocity.x)
	current.queue_free()
	await wait_frames(2)
	var stopped := await wait_until(func() -> bool: return absf(player.velocity.x) < 0.05, 2.0)
	assert_true(stopped, "drift fades once out of the rift (vx=%.2f)" % player.velocity.x)


func test_can_steer_across_a_current() -> void:
	_rift(Vector3(0, 1.5, 0), Vector3(3, 30, 30), PI * 0.5)
	pad.next.move = Vector2(0, -1)
	await wait_seconds(0.8)
	assert_true(player.global_position.z < -2.0, "still steers across the pull (z=%.2f)" % player.global_position.z)
	assert_true(player.global_position.x > 1.0, "while drifting with it (x=%.2f)" % player.global_position.x)


func test_no_rift_no_change() -> void:
	await wait_seconds(0.5)
	assert_true(player.is_on_floor(), "standing")
	assert_near(player.velocity.length(), 0.0, 0.01, "still")


func test_enemies_drift_in_rifts() -> void:
	_rift(Vector3(10, 6, 0), Vector3(4, 12, 4), PI)
	var bull := spawn_enemy("res://scenes/enemies/brass_bull.tscn", Vector3(10, 0, 0), 0.0, 1, false)
	var risen := await wait_until(func() -> bool: return bull.global_position.y > 3.0, 3.0)
	assert_true(risen, "bull floated (y=%.1f)" % bull.global_position.y)
