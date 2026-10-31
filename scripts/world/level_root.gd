class_name LevelRoot
extends Node3D
## Root script for every playable level scene (the arena and scenes/levels/*.tscn).
## Builds the player, HUD, pause menu and lighting at runtime, so a level scene
## only holds geometry (Blocks, GadgetGates), Crates, Hazards, Checkpoints, placed
## enemies and a `PlayerSpawn` Marker3D. A `WaveManager` child is optional.
##
## Placed enemies: every Enemy under the level when it enters the tree is recorded
## (scene, transform, exported values, patrol Marker3D children). When the player
## dies and respawns they are all freed and rebuilt fresh (dead ones come back,
## living ones reset unaware at home). Wave-spawned enemies are never recorded.
##
## Level select: `run.cmd -- --level=slice_01` loads res://scenes/levels/slice_01.tscn
## (`--level=arena` is scenes/main.tscn). The pause menu can switch levels too.

signal placed_enemies_reset

const PLAYER_TUNING := preload("res://data/player_tuning.tres")
const ARENA_PATH := "res://scenes/main.tscn"
const LEVELS_DIR := "res://scenes/levels"

static var _cmdline_handled: bool = false

var player: Player
var hud: Hud
var pause_menu: PauseMenu
var wave_manager: WaveManager
var player_spawn: Marker3D
## One record per placed enemy: {node, scene, script, parent, name, transform, props, markers}.
var placed: Array[Dictionary] = []

var _player_died: bool = false
var _recorded: bool = false


func _enter_tree() -> void:
	# Children exist with their scene values but have not run _ready yet, so this
	# snapshot is exactly what the level author placed.
	if not _recorded:
		_recorded = true
		_record_placed_enemies(self)


func _ready() -> void:
	if not _cmdline_handled:
		_cmdline_handled = true
		var wanted := cmdline_level_path()
		if wanted != "" and wanted != scene_file_path and get_tree().current_scene == self:
			get_tree().change_scene_to_file.call_deferred(wanted)
			return
	wave_manager = get_node_or_null(^"WaveManager") as WaveManager
	player_spawn = get_node_or_null(^"PlayerSpawn") as Marker3D
	_build_environment()
	player = Player.new()
	player.name = "Player"
	player.tuning = PLAYER_TUNING
	if player_spawn != null:
		player.position = player_spawn.position
		player.rotation.y = player_spawn.rotation.y
	add_child(player)
	player.died.connect(func() -> void: _player_died = true)
	player.respawned.connect(_on_player_respawned)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, wave_manager)
	pause_menu = PauseMenu.new()
	pause_menu.current_level_path = scene_file_path
	add_child(pause_menu)
	pause_menu.restart_requested.connect(restart)
	pause_menu.level_requested.connect(load_level)
	if wave_manager != null and wave_manager.autostart:
		wave_manager.start()


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed(&"debug_next_wave") and wave_manager != null:
		wave_manager.spawn_next_wave()
	elif event.is_action_pressed(&"debug_give_xp"):
		player.debug_level_current_weapon()


## Fresh level: new waves, full health and ammo, weapon levels reset.
func restart() -> void:
	get_tree().paused = false
	GameFeel.reset()
	get_tree().reload_current_scene()


func load_level(path: String) -> void:
	get_tree().paused = false
	GameFeel.reset()
	get_tree().change_scene_to_file(path)


# --- Placed enemies -------------------------------------------------------------

func _record_placed_enemies(node: Node) -> void:
	for c: Node in node.get_children():
		if c is Enemy:
			placed.append(_snapshot(c as Enemy))
		elif not (c is WaveManager):
			_record_placed_enemies(c)


func _snapshot(e: Enemy) -> Dictionary:
	var props: Dictionary = {}
	for p: Dictionary in e.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and usage & PROPERTY_USAGE_STORAGE != 0:
			var v: Variant = e.get(p["name"])
			props[p["name"]] = v.duplicate() if (v is Array or v is Dictionary) else v
	var markers: Array[Dictionary] = []
	for c: Node in e.get_children():
		if c is Marker3D:
			markers.append({&"name": c.name, &"transform": (c as Marker3D).transform})
	return {
		&"node": e,
		&"scene": e.scene_file_path,
		&"script": e.get_script(),
		&"parent": get_path_to(e.get_parent()),
		&"name": e.name,
		&"transform": e.transform,
		&"props": props,
		&"markers": markers,
	}


## Free every placed enemy (alive or dead) and rebuild it as authored. Enemy
## projectiles still in flight are cleared too.
func reset_placed_enemies() -> void:
	for n: Node in get_tree().get_nodes_in_group(LobProjectile.GROUP):
		n.queue_free()
	for rec: Dictionary in placed:
		var old: Variant = rec[&"node"]
		if is_instance_valid(old):
			var n := old as Node
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.queue_free()
		rec[&"node"] = _rebuild_enemy(rec)
	placed_enemies_reset.emit()


## The current instances of the placed enemies (freed ones are skipped).
func placed_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for rec: Dictionary in placed:
		var n: Variant = rec[&"node"]
		if is_instance_valid(n):
			out.append(n as Enemy)
	return out


func _rebuild_enemy(rec: Dictionary) -> Enemy:
	var e: Enemy
	var scene_path: String = rec[&"scene"]
	if scene_path != "":
		e = (load(scene_path) as PackedScene).instantiate() as Enemy
	else:
		e = (rec[&"script"] as Script).new() as Enemy
	var props: Dictionary = rec[&"props"]
	for key: String in props:
		var v: Variant = props[key]
		e.set(key, v.duplicate() if (v is Array or v is Dictionary) else v)
	e.name = rec[&"name"]
	e.transform = rec[&"transform"]
	for m: Dictionary in rec[&"markers"]:
		var marker := Marker3D.new()
		marker.name = m[&"name"]
		marker.transform = m[&"transform"]
		e.add_child(marker)
	var parent := get_node_or_null(rec[&"parent"] as NodePath)
	(parent if parent != null else self).add_child(e)
	return e


func _on_player_respawned() -> void:
	# Only a death resets the level; falling off the world just puts you back.
	if _player_died:
		_player_died = false
		reset_placed_enemies()


# --- Level select ---------------------------------------------------------------

## The arena first, then every scene in scenes/levels/ (alphabetical).
static func available_levels() -> PackedStringArray:
	var out := PackedStringArray([ARENA_PATH])
	var files := Array(DirAccess.get_files_at(LEVELS_DIR))
	files.sort()
	for f: String in files:
		var file := f.trim_suffix(".remap")
		if file.ends_with(".tscn"):
			out.append(LEVELS_DIR.path_join(file))
	return out


static func level_path(id: String) -> String:
	if id == "arena" or id == "main":
		return ARENA_PATH
	return LEVELS_DIR.path_join(id + ".tscn")


static func level_name(path: String) -> String:
	return "arena" if path == ARENA_PATH else path.get_file().get_basename()


## `-- --level=<name>` on the command line, as a scene path ("" if absent or missing).
static func cmdline_level_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			var path := level_path(arg.trim_prefix("--level="))
			if ResourceLoader.exists(path):
				return path
			push_warning("No level scene at %s" % path)
	return ""


# --- Environment ----------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.45, 0.6)
	sky_mat.sky_horizon_color = Color(0.85, 0.7, 0.5)
	sky_mat.ground_horizon_color = Color(0.6, 0.5, 0.4)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.shadow_enabled = true
	add_child(sun)
