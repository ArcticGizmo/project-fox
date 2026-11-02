class_name WaveManager
extends Node3D
## Spawns enemy waves at child Marker3D spawn points. When a wave is cleared
## the next starts after a delay. After the last wave it loops with +1 of
## every enemy type per loop.

signal wave_started(number: int)
signal wave_cleared(number: int)

const ENEMY_SCENES: Dictionary = {
	&"rat": preload("res://scenes/enemies/clockwork_rat.tscn"),
	&"toad": preload("res://scenes/enemies/spitter_toad.tscn"),
	&"bull": preload("res://scenes/enemies/brass_bull.tscn"),
	&"falcon": preload("res://scenes/enemies/brass_falcon.tscn"),
	&"gull": preload("res://scenes/enemies/bombardier_gull.tscn"),
	&"pangolin": preload("res://scenes/enemies/brass_pangolin.tscn"),
	&"heron": preload("res://scenes/enemies/chime_heron.tscn"),
	&"beetle": preload("res://scenes/enemies/coal_beetle.tscn"),
	&"rogue": preload("res://scenes/enemies/raccoon_rogue.tscn"),
	&"bee": preload("res://scenes/enemies/clockwork_honeybee.tscn"),
	&"sentinel": preload("res://scenes/enemies/ironhorn_sentinel.tscn"),
}

@export var autostart: bool = true
@export var first_wave_delay: float = 1.5
@export var delay_between_waves: float = 3.0

var waves: Array[Dictionary] = [
	{&"rat": 4},
	{&"falcon": 3},
	{&"toad": 2, &"rat": 2},
	{&"gull": 2, &"rat": 3},
	{&"bull": 1, &"falcon": 2},
	{&"pangolin": 1, &"rat": 4, &"heron": 1},
	{&"toad": 2, &"gull": 2, &"falcon": 2, &"pangolin": 1},
	{&"toad": 3, &"bull": 1, &"rat": 3, &"gull": 1, &"heron": 1},
	{&"beetle": 2, &"rogue": 2, &"rat": 2},
	{&"bee": 5, &"sentinel": 1},
]
var wave_number: int = 0
var alive: Array[Enemy] = []

var _next_wave_timer: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func start() -> void:
	_next_wave_timer = first_wave_delay


func _physics_process(delta: float) -> void:
	alive.assign(alive.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not (e as Enemy).health.is_dead))
	if wave_number > 0 and alive.is_empty() and _next_wave_timer < 0.0:
		wave_cleared.emit(wave_number)
		_next_wave_timer = delay_between_waves
	if _next_wave_timer >= 0.0:
		_next_wave_timer -= delta
		if _next_wave_timer < 0.0:
			spawn_next_wave()


func spawn_next_wave() -> void:
	_next_wave_timer = -1.0
	wave_number += 1
	var index := (wave_number - 1) % waves.size()
	var loop := floori(float(wave_number - 1) / waves.size())
	var markers := _spawn_markers()
	if markers.is_empty():
		push_error("WaveManager has no Marker3D spawn points")
		return
	var wave := waves[index]
	for kind: StringName in wave:
		var count := int(wave[kind]) + loop
		var marker := markers[_rng.randi() % markers.size()]
		for i: int in count:
			var offset := Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
			spawn_enemy(kind, marker.global_position + offset)
	wave_started.emit(wave_number)


func spawn_enemy(kind: StringName, at: Vector3) -> Enemy:
	var scene := ENEMY_SCENES[kind] as PackedScene
	var enemy := scene.instantiate() as Enemy
	enemy.position = at
	enemy.rotation.y = Player.yaw_of(-at)
	enemy.make_always_aware()
	get_parent().add_child(enemy)
	alive.append(enemy)
	return enemy


func _spawn_markers() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for c: Node in get_children():
		if c is Marker3D:
			out.append(c as Marker3D)
	return out
