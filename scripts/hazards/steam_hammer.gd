class_name SteamHammer
extends Hazard
## A steam press on an overhead rail (local X, posts at both ends). It slides
## after the nearest creature, player or enemy, within `track_reach` of the
## line, then stops, rises with a judder while its floor shadow pulses red,
## and slams down. Step out from under it during the wind-up, or bait it onto
## enemies (which are staggered). The head is not solid.
## States: track -> windup -> slam -> down -> rise -> track.

const TRACK := &"track"
const WINDUP := &"windup"
const SLAM := &"slam"
const DOWN := &"down"
const RISE := &"rise"
const WINDUP_LIFT := 0.6
const SHADOW_COLOR := Color(0.9, 0.1, 0.05)
const SHAKE_RADIUS := 12.0

@export var rail_length: float = 16.0
@export var rail_height: float = 7.0
## Square head, metres per side.
@export var head_size: float = 2.4
## Height of the head's underside between slams.
@export var rest_height: float = 4.0
## Creatures further than this from the rail line are ignored.
@export var track_reach: float = 3.0
@export var track_speed: float = 5.0
## Minimum time spent tracking before a slam.
@export var track_time: float = 2.0
@export var windup_time: float = 0.7
@export var slam_speed: float = 30.0
@export var down_time: float = 1.0
@export var rise_time: float = 1.0
@export var damage: float = 35.0
@export var knockback: float = 12.0
@export var knockback_up: float = 6.0
@export var enemy_stagger: float = 1.0

var hit_box: HitBox
## Carriage position along the rail (local X).
var carriage_x: float = 0.0
## Height of the head's underside above the ground.
var head_bottom: float = 0.0
var target: Node3D = null

var _carriage: Node3D
var _head: Node3D
var _rod: MeshInstance3D
var _head_material: StandardMaterial3D
var _shadow: MeshInstance3D
var _shadow_material: StandardMaterial3D


func _setup() -> void:
	head_bottom = rest_height
	var half := rail_length * 0.5
	var iron := Color(0.3, 0.28, 0.27)
	for side: float in [-1.0, 1.0]:
		var post := Block.new()
		post.size = Vector3(0.6, rail_height + 0.4, 0.6)
		post.color = iron
		post.position = Vector3(side * (half + 0.6), (rail_height + 0.4) * 0.5, 0)
		add_child(post)
	add_box(Vector3(rail_length + 1.8, 0.4, 0.5), Vector3(0, rail_height + 0.2, 0), flat_material(iron, 0.6, 0.5))

	_carriage = Node3D.new()
	_carriage.name = "Carriage"
	add_child(_carriage)
	var brass := flat_material(Color(0.8, 0.6, 0.25), 0.35, 0.8)
	add_box(Vector3(1.0, 0.6, 0.9), Vector3(0, rail_height - 0.1, 0), brass, _carriage)
	_rod = add_box(Vector3(0.3, 1.0, 0.3), Vector3.ZERO, flat_material(Color(0.7, 0.7, 0.72), 0.3, 0.9), _carriage)

	_head = Node3D.new()
	_head.name = "Head"
	_carriage.add_child(_head)
	_head_material = glow_material(Color(0.25, 0.23, 0.22))
	_head_material.metallic = 0.6
	_head_material.roughness = 0.5
	add_box(Vector3(head_size, 1.0, head_size), Vector3(0, 0.5, 0), _head_material, _head)
	add_box(Vector3(head_size + 0.1, 0.15, head_size + 0.1), Vector3(0, 0.85, 0), brass, _head)
	add_box(Vector3(head_size + 0.1, 0.15, head_size + 0.1), Vector3(0, 0.15, 0), brass, _head)

	var disc := CylinderMesh.new()
	disc.top_radius = head_size * 0.6
	disc.bottom_radius = head_size * 0.6
	disc.height = 0.02
	_shadow_material = glow_material(Color(SHADOW_COLOR, 0.2), true)
	_shadow = add_mesh(disc, Vector3(0, 0.02, 0), _shadow_material, _carriage)
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Taller than one frame of slam travel so it cannot tunnel through anyone.
	hit_box = make_hit_box("HeadHitBox", Vector3(head_size * 0.95, 1.4, head_size * 0.95), Vector3(0, 0.5, 0),
			damage, knockback, knockback_up, _head)
	hit_box.hit_landed.connect(_on_hit_landed)
	enter_state(TRACK)
	_update_pose()


func _tick_state(delta: float) -> void:
	match state:
		TRACK:
			target = _nearest_creature()
			if target != null:
				var goal := clampf(to_local(target.global_position).x, -rail_length * 0.5, rail_length * 0.5)
				carriage_x = move_toward(carriage_x, goal, track_speed * delta)
				if state_time >= track_time:
					enter_state(WINDUP)
			else:
				state_time = 0.0
		WINDUP:
			var t := state_time / windup_time
			head_bottom = rest_height + WINDUP_LIFT * t + 0.05 * sin(_age * 70.0) * t
			_head_material.emission = SHADOW_COLOR * 0.8 * t
			_shadow_material.albedo_color.a = lerpf(0.25, 0.8, t) * (0.75 + 0.25 * sin(_age * 25.0))
			if state_time >= windup_time:
				enter_state(SLAM)
		SLAM:
			head_bottom = maxf(0.0, head_bottom - slam_speed * delta)
			if head_bottom <= 0.0:
				_impact()
				enter_state(DOWN)
		DOWN:
			if state_time >= down_time:
				enter_state(RISE)
		RISE:
			head_bottom = lerpf(0.0, rest_height, clampf(state_time / rise_time, 0.0, 1.0))
			if state_time >= rise_time:
				enter_state(TRACK)
	_update_pose()


func _on_enter_state(new_state: StringName) -> void:
	hit_box.active = new_state == SLAM
	if new_state == TRACK or new_state == DOWN:
		_head_material.emission = Color.BLACK
		_shadow_material.albedo_color.a = 0.2


func _update_pose() -> void:
	_carriage.position.x = carriage_x
	_head.position.y = head_bottom
	var rod_top := rail_height - 0.4
	var rod_bottom := head_bottom + 1.0
	_rod.scale.y = maxf(0.01, rod_top - rod_bottom)
	_rod.position.y = (rod_top + rod_bottom) * 0.5


## Closest living ground creature near the rail line (players and enemies alike).
func _nearest_creature() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	var candidates: Array[Node] = get_tree().get_nodes_in_group(&"player")
	candidates.append_array(get_tree().get_nodes_in_group(&"enemies"))
	for n: Node in candidates:
		var body := n as Node3D
		if body == null:
			continue
		var e := body as Enemy
		if e != null and (e.flying or e.health.is_dead):
			continue
		var player := body as Player
		if player != null and player.is_dead:
			continue
		var local := to_local(body.global_position)
		if absf(local.z) > track_reach or absf(local.x) > rail_length * 0.5 + head_size:
			continue
		var d := absf(local.x - carriage_x)
		if d < best_dist:
			best = body
			best_dist = d
	return best


func _impact() -> void:
	var foot := to_global(Vector3(carriage_x, 0.1, 0))
	GameFeel.impact(foot, Color(0.9, 0.9, 0.9, 0.6), head_size * 2.2, 0.35)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		var d := player.global_position.distance_to(foot)
		if d < SHAKE_RADIUS:
			GameFeel.shake(0.8 * (1.0 - d / SHAKE_RADIUS))


func _on_hit_landed(hb: HurtBox, _info: DamageInfo) -> void:
	var e := enemy_hit(hb)
	if e != null:
		e.stagger(enemy_stagger)
