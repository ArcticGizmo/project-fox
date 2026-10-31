class_name TestCase
extends Node3D
## Base for headless tests. Each test_* method gets a fresh instance added to
## the scene tree, so the instance itself is the test's 3D world root.
## Run with --fixed-fps 60 so one awaited physics frame == 1/60 s exactly.

const FRAME := 1.0 / 60.0

var failures: PackedStringArray = PackedStringArray()


func before_each() -> void:
	pass


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "expected true") -> void:
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("%s expected %s, got %s" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s expected %.3f +/- %.3f, got %.3f" % [message, expected, tolerance, actual])


func wait_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func wait_seconds(seconds: float) -> void:
	await wait_frames(ceili(seconds / FRAME))


## Waits until `condition` returns true or `timeout` seconds pass. Returns success.
func wait_until(condition: Callable, timeout: float) -> bool:
	var frames := ceili(timeout / FRAME)
	for _i: int in frames:
		if condition.call():
			return true
		await get_tree().physics_frame
	return bool(condition.call())


func add_floor(size: float = 200.0) -> Block:
	var floor_block := Block.new()
	floor_block.size = Vector3(size, 1.0, size)
	floor_block.position = Vector3(0, -0.5, 0)
	add_child(floor_block)
	return floor_block


func add_wall(center: Vector3, size: Vector3) -> Block:
	var wall := Block.new()
	wall.size = size
	wall.position = center
	add_child(wall)
	return wall


## A stationary stand-in for the player: in the "player" group with a 0.9 x 1.8
## hurtbox, so enemies target and damage it.
func add_dummy_target(at: Vector3) -> TestDummy:
	var dummy := TestDummy.new()
	dummy.position = at
	add_child(dummy)
	return dummy


## Enemies spawn aware (like wave enemies) unless `aware` is false, which
## leaves them unaware at home as if placed in a level.
func spawn_enemy(scene_path: String, at: Vector3, yaw: float = 0.0, seed_value: int = 1, aware: bool = true) -> Enemy:
	var enemy := (load(scene_path) as PackedScene).instantiate() as Enemy
	enemy.position = at
	enemy.rotation.y = yaw
	enemy.random_seed = seed_value
	if aware:
		enemy.make_always_aware()
	add_child(enemy)
	return enemy


## Parses "state@1.23" log entries into the time of the first matching state.
static func state_time_in_log(entries: PackedStringArray, state_name: String, occurrence: int = 0) -> float:
	var seen := 0
	for entry: String in entries:
		var parts := entry.split("@")
		if parts[0] == state_name:
			if seen == occurrence:
				return parts[1].to_float()
			seen += 1
	return -1.0
