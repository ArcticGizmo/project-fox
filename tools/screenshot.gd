extends Node
## Renders the main scene (needs a GPU, so not --headless), waits, saves PNGs
## and quits. Lets an agent check visuals without anyone at the keyboard.
##   godot --path . res://tools/screenshot.tscn -- --out=screenshots --wait=2.5

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
	# Overview from above to check layout and enemy scale.
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 45, 32)
	cam.look_at(Vector3(0, 0, -2))
	cam.make_current()
	await get_tree().create_timer(0.1).timeout
	await _capture("overview.png")
	get_tree().quit()


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


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(file_name))
	img.save_png(path)
	print("saved ", path)
