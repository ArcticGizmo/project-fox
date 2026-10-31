extends Node
## Renders the main scene (needs a GPU, so not --headless), waits, saves PNGs
## and quits. Lets an agent check visuals without anyone at the keyboard.
##   godot --path . res://tools/screenshot.tscn -- --out=screenshots --wait=2.5
##   ... -- --slice     only the greybox slice shots (slice_*.png)

const SLICE_PATH := "res://scenes/levels/slice_01.tscn"

var out_dir: String = "res://screenshots"
var wait: float = 2.5


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--wait="):
			wait = arg.trim_prefix("--wait=").to_float()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Stop the editor importing screenshots as game assets.
	FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)
	# `--slice`: only the greybox slice shots (quick layout iteration).
	if "--slice" in OS.get_cmdline_user_args():
		await _capture_slice(null, SLICE_PATH)
		get_tree().quit()
		return
	var arena := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(arena)
	await get_tree().create_timer(wait).timeout
	await _capture("gameplay.png")
	await _capture_scoped(arena.get("player") as Player)
	# Pull the trigger through the real input map (same path as a controller).
	Input.action_press(&"fire")
	await get_tree().create_timer(0.2).timeout
	await _capture("firing.png")
	Input.action_release(&"fire")
	# Weapon wheel held with the left stick pushed right (slot 3 highlighted).
	Input.action_press(&"weapon_wheel")
	Input.action_press(&"move_right", 1.0)
	await get_tree().create_timer(0.3, true, false, true).timeout
	await _capture("wheel.png")
	Input.action_release(&"move_right")
	await get_tree().create_timer(0.1, true, false, true).timeout
	Input.action_release(&"weapon_wheel")
	await get_tree().create_timer(0.3).timeout
	var menu := arena.get("pause_menu") as PauseMenu
	menu.open()
	await get_tree().create_timer(0.2).timeout
	await _capture("pause.png")
	menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--weapons" in OS.get_cmdline_user_args():
		await _capture_each_weapon(arena.get("player") as Player)
	DebugSettings.show_boxes = true
	await get_tree().create_timer(0.1).timeout
	await _capture("debug_boxes.png")
	Input.action_press(&"melee")
	await get_tree().create_timer(0.1).timeout
	Input.action_release(&"melee")
	await _capture("melee.png")
	await get_tree().create_timer(0.5).timeout
	await _capture_status(arena.get("player") as Player)
	await _capture_flyers(arena.get("player") as Player, arena.get_node("WaveManager") as WaveManager)
	await _capture_hazards(arena.get("player") as Player)
	await _capture_awareness(arena.get("player") as Player, arena.get_node("WaveManager") as WaveManager)
	# Overview from above to check layout and enemy scale.
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 45, 32)
	cam.look_at(Vector3(0, 0, -2))
	cam.make_current()
	await get_tree().create_timer(0.1).timeout
	await _capture("overview.png")
	cam.queue_free()
	await _capture_slice(arena, SLICE_PATH)
	get_tree().quit()



## Swap the arena for the greybox slice: the player's view from the landing pad,
## a few in-level shots, and overviews sized to the level's real extents.
func _capture_slice(arena: Node, path: String) -> void:
	DebugSettings.show_boxes = false
	if arena != null:
		arena.queue_free()
		await get_tree().process_frame
	var level := (load(path) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await get_tree().create_timer(1.5).timeout
	await _capture("slice_pad_view.png")
	var shots: Array[Array] = [
		["slice_traversal.png", Vector3(12.5, 2.4, -32), Vector3(32, 1.5, -36)],
		["slice_hazard_yard.png", Vector3(41.5, 7.5, -13), Vector3(46, 0, 3)],
		["slice_pocket_b.png", Vector3(31, 2.2, 4.2), Vector3(18, 3.0, 7)],
		["slice_shortcut_from_pad.png", Vector3(-2, 5.0, 1), Vector3(9, 2.5, 1)],
		["slice_ridge.png", Vector3(21.5, 2.6, 18.5), Vector3(19.5, 5, 40)],
		["slice_finale.png", Vector3(19.5, 8.2, 47.5), Vector3(19.5, 6, 66)],
	]
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	for s: Array in shots:
		cam.global_position = s[1] as Vector3
		cam.look_at(s[2] as Vector3)
		await get_tree().create_timer(0.1).timeout
		await _capture(s[0] as String)
	await _capture_slice_overview(level, cam)
	cam.queue_free()


## Top-down (orthographic) and high-angle overviews framed on the level's Blocks.
func _capture_slice_overview(level: LevelRoot, cam: Camera3D) -> void:
	var bounds := AABB()
	var first := true
	for n: Node in level.find_children("*", "Block", true, false):
		var b := n as Block
		if b.size.x > 100.0:
			continue  # the abyss floor
		var box := AABB(b.global_position - b.size * 0.5, b.size)
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(bounds.size.z, bounds.size.x / aspect) * 1.04
	cam.far = 200.0
	cam.global_position = Vector3(center.x, 80, center.z)
	cam.look_at(center, Vector3.FORWARD)
	await get_tree().create_timer(0.1).timeout
	await _capture("slice_overview.png")
	DebugSettings.show_ai = true
	await get_tree().create_timer(0.2).timeout
	await _capture("slice_overview_ai.png")
	DebugSettings.show_ai = false
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.far = 400.0
	var reach := maxf(bounds.size.x, bounds.size.z)
	cam.global_position = center + Vector3(-reach * 0.3, reach * 0.5, reach * 0.42)
	cam.look_at(center)
	await get_tree().create_timer(0.1).timeout
	await _capture("slice_overview_angle.png")

## Fire each weapon for a moment and capture weapon_<id>.png (pass --weapons).
func _capture_each_weapon(player: Player) -> void:
	for i: int in player.weapons.size():
		player.select_weapon(i)
		await get_tree().physics_frame
		Input.action_press(&"fire")
		await get_tree().create_timer(0.35).timeout
		await _capture("weapon_%s.png" % player.weapons[i].data.id)
		Input.action_release(&"fire")
		await get_tree().create_timer(0.3).timeout


## Equip the scoped rifle via its number key, hold strafe, capture, restore.
func _capture_scoped(player: Player) -> void:
	var slot := player.weapon_paths.find("res://data/weapons/owl_lens_rifle.tres")
	if slot < 0:
		return
	var key := StringName("weapon_slot_%d" % (slot + 1))
	var previous := player.current_weapon_index
	Input.action_press(key)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(key)
	Input.action_press(&"strafe")
	await get_tree().create_timer(0.6).timeout
	await _capture("scoped.png")
	Input.action_release(&"strafe")
	key = StringName("weapon_slot_%d" % (previous + 1))
	Input.action_press(key)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(key)
	await get_tree().create_timer(0.4).timeout


## Line two enemies up in the open: one half chilled, one frozen solid.
func _capture_status(player: Player) -> void:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	if enemies.size() < 2:
		return
	DebugSettings.show_boxes = false
	var chilled := enemies[0] as Enemy
	var frozen := enemies[1] as Enemy
	var base := player.global_position + Vector3(0, 0, 6)
	chilled.global_position = base + Vector3(-1.6, 0, 0)
	frozen.global_position = base + Vector3(1.6, 0, 0)
	frozen.freeze(5.0)
	await get_tree().physics_frame
	# Keep the chilled one still without stopping its visuals ticking.
	chilled.root(5.0)
	chilled.add_chill(0.6, 5.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = base + Vector3(0, 2.5, 5.0)
	cam.look_at(base + Vector3.UP * 0.6)
	cam.make_current()
	await get_tree().create_timer(0.1).timeout
	await _capture("status.png")
	cam.queue_free()


## Spawn a falcon and a gull near the player: cruising shot, then the falcon's dive.
func _capture_flyers(player: Player, waves: WaveManager) -> void:
	var base := player.global_position
	var falcon := waves.spawn_enemy(&"falcon", base + Vector3(-4, 0, -8)) as BrassFalcon
	waves.spawn_enemy(&"gull", base + Vector3(4, 0, -10))
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = base + Vector3(0, 2.5, 7)
	cam.look_at(base + Vector3(0, 3.5, -6))
	cam.make_current()
	await get_tree().create_timer(2.2).timeout
	await _capture("flyers.png")
	for _i: int in 300:
		if not is_instance_valid(falcon) or falcon.state == &"dive":
			break
		await get_tree().physics_frame
	await get_tree().create_timer(0.12).timeout
	await _capture("falcon_dive.png")
	cam.queue_free()


## One shot of each hazard type mid-telegraph and while dangerous.
func _capture_hazards(arena_player: Player) -> void:
	var done: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"hazards"):
		var kind := (n.get_script() as Script).get_global_name()
		if done.has(kind):
			continue
		done[kind] = true
		if n is FireTrap:
			await _capture_fire_trap(n as FireTrap)
		elif n is LightningBarrier:
			await _capture_lightning(n as LightningBarrier)
		elif n is Lava:
			await _capture_lava(n as Lava, arena_player)
		elif n is ClockworkSweeper:
			await _capture_sweeper(n as ClockworkSweeper)
		elif n is SteamHammer:
			await _capture_hammer(n as SteamHammer)


func _capture_hammer(hammer: SteamHammer) -> void:
	var cam := _hazard_camera(hammer, Vector3(0, 5.0, 12.0), 3.0)
	hammer.enter_state(SteamHammer.WINDUP)
	hammer.state_time = hammer.windup_time * 0.8
	await get_tree().create_timer(0.05).timeout
	await _capture("hazard_hammer_windup.png")
	for _i: int in 120:
		if hammer.state == SteamHammer.DOWN:
			break
		await get_tree().physics_frame
	await _capture("hazard_hammer_slam.png")
	cam.queue_free()


func _capture_sweeper(sweeper: ClockworkSweeper) -> void:
	var cam := _hazard_camera(sweeper, Vector3(0, 5.0, 8.0), 0.3)
	sweeper.enter_state(ClockworkSweeper.SURGE_WARN)
	sweeper.state_time = sweeper.surge_warning * 0.8
	await get_tree().create_timer(0.05).timeout
	await _capture("hazard_sweeper_warn.png")
	cam.queue_free()


func _capture_fire_trap(trap: FireTrap) -> void:
	var cam := _hazard_camera(trap)
	trap.trigger_now()
	await get_tree().create_timer(trap.arm_time * 0.8).timeout
	await _capture("hazard_fire_armed.png")
	await get_tree().create_timer(trap.arm_time * 0.2 + 0.3).timeout
	await _capture("hazard_fire_burning.png")
	cam.queue_free()


## Drop the fox onto the lava and catch it mid-bounce.
func _capture_lava(lava: Lava, player: Player) -> void:
	var cam := _hazard_camera(lava, Vector3(0, 4.0, 9.0), 1.0)
	await get_tree().create_timer(0.3).timeout
	await _capture("hazard_lava.png")
	player.global_position = lava.global_position + Vector3(1.0, 0.05, 0.5)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	# The fox blinks during hurt i-frames; wait for a visible frame.
	for _i: int in 10:
		if player.visual.visible:
			break
		await get_tree().physics_frame
	await _capture("hazard_lava_launch.png")
	cam.queue_free()


## From the north (-Z) side so a second barrier behind it does not block the view.
func _capture_lightning(barrier: LightningBarrier) -> void:
	var cam := _hazard_camera(barrier, Vector3(0, 6.5, -8.0), 1.2)
	barrier.enter_state(LightningBarrier.CHARGING)
	barrier.state_time = barrier.charge_time * 0.8
	await get_tree().create_timer(0.05).timeout
	await _capture("hazard_lightning_charging.png")
	await get_tree().create_timer(barrier.charge_time * 0.2 + 0.2).timeout
	await _capture("hazard_lightning_on.png")
	cam.queue_free()


func _hazard_camera(h: Hazard, offset: Vector3 = Vector3(0, 3.5, 7), look_height: float = 1.0) -> Camera3D:
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = h.global_position + offset
	cam.look_at(h.global_position + Vector3.UP * look_height)
	cam.make_current()
	return cam


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(file_name))
	img.save_png(path)
	print("saved ", path)


## Unaware enemies with the AI debug view on: a resting bull with a patrol route,
## a suspicious rat, an alerting toad passing the alert to a gull, plus a noise
## pulse. Then the same moment with the view off (markers only).
func _capture_awareness(player: Player, waves: WaveManager) -> void:
	waves.set_physics_process(false)
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		n.queue_free()
	await get_tree().physics_frame
	DebugSettings.show_boxes = false
	var p := player.global_position
	var parent := waves.get_parent()
	var bull := _place_unaware(parent, "res://scenes/enemies/brass_bull.tscn", p + Vector3(7, 0, -12), 0.6,
			[Vector3(-3, 0, -3), Vector3(3, 0, -4)])
	bull.rest_time_min = 60.0
	bull.rest_time_max = 60.0
	_place_unaware(parent, "res://scenes/enemies/clockwork_rat.tscn", p + Vector3(-4, 0, -11), PI - 0.3)
	var toad := _place_unaware(parent, "res://scenes/enemies/spitter_toad.tscn", p + Vector3(2, 0, -22), 0.0)
	_place_unaware(parent, "res://scenes/enemies/bombardier_gull.tscn", p + Vector3(5, 0, -24), 0.0)
	DebugSettings.show_ai = true
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = p + Vector3(0, 9, -1)
	cam.look_at(p + Vector3(0, 0, -14))
	cam.make_current()
	await get_tree().create_timer(0.3).timeout
	# Away from the bull so it keeps resting; the rat may hear it and investigate.
	NoiseEvent.emit(p + Vector3(-6, 0, -6), 3.0, player)
	toad.call(&"_begin_alert", true)
	await get_tree().create_timer(0.25).timeout
	await _capture("awareness_debug.png")
	DebugSettings.show_ai = false
	await get_tree().process_frame
	await _capture("awareness_markers.png")
	cam.queue_free()
	waves.set_physics_process(true)


func _place_unaware(parent: Node, path: String, at: Vector3, yaw: float, route: Array[Vector3] = []) -> Enemy:
	var e := (load(path) as PackedScene).instantiate() as Enemy
	e.position = at
	e.rotation.y = yaw
	for offset: Vector3 in route:
		var m := Marker3D.new()
		m.position = offset
		e.add_child(m)
	parent.add_child(e)
	return e
