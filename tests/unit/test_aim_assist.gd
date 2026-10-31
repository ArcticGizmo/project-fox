extends TestCase


func _targets(points: Array[Vector3]) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p: Vector3 in points:
		var n := Node3D.new()
		n.position = p
		add_child(n)
		out.append(n)
	return out


func test_prefers_closest_to_centre() -> void:
	var t := _targets([Vector3(1.5, 0, -20), Vector3(0.3, 0, -20)])
	assert_eq(AimAssist.pick_target(Vector3.ZERO, Vector3.FORWARD, t, 10.0, 60.0), t[1], "centre target")


func test_close_enemy_beats_far_one_on_centre() -> void:
	# ~6.8 deg off at 5m vs dead centre at 50m
	var t := _targets([Vector3(0.6, 0, -5), Vector3(0, 0, -50)])
	assert_eq(AimAssist.pick_target(Vector3.ZERO, Vector3.FORWARD, t, 10.0, 60.0), t[0], "distance penalty")


func test_rejects_outside_cone_and_range() -> void:
	var t := _targets([Vector3(10, 0, -10), Vector3(0, 0, -100)])
	assert_eq(AimAssist.pick_target(Vector3.ZERO, Vector3.FORWARD, t, 10.0, 60.0), null, "nothing valid")


func test_line_of_sight_blocks() -> void:
	var t := _targets([Vector3(0, 1, -10)])
	add_wall(Vector3(0, 1, -5), Vector3(4, 4, 1))
	await wait_frames(2)
	var space := get_world_3d().direct_space_state
	assert_eq(AimAssist.pick_target(Vector3(0, 1, 0), Vector3.FORWARD, t, 10.0, 60.0, space), null, "wall blocks")
