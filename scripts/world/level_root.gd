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
##
## Saving (`uses_save`, off for the arena): the SaveGame profile is applied to
## the new player (glimmer, owned weapons and levels, gadgets, Heartsprings),
## pickups it already took are removed, and if its last checkpoint is in this
## level the fox starts there. It saves at checkpoints, pickups, purchases,
## gadget unlocks, respawns and whenever the level leaves the tree (restart,
## level change, quit). What a level only lends (`starting_gadgets`,
## `lend_all_weapons`) is never saved as owned.

signal placed_enemies_reset

const PLAYER_TUNING := preload("res://data/player_tuning.tres")
const ARENA_PATH := "res://scenes/main.tscn"
const LEVELS_DIR := "res://scenes/levels"

static var _cmdline_handled: bool = false

## Surface textures for this level's Blocks (null: LevelTheme.DEFAULT_PATH).
@export var level_theme: LevelTheme
## Gadgets the fox starts this level with (unlocked before the HUD binds, so no popups).
@export var starting_gadgets: Array[StringName] = []
## False: never loads or writes the save (the wave arena: a sandbox with every weapon).
@export var uses_save: bool = true
## Every weapon is owned while in this level but not saved as owned (test beds).
@export var lend_all_weapons: bool = false

var player: Player
var hud: Hud
var pause_menu: PauseMenu
var shop_menu: ShopMenu
var wave_manager: WaveManager
var player_spawn: Marker3D
## One record per placed enemy: {node, scene, script, parent, name, transform, props, markers}.
var placed: Array[Dictionary] = []

var _player_died: bool = false
var _recorded: bool = false
var _lent_weapons: Array[StringName] = []
var _lent_gadgets: Array[StringName] = []
## Saved pickup id -> SavedPickup.kind(), for every one placed in the level.
var _pickup_kinds: Dictionary = {}
## Saved pickup id -> true once taken (this visit or an earlier one).
var _pickups_found: Dictionary = {}


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
	var resume := saved_checkpoint()
	if resume != null:
		player.position = to_local(resume.spawn_position())
		player.rotation.y = resume.global_rotation.y
	add_child(player)
	if uses_save:
		SaveGame.profile.apply(player)
	_register_pickups()
	if resume != null:
		resume.activate(player)
	for id: StringName in starting_gadgets:
		if not player.has_gadget(id):
			_lent_gadgets.append(id)
		player.unlock_gadget(id)
	if lend_all_weapons:
		for w: Weapon in player.weapons:
			if not w.owned:
				w.owned = true
				_lent_weapons.append(w.data.id)
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
	pause_menu.save_reset_requested.connect(reset_save)
	# After the pause menu, so it sees Start / Esc first while open.
	shop_menu = ShopMenu.new()
	add_child(shop_menu)
	for n: Node in get_tree().get_nodes_in_group(MagpiePeddler.GROUP):
		if is_ancestor_of(n):
			(n as MagpiePeddler).trade_requested.connect(func(_p: MagpiePeddler) -> void: shop_menu.open(player))
	if uses_save:
		_connect_saving()
	if wave_manager != null and wave_manager.autostart:
		wave_manager.start()


func _exit_tree() -> void:
	save_progress()


# --- Saving ---------------------------------------------------------------------

## Copies the player into the save profile and writes it (no-op without uses_save).
func save_progress() -> void:
	if not uses_save or player == null or not is_instance_valid(player):
		return
	SaveGame.profile.capture(player, _lent_weapons, _lent_gadgets)
	SaveGame.save()


## The save's last checkpoint if it is in this level, else null.
func saved_checkpoint() -> Checkpoint:
	var p := SaveGame.profile
	if not uses_save or p.checkpoint_level == "" or p.checkpoint_level != scene_file_path:
		return null
	return get_node_or_null(NodePath(p.checkpoint_node)) as Checkpoint


## Key for this level's entries in Profile.collected.
func save_key() -> String:
	return level_name(scene_file_path) if scene_file_path != "" else String(name)


func pickup_id(pickup: Node) -> String:
	return str(get_path_to(pickup))


## Saved pickups still in this level (not taken).
func saved_pickups() -> Array[SavedPickup]:
	var out: Array[SavedPickup] = []
	for n: Node in get_tree().get_nodes_in_group(SavedPickup.GROUP):
		var s := n as SavedPickup
		if s != null and is_ancestor_of(s) and not s.is_taken and not s.is_queued_for_deletion():
			out.append(s)
	return out


## Per pickup kind (SavedPickup.kind()): Vector2i(found, placed) in this level,
## counting ones taken on earlier visits (from the save).
func pickup_tally() -> Dictionary:
	var out := {}
	for id: String in _pickup_kinds:
		var kind: StringName = _pickup_kinds[id]
		var t: Vector2i = out.get(kind, Vector2i.ZERO)
		out[kind] = t + Vector2i(1 if _pickups_found.has(id) else 0, 1)
	return out


## Records every saved pickup; frees the ones the save already took.
func _register_pickups() -> void:
	for s: SavedPickup in saved_pickups():
		var id := pickup_id(s)
		_pickup_kinds[id] = s.kind()
		if uses_save and SaveGame.profile.has_collected(save_key(), id):
			_pickups_found[id] = true
			s.is_taken = true
			s.remove_from_group(SavedPickup.GROUP)
			s.queue_free()
		else:
			s.taken.connect(_on_pickup_taken)


func _on_pickup_taken(s: SavedPickup) -> void:
	var id := pickup_id(s)
	_pickups_found[id] = true
	if uses_save:
		SaveGame.profile.mark_collected(save_key(), id)
		save_progress()


func _connect_saving() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"checkpoints"):
		if is_ancestor_of(n):
			var cp := n as Checkpoint
			cp.activated.connect(func(_p: Player) -> void:
				SaveGame.profile.set_checkpoint(scene_file_path, str(get_path_to(cp)))
				save_progress())
	player.gadgets.unlocked_gadget.connect(func(_id: StringName) -> void: save_progress())
	player.respawned.connect(save_progress)
	shop_menu.purchased.connect(func(_item: StringName) -> void: save_progress())


## Pause menu Debug page: wipe the save and start this level over.
func reset_save() -> void:
	uses_save = false  # nothing from this run gets written on the way out
	SaveGame.wipe()
	restart()


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed(&"debug_next_wave") and wave_manager != null:
		wave_manager.spawn_next_wave()
	elif event.is_action_pressed(&"debug_give_xp"):
		player.debug_level_current_weapon()


## Fresh level from its PlayerSpawn: new waves, full health and ammo. Saved
## progress stays (in the arena, which never saves, weapon levels reset).
func restart() -> void:
	if uses_save and SaveGame.profile.checkpoint_level == scene_file_path:
		SaveGame.profile.clear_checkpoint()
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

## Sky, sun, haze, ambient occlusion and grading from the level's theme (the setting's mood).
func _build_environment() -> void:
	var theme := level_theme if level_theme != null else LevelTheme.default_theme()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_horizon_color = theme.ground_horizon
	sky_mat.ground_bottom_color = theme.ground_bottom
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = theme.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	# Contact shadows where blocks, props and characters meet.
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = theme.ssao_intensity
	env.ssao_detail = 0.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = theme.fog_color
	env.fog_density = theme.fog_density
	env.fog_sky_affect = theme.fog_sky_affect
	env.fog_aerial_perspective = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = theme.saturation
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(theme.sun_angle.x, theme.sun_angle.y, 0)
	sun.light_energy = theme.sun_energy
	sun.light_color = theme.sun_color
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
