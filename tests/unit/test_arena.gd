extends TestCase
## Smoke test: the real main scene boots, spawns a wave and survives a few
## seconds of AI vs an idle player without script errors.

var arena: Node3D


func before_each() -> void:
	arena = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	add_child(arena)
	await wait_frames(2)


func test_main_scene_boots_and_spawns_waves() -> void:
	var waves := arena.get_node("WaveManager") as WaveManager
	var player := get_tree().get_first_node_in_group(&"player") as Player
	assert_true(player != null, "player spawned")
	var started := await wait_until(func() -> bool: return waves.wave_number >= 1, 3.0)
	assert_true(started, "first wave started")
	assert_true(get_tree().get_nodes_in_group(&"enemies").size() > 0, "enemies alive")
	await wait_seconds(3.0)
	assert_true(is_instance_valid(player) and is_instance_valid(waves), "survived 3s of combat")


func test_debug_next_wave_and_ramp_geometry() -> void:
	var waves := arena.get_node("WaveManager") as WaveManager
	waves.spawn_next_wave()
	waves.spawn_next_wave()
	assert_eq(waves.wave_number, 2, "manual wave advance")
	# The ramp should rise toward the platform (+X).
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(13, 10, -14), Vector3(13, -5, -14), Layers.WORLD)
	var hit := space.intersect_ray(q)
	assert_false(hit.is_empty(), "ramp exists")
	if not hit.is_empty():
		assert_true((hit["position"] as Vector3).y > 2.0, "ramp high end is near the platform, y=%.2f" % (hit["position"] as Vector3).y)
