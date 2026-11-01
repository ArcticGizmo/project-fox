class_name AnimShowcase
extends Node3D
## Builds the fox animation gallery at runtime (scenes/levels/anim_showcase.tscn):
## - Front row: one pedestal per clip in FoxModel's library, looping at full speed
##   (one-shot clips replay after a short pause), each labelled.
## - Back row: the same clips at quarter speed, to read the poses.
## - A lap track: one fox walking and one running laps at their clips' authored speeds,
##   so foot slide and cadence can be judged against real ground travel.
## - A ramp lane: a fox that speeds up from standing to a sprint and back, showing the
##   idle/walk/run picks and blends the player gets; its label shows the speed.
## New clips added to FoxModel show up here automatically.

const SPACING := 2.6
const SLOW_SCALE := 0.25
const ONE_SHOT_GAP := 0.6
const LAP_RADIUS := 6.0
const LAP_CENTER := Vector3(0, 0, 16)
const RAMP_START := Vector3(-14, 0, 30)
const RAMP_LENGTH := 28.0
## Peak speed on the ramp lane; matches the player's run speed.
const RAMP_PEAK := 8.5
const RAMP_ACCEL := 3.0

var _lappers: Array[Dictionary] = []
var _ramp_fox: FoxModel
var _ramp_label: Label3D
var _ramp_speed: float = 0.0
var _ramp_dir: float = 1.0
var _ramp_braking: bool = false


func _ready() -> void:
	var probe := FoxModel.new(Player.HEIGHT)
	var clips := Array(probe.anim.get_animation_list())
	probe.free()
	clips.sort()
	var width := (clips.size() - 1) * SPACING
	for i: int in clips.size():
		var x := -width * 0.5 + i * SPACING
		var clip: StringName = clips[i]
		_pedestal(Vector3(x, 0, 0), clip, 1.0, String(clip))
		_pedestal(Vector3(x, 0, -4.0), clip, SLOW_SCALE, "%s  ¼×" % clip)
	_lapper(&"Walk", FoxModel.WALK_CLIP_SPEED, 0.0)
	_lapper(&"Running", FoxModel.RUN_CLIP_SPEED, PI)
	_label(LAP_CENTER + Vector3(0, 0.6, 0), "Laps at authored speeds\nwalk %.1f m/s · run %.1f m/s" %
			[FoxModel.WALK_CLIP_SPEED, FoxModel.RUN_CLIP_SPEED], 48)
	_ramp_fox = FoxModel.new(Player.HEIGHT)
	add_child(_ramp_fox)
	_ramp_fox.position = RAMP_START
	_ramp_fox.rotation.y = -PI * 0.5
	_ramp_label = _label(Vector3.ZERO, "", 40)
	_lane_marks()


func _physics_process(delta: float) -> void:
	for lap: Dictionary in _lappers:
		var fox: FoxModel = lap.fox
		var angle: float = lap.angle + (lap.speed as float) / LAP_RADIUS * delta
		lap.angle = angle
		fox.position = LAP_CENTER + Vector3(cos(angle), 0, sin(angle)) * LAP_RADIUS
		# The fox faces -Z; this yaw turns -Z onto the circle's tangent.
		fox.rotation.y = PI - angle
		fox.update(lap.speed as float, true)
	_tick_ramp(delta)


## Speeds up along the lane, brakes before the end, stands a beat, turns, repeats.
func _tick_ramp(delta: float) -> void:
	var start_x := RAMP_START.x
	var travelled := (_ramp_fox.position.x - start_x) if _ramp_dir > 0.0 else (start_x + RAMP_LENGTH - _ramp_fox.position.x)
	var stop_distance := _ramp_speed * _ramp_speed / (2.0 * RAMP_ACCEL)
	if not _ramp_braking and travelled + stop_distance >= RAMP_LENGTH:
		_ramp_braking = true
	if _ramp_braking:
		_ramp_speed = maxf(_ramp_speed - RAMP_ACCEL * delta, 0.0)
		if _ramp_speed == 0.0:
			_ramp_braking = false
			_ramp_dir = -_ramp_dir
			_ramp_fox.rotation.y = -PI * 0.5 * _ramp_dir
			_ramp_speed = -1.5  # a moment standing before setting off again
	else:
		_ramp_speed = minf(_ramp_speed + RAMP_ACCEL * delta, RAMP_PEAK)
	var speed := maxf(_ramp_speed, 0.0)
	_ramp_fox.position.x += speed * _ramp_dir * delta
	_ramp_fox.update(speed, true)
	_ramp_label.position = _ramp_fox.position + Vector3.UP * 2.4
	_ramp_label.text = "%.1f m/s  %s" % [speed, _ramp_fox.anim.current_animation]


func _pedestal(at: Vector3, clip: StringName, speed_scale: float, title: String) -> void:
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.9
	cyl.height = 0.2
	base.mesh = cyl
	base.position = at + Vector3.UP * 0.1
	add_child(base)
	var fox := FoxModel.new(Player.HEIGHT)
	add_child(fox)
	fox.position = at + Vector3.UP * 0.2
	# Three-quarter view toward the spawn.
	fox.rotation.y = PI + 0.5
	fox.anim.speed_scale = speed_scale
	fox.anim.play(clip)
	if fox.anim.get_animation(clip).loop_mode == Animation.LOOP_NONE:
		fox.anim.animation_finished.connect(func(_name: StringName) -> void:
			get_tree().create_timer(ONE_SHOT_GAP).timeout.connect(func() -> void: fox.anim.play(clip)))
	_label(at + Vector3.UP * 2.5, title, 40)


func _lapper(clip: StringName, speed: float, angle: float) -> void:
	var fox := FoxModel.new(Player.HEIGHT)
	add_child(fox)
	fox.anim.play(clip)
	_lappers.append({fox = fox, speed = speed, angle = angle})


func _lane_marks() -> void:
	for i: int in int(RAMP_LENGTH / 2.0) + 1:
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.02, 1.2)
		tick.mesh = box
		tick.position = RAMP_START + Vector3(i * 2.0, 0.01, 0)
		add_child(tick)
	_label(RAMP_START + Vector3(RAMP_LENGTH * 0.5, 0.6, 2.0), "Speed ramp (2 m ticks)", 40)


func _label(at: Vector3, text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	add_child(l)
	return l
