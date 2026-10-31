extends Node3D
## Grey-box combat arena: spawns the player and HUD, sets up lighting and
## runs the wave manager. Level geometry lives in scenes/main.tscn as Blocks.

const PLAYER_TUNING := preload("res://data/player_tuning.tres")

var player: Player
var hud: Hud
var pause_menu: PauseMenu

@onready var wave_manager: WaveManager = $WaveManager
@onready var player_spawn: Marker3D = $PlayerSpawn


func _ready() -> void:
	_build_environment()
	player = Player.new()
	player.name = "Player"
	player.tuning = PLAYER_TUNING
	player.position = player_spawn.position
	player.rotation.y = player_spawn.rotation.y
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, wave_manager)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart_requested.connect(restart)
	if wave_manager.autostart:
		wave_manager.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_next_wave"):
		wave_manager.spawn_next_wave()
	elif event.is_action_pressed(&"debug_give_xp"):
		player.debug_level_current_weapon()


## Fresh arena: new waves, full health and ammo, weapon levels reset.
func restart() -> void:
	get_tree().paused = false
	GameFeel.reset()
	get_tree().reload_current_scene()


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
