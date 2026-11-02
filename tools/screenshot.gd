extends Node
## Renders the main scene (needs a GPU, so not --headless), waits, saves PNGs
## and quits. Lets an agent check visuals without anyone at the keyboard.
##   godot --path . res://tools/screenshot.tscn -- --out=screenshots --wait=2.5
##   ... -- --slice     only the greybox slice shots (slice_*, grapple_*, burrow_*, glide_*, conduit_*)

const SLICE_PATH := "res://scenes/levels/slice_01.tscn"
const BOSS_PATH := "res://scenes/levels/boss_furnace_stag.tscn"
const SHOWCASE_PATH := "res://scenes/levels/anim_showcase.tscn"

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
	# `--boss`: only the Furnace Stag arena shots.
	if "--boss" in OS.get_cmdline_user_args():
		await _capture_boss()
		get_tree().quit()
		return
	# `--fox`: only the fox animation contact sheets.
	if "--fox" in OS.get_cmdline_user_args():
		await _capture_fox_anims()
		await _capture_showcase()
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
	menu.show_debug_page()
	await get_tree().create_timer(0.1).timeout
	await _capture("pause_debug.png")
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
	# Level-up popup: weapon name plus what the level adds.
	(arena.get("player") as Player).debug_level_current_weapon()
	await get_tree().create_timer(0.4).timeout
	await _capture("level_up.png")
	await _capture_status(arena.get("player") as Player)
	await _capture_flyers(arena.get("player") as Player, arena.get_node("WaveManager") as WaveManager)
	await _capture_pangolin(arena.get("player") as Player, arena.get_node("WaveManager") as WaveManager)
	await _capture_heron(arena.get("player") as Player, arena.get_node("WaveManager") as WaveManager)
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
	await _capture_boss()
	if is_instance_valid(arena):
		arena.queue_free()
	await _capture_fox_anims()
	await _capture_showcase()
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
		["slice_traversal.png", Vector3(16.5, 2.4, -32), Vector3(34, 1.5, -36)],
		["slice_hazard_yard.png", Vector3(41.5, 7.5, -13), Vector3(46, 0, 3)],
		["slice_pocket_b.png", Vector3(31, 2.2, 4.2), Vector3(18, 3.0, 7)],
		["slice_shortcut_from_pad.png", Vector3(-3, 5.5, -3), Vector3(9, 4, 1)],
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
	await _capture_grapple(level)
	await _capture_burrow(level)
	await _capture_glide(level)
	await _capture_conduit(level)


## Top-down (orthographic) and high-angle overviews framed on the level's Blocks.
func _capture_slice_overview(level: LevelRoot, cam: Camera3D) -> void:
	# Overviews are for reading layout from far up: no distance haze.
	var env := (level.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	env.fog_enabled = false
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
	env.fog_enabled = true

## Fire each weapon for a moment and capture weapon_<id>.png (pass --weapons).
func _capture_each_weapon(player: Player) -> void:
	for i: int in player.weapons.size():
		player.select_weapon(i)
		await get_tree().physics_frame
		Input.action_press(&"fire")
		var data := player.weapons[i].data
		if data.charge_time > 0.0:
			# Charge weapons: the full-charge reticle, then the shot after release.
			await get_tree().create_timer(data.charge_time + 0.1).timeout
			await _capture("weapon_%s_charged.png" % data.id)
			Input.action_release(&"fire")
			await get_tree().create_timer(0.12).timeout
			await _capture("weapon_%s.png" % data.id)
		else:
			await get_tree().create_timer(0.35).timeout
			await _capture("weapon_%s.png" % data.id)
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


## A pangolin seen from the side: plates flared for a volley, shards in flight,
## curled mid-roll, then dizzy on its back.
func _capture_pangolin(player: Player, waves: WaveManager) -> void:
	var base := player.global_position
	var p := waves.spawn_enemy(&"pangolin", base + Vector3(0, 0, -9)) as BrassPangolin
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = base + Vector3(6, 2.5, -3)
	cam.look_at(base + Vector3(0, 0.8, -6.5))
	cam.make_current()
	for _i: int in 400:
		if not is_instance_valid(p) or p.state == &"volley_windup" and p.state_time > p.volley_windup_time * 0.8:
			break
		await get_tree().physics_frame
	await _capture("pangolin_volley_windup.png")
	await get_tree().create_timer(0.2).timeout
	await _capture("pangolin_volley.png")
	if is_instance_valid(p):
		p.enter_state(&"curl")
	await get_tree().create_timer(p.curl_time * 0.8).timeout
	await _capture("pangolin_curl.png")
	await get_tree().create_timer(0.35).timeout
	await _capture("pangolin_roll.png")
	if is_instance_valid(p):
		p.enter_state(&"dizzy")
		DebugSettings.show_boxes = true
	await get_tree().create_timer(0.3).timeout
	await _capture("pangolin_dizzy.png")
	DebugSettings.show_boxes = false
	if is_instance_valid(p):
		p.queue_free()
	# A Clockwork Swallow looping round a fresh pangolin to hit its back, from above.
	var p2 := waves.spawn_enemy(&"pangolin", base + Vector3(0, 0, -10)) as BrassPangolin
	p2.set_physics_process(false)
	player.select_weapon(Player.DEFAULT_WEAPONS.find("res://data/weapons/clockwork_swallow.tres"))
	cam.global_position = base + Vector3(0, 16, -5)
	cam.look_at(base + Vector3(0, 0, -6), Vector3.FORWARD)
	await get_tree().physics_frame
	Input.action_press(&"fire")
	await get_tree().create_timer(0.05).timeout
	Input.action_release(&"fire")
	await get_tree().create_timer(0.35).timeout
	await _capture("swallow_curve.png")
	await get_tree().create_timer(0.2).timeout
	await _capture("swallow_hit.png")
	if is_instance_valid(p2):
		p2.queue_free()
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


## Contact sheets of the fox's clips on an empty stage, each fox frozen at a phase:
## fox_walk_side / fox_walk_front (contact, down, passing, up, then the other foot),
## fox_run_side, fox_idle (quarter-loop steps), fox_air (jump, flip, fall, land),
## fox_actions (dodge, hurt, land, three-quarter view), fox_swings, fox_slam_aim,
## fox_gadgets (glide, reel, strafe hip twist).
func _capture_fox_anims() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.38)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.make_current()

	var side := Vector3(9, 1.0, 0)
	var front := Vector3(0, 1.0, -9)
	# Each sheet: file, camera position, row direction, [clip, phase(, aiming(, hip twist deg))] per fox.
	var sheets: Array[Array] = [
		["fox_walk_side.png", side, Vector3.FORWARD, _phases(&"Walk", [0.0, 0.125, 0.25, 0.375, 0.5, 0.75])],
		["fox_walk_front.png", front, Vector3.RIGHT, _phases(&"Walk", [0.0, 0.125, 0.25, 0.375, 0.5, 0.75])],
		["fox_run_side.png", side, Vector3.FORWARD, _phases(&"Running", [0.0, 0.17, 0.33, 0.5, 0.67, 0.83])],
		["fox_idle.png", Vector3(5, 1.2, -6), Vector3.RIGHT, _phases(&"Idle", [0.0, 0.25, 0.5, 0.75])],
		["fox_air.png", side, Vector3.FORWARD, [[&"Jump", 0.0], [&"DoubleJump", 0.25], [&"DoubleJump", 0.5],
				[&"DoubleJump", 0.75], [&"Fall", 0.0], [&"Land", 0.12]]],
		["fox_actions.png", Vector3(6, 1.2, -7), Vector3.RIGHT, [[&"Dodge", 0.6], [&"Hurt", 0.12], [&"Land", 0.12],
				[&"Jump", 0.25], [&"Fall", 0.5]]],
		["fox_swings.png", Vector3(8, 3.0, -4), Vector3.FORWARD, [[&"SwingRight", 0.0], [&"SwingRight", 0.3],
				[&"SwingLeft", 0.0], [&"SwingLeft", 0.3], [&"SwingOverhead", 0.0], [&"SwingOverhead", 0.3]]],
		["fox_slam_aim.png", Vector3(8, 2.0, -3), Vector3.FORWARD, [[&"SlamRise", 0.0], [&"SlamFall", 0.0],
				[&"SlamLand", 0.1], [&"Idle", 0.0, true], [&"Running", 0.3, true]]],
		["fox_staff.png", Vector3(7.5, 1.6, -2.4), Vector3.FORWARD, [[&"Idle", 0.0], [&"SwingRight", 0.3],
				[&"SwingOverhead", 0.0], [&"SwingOverhead", 0.3], [&"SlamRise", 0.0], [&"SlamFall", 0.0]]],
		["fox_gadgets.png", Vector3(8, 2.0, -3), Vector3.FORWARD, [[&"Glide", 0.0], [&"Glide", 0.5], [&"Reel", 0.0],
				[&"Walk", 0.0, true, 60.0], [&"Running", 0.0, true, -60.0]]],
	]
	for sheet: Array in sheets:
		var poses: Array = sheet[3]
		var row_dir: Vector3 = sheet[2]
		var foxes: Array[FoxModel] = []
		for i: int in poses.size():
			var fox := FoxModel.new(Player.HEIGHT)
			stage.add_child(fox)
			var gun := MeshInstance3D.new()
			var gun_box := BoxMesh.new()
			gun_box.size = Vector3(0.13, 0.13, 0.42)
			gun.mesh = gun_box
			gun.position = Vector3(0, 0.03, -0.12)
			fox.gun_mount.add_child(gun)
			# The staff in the fist for staff moves, slung on the back otherwise.
			var clip := String(poses[i][0])
			var mount := fox.staff_hand_mount if clip.begins_with("Swing") or clip.begins_with("Slam") else fox.staff_back_mount
			var holder := Node3D.new()
			holder.scale = Vector3.ONE / (Player.HEIGHT / FoxModel.MODEL_HEIGHT)
			holder.add_child(StaffMelee.staff_visual())
			mount.add_child(holder)
			fox.position = row_dir * (float(i) - (poses.size() - 1) * 0.5) * 1.5
			fox.anim.play(poses[i][0] as StringName)
			fox.anim.seek(fox.anim.current_animation_length * float(poses[i][1]), true)
			fox.anim.pause()
			if (poses[i] as Array).size() > 2 and poses[i][2]:
				fox.aim(true)
				fox._update_aim()
				fox.aim_layer.influence = 1.0
			if (poses[i] as Array).size() > 3:
				fox.twist_layer.yaw = deg_to_rad(float(poses[i][3]))
			foxes.append(fox)
		cam.position = sheet[1] as Vector3
		cam.look_at(Vector3(0, 0.85, 0))
		await get_tree().process_frame
		await _capture(sheet[0] as String)
		for fox: FoxModel in foxes:
			fox.queue_free()
	stage.queue_free()


## The animation showcase level: the player's view from spawn and an overview.
func _capture_showcase() -> void:
	var level := (load(SHOWCASE_PATH) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await get_tree().create_timer(2.0).timeout
	await _capture("showcase_spawn.png")
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0, 26, 40)
	cam.look_at(Vector3(0, 0, 10))
	cam.make_current()
	await get_tree().create_timer(0.1).timeout
	await _capture("showcase_overview.png")
	cam.queue_free()
	level.queue_free()


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


## Grapple-Tail at the slice's GrappleLedge: airborne with the ring highlighted
## (and the reticle's brass ring), then mid-reel from the player's camera and
## from the side so the rope reads.
func _capture_grapple(level: LevelRoot) -> void:
	var player := level.player
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	player.unlock_gadget(Gadgets.GRAPPLE)
	player.global_position = Vector3(30.4, 1.55, -35.0)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = deg_to_rad(-5.0)
	player.camera_rig.snap_to_target()
	player.camera_rig.camera.make_current()
	await get_tree().create_timer(0.4).timeout
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	for _i: int in 60:
		await get_tree().physics_frame
		if player.velocity.y <= 2.0:
			break
	await _capture("grapple_ready.png")
	pad.next.dodge_pressed = true
	for _i: int in 60:
		await get_tree().physics_frame
		if player.grapple.phase == GrappleTail.Phase.REEL and player.grapple.phase_time > 0.12:
			break
	get_tree().paused = true  # hold the pose for both shots
	await _capture("grapple_reel.png")
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = player.global_position + Vector3(7.5, 2.0, 1.5)
	cam.look_at(player.global_position.lerp(player.grapple.ring.global_position, 0.5))
	cam.make_current()
	await _capture("grapple_reel_side.png")
	get_tree().paused = false
	cam.queue_free()
	player.input_provider = DeviceInputProvider.new()


## Leaf-wing Cloak at the slice's GlideVent: ride the updraft (glide_vent.png),
## then glide south over the gap toward BeyondPlatform (glide_gap.png, plus a
## side view glide_gap_side.png).
func _capture_glide(level: LevelRoot) -> void:
	var player := level.player
	var enemies := level.get_node_or_null(^"Enemies")
	if enemies != null:
		enemies.queue_free()  # last step: keep the finale quiet for the glide shots
	if player.is_dead:
		player.respawn()  # killed during earlier shots: do not let the respawn timer move it mid-glide
	var gate := level.get_node(^"Level/Finale/GlideVent") as GadgetGate
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	player.unlock_gadget(Gadgets.GLIDE)
	player.grapple.cancel()  # the grapple shots leave it mid-reel
	player.global_position = gate.global_position + Vector3.UP * (gate.size.y * 0.5 + 0.05)
	player.velocity = Vector3.ZERO
	player.camera_rig.yaw = PI
	player.camera_rig.pitch = deg_to_rad(-12.0)
	player.camera_rig.snap_to_target()
	player.camera_rig.camera.make_current()
	await get_tree().create_timer(0.4).timeout
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	var doubled := false
	for _i: int in 240:
		await get_tree().physics_frame
		if not doubled and player.velocity.y <= 0.0 and not player.is_on_floor():
			doubled = true
			pad.next.jump_pressed = true
		if player.is_gliding() and player.global_position.y > gate.global_position.y + 5.0:
			break
	await _capture("glide_vent.png")
	pad.next.move = Vector2(0, -1)
	for _i: int in 90:
		await get_tree().physics_frame
	get_tree().paused = true
	await _capture("glide_gap.png")
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = player.global_position + Vector3(-7.0, 4.0, -2.5)
	cam.look_at(player.global_position + Vector3.UP)
	cam.make_current()
	await _capture("glide_gap_side.png")
	get_tree().paused = false
	cam.queue_free()
	pad.next = PlayerInputState.new()
	player.input_provider = DeviceInputProvider.new()


## Burrow Claws at pocket A's ambush patches: tunnel from AmbushSoil (behind
## the cover by the fence) to AmbushSoilBull behind the resting bull, then the
## dirt mound moving with the AI debug view on (nobody sees it: burrow_mound),
## the pop-out hop (burrow_pop) and the sneak swing (burrow_sneak).
func _capture_burrow(level: LevelRoot) -> void:
	var player := level.player
	if player.is_dead:
		player.respawn()
	player.grapple.cancel()  # the grapple shots leave it mid-reel
	var from := level.get_node(^"Level/PocketA/AmbushSoil") as SoilPatch
	var to := level.get_node(^"Level/PocketA/AmbushSoilBull") as SoilPatch
	var bull := level.get_node_or_null(^"Enemies/PocketA/Bull") as Enemy
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	player.unlock_gadget(Gadgets.BURROW)
	player.global_position = from.global_position + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.facing_yaw = 0.0
	player.camera_rig.yaw = 0.0
	player.camera_rig.pitch = deg_to_rad(-15.0)
	player.camera_rig.snap_to_target()
	player.camera_rig.camera.make_current()
	await get_tree().create_timer(0.3).timeout
	pad.next.dodge_pressed = true  # dig in
	for _i: int in 60:
		await get_tree().physics_frame
		if player.burrow.is_under():
			break
	pad.next.dodge_pressed = true  # tunnel to the patch behind the bull
	for _i: int in 120:
		await get_tree().physics_frame
		if player.burrow.is_under() and player.burrow.patch == to:
			break
	pad.next.move = Vector2(0.3, -1.0)  # creep up behind the bull
	DebugSettings.show_ai = true
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = to.global_position + Vector3(6.5, 4.5, 3.5)
	cam.look_at(to.global_position.lerp(bull.global_position if bull != null else to.global_position, 0.4))
	cam.make_current()
	for _i: int in 15:
		await get_tree().physics_frame
	await _capture("burrow_mound.png")
	DebugSettings.show_ai = false
	pad.next.move = Vector2.ZERO
	pad.next.jump_pressed = true  # pop out (press staff during the hop: swings on landing)
	await get_tree().physics_frame
	pad.next.melee_pressed = true
	for _i: int in 6:
		await get_tree().physics_frame
	await _capture("burrow_pop.png")
	for _i: int in 40:
		await get_tree().physics_frame
		if player.melee.phase == StaffMelee.Phase.SWING and player.melee.phase_time > 0.2:
			break
	await _capture("burrow_sneak.png")
	if bull != null:
		print("burrow sneak: bull %.0f / %.0f hp, aware %s" % [bull.health.current, bull.health.max_health, bull.aware])
	cam.queue_free()
	pad.next = PlayerInputState.new()
	player.input_provider = DeviceInputProvider.new()


## Copper Conduit Gauntlet on the slice's shortcut: staff the yard's DoorBarrier
## while it arcs (conduit_absorb: the bolt into the staff; conduit_charged: the
## charged staff crackling by the drained barrier), then the ShortcutTerminal in
## pocket B (conduit_powered: lamp lit, door sinking; conduit_door_open: the
## doorway from pocket B; conduit_door_from_pad: the same from the pad).
func _capture_conduit(level: LevelRoot) -> void:
	var player := level.player
	if player.is_dead:
		player.respawn()
	player.grapple.cancel()
	player.close_glide()
	var barrier := level.get_node(^"Hazards/DoorBarrier") as LightningBarrier
	var terminal := level.get_node(^"Level/Shortcut/ShortcutTerminal") as ConduitTerminal
	var door := level.get_node(^"Level/Shortcut/ShortcutDoor") as GadgetGate
	var pad := ScriptedInputProvider.new()
	player.input_provider = pad
	player.unlock_gadget(Gadgets.CONDUIT)
	# Yard side of the barrier (east), facing it.
	var a := barrier.to_global(Vector3(0, 0.05, 1.9))
	var b := barrier.to_global(Vector3(0, 0.05, -1.9))
	_place_player(player, a if a.x > b.x else b, barrier.global_position)
	var cam := Camera3D.new()
	add_child(cam)
	var fox := player.global_position
	cam.global_position = fox + Vector3(2.6, 2.6, 3.4)
	cam.look_at(fox.lerp(barrier.global_position, 0.5) + Vector3.UP * 1.0)
	cam.make_current()
	for _i: int in 30:
		await get_tree().physics_frame  # land first: a staff press in the air is a slam
	for _i: int in 600:
		await get_tree().physics_frame
		if barrier.state == LightningBarrier.ON and barrier.state_time > 0.2 and player.is_on_floor():
			break
	await _capture("conduit_barrier_live.png")
	pad.next.melee_pressed = true
	for _i: int in 30:
		await get_tree().physics_frame
		if player.conduit.is_charged():
			break
	await get_tree().physics_frame
	await _capture("conduit_absorb.png")
	for _i: int in 30:
		await get_tree().physics_frame
	# Front-right of the fox (it faces the barrier; the staff rests on its right).
	cam.global_position = player.global_position + player.facing_forward() * 1.8 + Vector3.UP * 1.7 + player.facing_forward().cross(Vector3.UP) * 1.6
	cam.look_at(player.global_position + Vector3.UP * 1.2)
	await _capture("conduit_charged.png")
	print("conduit: charges %d, barrier %s" % [player.conduit.charges, barrier.state])
	# Pocket B: the dead terminal beside the shortcut door.
	_place_player(player, terminal.global_position + Vector3(0.4, 0.05, 1.6), terminal.global_position)
	cam.global_position = Vector3(16.5, 3.4, -1.6)
	cam.look_at(Vector3(9.4, 1.6, -0.4))
	for _i: int in 10:
		await get_tree().physics_frame
	await _capture("conduit_terminal_dead.png")
	pad.next.melee_pressed = true
	for _i: int in 40:
		await get_tree().physics_frame
	await _capture("conduit_powered.png")
	for _i: int in 120:
		await get_tree().physics_frame
		if door.is_fully_open():
			break
	await _capture("conduit_door_open.png")
	cam.global_position = Vector3(-3, 5.5, -3)
	cam.look_at(Vector3(9, 2, 1))
	await get_tree().create_timer(0.1).timeout
	await _capture("conduit_door_from_pad.png")
	print("conduit: terminal powered %s, door open %s" % [terminal.is_powered, door.is_fully_open()])
	cam.queue_free()
	pad.next = PlayerInputState.new()
	player.input_provider = DeviceInputProvider.new()


func _place_player(player: Player, at: Vector3, look_at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.facing_yaw = Player.yaw_of(look_at - at)
	player.visual.rotation.y = player.facing_yaw
	player.camera_rig.yaw = player.facing_yaw
	player.camera_rig.snap_to_target()


func _phases(clip: StringName, phases: Array) -> Array:
	return phases.map(func(p: float) -> Array: return [clip, p])


## The Furnace Stag arena: the player's opening view (boss bar), then the stag
## rearing, its shockwave, phase 2 (furnace open, barrage) and phase 3 lightning.
func _capture_boss() -> void:
	for c: Node in get_children():
		if c is LevelRoot:
			c.queue_free()
	await get_tree().process_frame
	var level := (load(BOSS_PATH) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await get_tree().create_timer(1.5).timeout
	await _capture("boss_intro.png")
	# Keep the fox alive: a respawn would rebuild the stag mid-shoot.
	level.player.health.max_health = 100000.0
	level.player.health.current = 100000.0
	var stag := get_tree().get_nodes_in_group(&"bosses")[0] as FurnaceStag
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	var side := func() -> void:
		cam.global_position = stag.global_position + Vector3(11, 5, 3)
		cam.look_at(stag.global_position + Vector3.UP * 2.0)
	side.call()
	stag.force_attack(&"stomp")
	for _i: int in 300:
		if stag.state == &"stomp_windup" and stag.state_time > stag.stomp_windup_time * 0.75:
			break
		await get_tree().physics_frame
	await _capture("boss_rear.png")
	for _i: int in 300:
		if stag.last_shockwave != null:
			break
		await get_tree().physics_frame
	cam.global_position = stag.global_position + Vector3(0, 14, 12)
	cam.look_at(stag.global_position)
	await get_tree().create_timer(0.5).timeout
	await _capture("boss_shockwave.png")
	stag.health.apply_damage(DamageInfo.create(stag.health.current - stag.health.max_health * 0.6, stag.global_position))
	await get_tree().create_timer(stag.roar_time + 0.3).timeout
	cam.global_position = stag.global_position + stag.forward() * 9.0 + Vector3(3, 3, 0)
	cam.look_at(stag.global_position + Vector3.UP * 1.5)
	await _capture("boss_phase2.png")
	stag.force_attack(&"barrage")
	for _i: int in 300:
		if stag.state == &"recover":
			break
		await get_tree().physics_frame
	side.call()
	await get_tree().create_timer(0.4).timeout
	await _capture("boss_barrage.png")
	stag.health.apply_damage(DamageInfo.create(stag.health.current - stag.health.max_health * 0.3, stag.global_position))
	await get_tree().create_timer(stag.roar_time + 0.3).timeout
	stag.force_attack(&"strike")
	for _i: int in 300:
		if not stag.last_strikes.is_empty():
			break
		await get_tree().physics_frame
	cam.global_position = level.player.global_position + Vector3(0, 11, -8)
	cam.look_at(level.player.global_position)
	await get_tree().create_timer(0.5).timeout
	await _capture("boss_lightning.png")
	cam.queue_free()
	level.queue_free()
	await get_tree().process_frame


## A Chime Heron shielding a bull and a pangolin: bubbles and tethers.
func _capture_heron(player: Player, waves: WaveManager) -> void:
	var base := player.global_position
	var heron := waves.spawn_enemy(&"heron", base + Vector3(0, 0, -14))
	var bull := waves.spawn_enemy(&"bull", base + Vector3(-3.5, 0, -11))
	var pang := waves.spawn_enemy(&"pangolin", base + Vector3(3.5, 0, -11))
	for e: Enemy in [heron, bull, pang]:
		e.set_physics_process(false)
	await get_tree().physics_frame
	# Running (visuals update every physics frame); 0.25 s is too short to wander off.
	for e: Enemy in [heron, bull, pang]:
		e.set_physics_process(true)
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = base + Vector3(5, 4, -3)
	cam.look_at(base + Vector3(0, 1, -12))
	cam.make_current()
	await get_tree().create_timer(0.3).timeout
	await _capture("heron_shield.png")
	for e: Enemy in [heron, bull, pang]:
		if is_instance_valid(e):
			e.queue_free()
	cam.queue_free()
