class_name FoxModel
extends Node3D
## The fox's rigged mesh (Ember_the_Foxling.glb, Mixamo skeleton). Pure presentation:
## the player calls `update()` each frame with its ground speed and `flash` for hurt.
##
## The GLB ships one in-place "Running" clip and a T-pose; "Idle" and "Walk" are baked
## here from the rest pose. Poses are written as rotations about the model's own axes
## (X = the fox's left, Y = up, Z = forward, as authored in the GLB) applied to each
## bone in its rest frame, so a child's rotation rides on its parent's:
##   pitch +  thigh/arm swings back, shin/forearm folds back, spine leans forward, toes point down
##   yaw   +  turns toward the fox's left
##   roll  +  tips the top of an upright bone toward the fox's right
##
## Locomotion picks a clip by ground speed (with hysteresis between walk and run) and
## scales its playback so the feet keep pace with the body.

const SCENE: PackedScene = preload("res://imported_models/Ember_the_Foxling/Ember_the_Foxling.glb")
const SKELETON_PATH := "SmartRigArmature/Skeleton3D:%s"
## Authored height of the GLB (ear tips), scaled up to the player's capsule.
const MODEL_HEIGHT := 1.7

## Ground speeds each clip's cadence was authored for; playback scales from these.
const WALK_CLIP_SPEED := 2.4
const RUN_CLIP_SPEED := 7.0
## Below IDLE_SPEED the fox stands; walk/run switch at RUN_ENTER_SPEED going up and
## RUN_EXIT_SPEED coming down so a stick held near the threshold doesn't flicker.
const IDLE_SPEED := 0.35
const RUN_ENTER_SPEED := 4.0
const RUN_EXIT_SPEED := 3.2
const BLEND_TIME := 0.2

const IDLE_LENGTH := 3.2
const WALK_LENGTH := 0.9
## Keys per baked cycle (plus a closing key).
const SAMPLES := 32

## Arms hang this far below the T-pose (degrees), a little forward and bent at the elbow.
const ARM_DROP := 68.0

const HIPS := &"mixamorig_Hips"
const SPINE := &"mixamorig_Spine"
const SPINE1 := &"mixamorig_Spine1"
const SPINE2 := &"mixamorig_Spine2"
const NECK := &"mixamorig_Neck"
const HEAD := &"mixamorig_Head"
const L_SHOULDER := &"mixamorig_LeftShoulder"
const R_SHOULDER := &"mixamorig_RightShoulder"
const L_ARM := &"mixamorig_LeftArm"
const R_ARM := &"mixamorig_RightArm"
const L_FOREARM := &"mixamorig_LeftForeArm"
const R_FOREARM := &"mixamorig_RightForeArm"
const L_THIGH := &"mixamorig_LeftUpLeg"
const R_THIGH := &"mixamorig_RightUpLeg"
const L_SHIN := &"mixamorig_LeftLeg"
const R_SHIN := &"mixamorig_RightLeg"
const L_FOOT := &"mixamorig_LeftFoot"
const R_FOOT := &"mixamorig_RightFoot"
## Key in a pose Dictionary for the hips' translation (model space, metres).
const HIPS_OFFSET := &"hips_offset"

var skeleton: Skeleton3D
var anim: AnimationPlayer
var material: StandardMaterial3D


func _init(height: float = MODEL_HEIGHT) -> void:
	name = "FoxModel"
	var model := SCENE.instantiate() as Node3D
	# The GLB faces +Z; the player faces -Z.
	model.rotation.y = PI
	model.scale = Vector3.ONE * (height / MODEL_HEIGHT)
	add_child(model)
	skeleton = model.find_child("Skeleton3D") as Skeleton3D
	anim = model.find_child("AnimationPlayer") as AnimationPlayer

	# Own copy of the material so the hurt flash doesn't touch the imported resource.
	var mesh := skeleton.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D
	material = (mesh.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color.BLACK
	mesh.set_surface_override_material(0, material)

	var lib := AnimationLibrary.new()
	var run := anim.get_animation(&"Running").duplicate() as Animation
	run.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(&"Running", run)
	lib.add_animation(&"Idle", _bake(IDLE_LENGTH, _idle_pose))
	lib.add_animation(&"Walk", _bake(WALK_LENGTH, _walk_pose))
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", lib)
	anim.play(&"Idle")


## `speed` is horizontal ground speed; airborne poses fall back to idle for now.
func update(speed: float, on_floor: bool) -> void:
	var clip := &"Idle"
	if on_floor and speed > IDLE_SPEED:
		var running := anim.current_animation == &"Running"
		clip = &"Running" if speed > (RUN_EXIT_SPEED if running else RUN_ENTER_SPEED) else &"Walk"
	if anim.current_animation != clip:
		anim.play(clip, BLEND_TIME)
	match clip:
		&"Running":
			anim.speed_scale = clampf(speed / RUN_CLIP_SPEED, 0.6, 1.6)
		&"Walk":
			anim.speed_scale = clampf(speed / WALK_CLIP_SPEED, 0.5, 1.6)
		_:
			anim.speed_scale = 1.0


func flash(amount: float) -> void:
	material.emission = Color(1.0, 0.1, 0.1) * amount


# --- Poses --------------------------------------------------------------------------
# Each takes the cycle phase p in [0, 1) and returns {bone: Quaternion (model axes),
# HIPS_OFFSET: Vector3}. Every call must return the same keys.

## A relaxed, slightly knee-soft stance: breathing (chest and shoulders rise), a slow
## weight shift between the feet, and an unhurried look around. The harmonics are whole
## numbers of cycles so the loop closes; mixing them keeps it from reading as one sine.
func _idle_pose(p: float) -> Dictionary:
	var breath := sin(TAU * p * 2.0)  # two breaths per loop
	var shift := sin(TAU * p)  # weight to the left foot, then the right
	var look := sin(TAU * p + 0.6) * 0.7 + sin(TAU * p * 3.0) * 0.3
	var knee := 7.0
	var thigh := 4.0 + shift * 1.0
	var pose := {
		HIPS_OFFSET: Vector3(shift * 0.012, -0.012 - absf(shift) * 0.004, 0.0),
		HIPS: _roll(shift * 1.5),  # the free leg's hip drops
		SPINE: _roll(-shift * 1.2),
		SPINE1: _pitch(2.0 - breath * 1.5),
		SPINE2: _pitch(-breath * 1.0),
		NECK: _pitch(-1.0),
		HEAD: _yaw(look * 7.0) * _pitch(1.5 + breath * 1.0) * _roll(shift * 1.0),
		L_SHOULDER: _roll(breath * 2.0),
		R_SHOULDER: _roll(-breath * 2.0),
	}
	_set_arms(pose, breath * 2.0, -breath * 2.0, 14.0, 14.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, thigh, knee + shift * 2.0, 0.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, thigh, knee - shift * 2.0, 0.0)
	return pose


## Two steps per cycle, phase 0 = left heel strike. Classic beats: contact (leg reaching,
## heel down, toe up), down (knee takes the weight, body at its lowest), passing (swing
## knee high, body rising), up (pushing off the toe, body at its highest). Pelvis twists
## toward the reaching leg and the chest counter-twists; arms swing against the legs,
## a beat late, elbows folding as they come forward; the head holds steady.
func _walk_pose(p: float) -> Dictionary:
	var stride := cos(TAU * p)  # +1: left leg forward, -1: right leg forward
	var bob := -cos(TAU * 2.0 * (p - 0.08))  # lowest just after each contact
	var sway := sin(TAU * p)  # over the standing foot
	var arm := cos(TAU * (p - 0.06))  # follows through slightly behind the legs
	var pose := {
		HIPS_OFFSET: Vector3(sway * 0.018, bob * 0.022 - 0.008, 0.0),
		HIPS: _yaw(-stride * 7.0) * _roll(sway * 2.0),
		SPINE: _pitch(3.0) * _roll(-sway * 1.5),
		SPINE1: _pitch(1.0),
		SPINE2: _yaw(stride * 11.0) * _pitch(bob * 1.0),
		NECK: _yaw(-stride * 2.0),
		HEAD: _yaw(-stride * 2.0) * _pitch(-2.0 - bob * 1.5),
		L_SHOULDER: _roll(-arm * 2.0),
		R_SHOULDER: _roll(-arm * 2.0),
	}
	_set_arms(pose, -arm * 22.0, arm * 22.0, 14.0 + maxf(-arm, 0.0) * 22.0, 14.0 + maxf(arm, 0.0) * 22.0)
	_walk_leg(pose, L_THIGH, L_SHIN, L_FOOT, p)
	_walk_leg(pose, R_THIGH, R_SHIN, R_FOOT, wrapf(p + 0.5, 0.0, 1.0))
	return pose


## One leg's walk, `p` = 0 at its own heel strike. Stance (0 to ~0.55): the leg sweeps
## back under the body, knee giving at the load and straightening for push-off.
## Swing (~0.55 to 1): knee folds high at passing, the shin reaches out for the next step.
func _walk_leg(pose: Dictionary, thigh: StringName, shin: StringName, foot: StringName, p: float) -> void:
	var forward := cos(TAU * p) * 27.0
	var knee := 5.0 + 16.0 * _bump(p, 0.12, 0.07) + 58.0 * _bump(p, 0.76, 0.12)
	var stance := _plateau(p, 0.04, 0.5, 0.06)
	# Heel strike toe-up, then a push off the toes, then toes lifted to clear the floor.
	var ankle := -14.0 * _bump(p, 0.0, 0.05) + 26.0 * _bump(p, 0.6, 0.06) - 10.0 * _bump(p, 0.85, 0.08)
	# During stance the foot stays flat: cancel the thigh and knee pitch it inherits.
	ankle += stance * (forward - knee)
	_set_leg(pose, thigh, shin, foot, forward, knee, ankle)


## `forward` swings the thigh forward, `knee` folds the shin back, `ankle` points the
## toes down (all degrees, on top of whatever the parent does).
func _set_leg(pose: Dictionary, thigh: StringName, shin: StringName, foot: StringName,
		forward: float, knee: float, ankle: float) -> void:
	pose[thigh] = _pitch(-forward)
	pose[shin] = _pitch(knee)
	pose[foot] = _pitch(ankle)


## Drops both arms out of the T-pose. `swing_*` swings each arm forward (degrees),
## `elbow_*` folds the forearm forward.
func _set_arms(pose: Dictionary, swing_l: float, swing_r: float, elbow_l: float, elbow_r: float) -> void:
	# Lowered about Z, then swung about X so the swing is always fore/aft.
	pose[L_ARM] = _pitch(-swing_l - 6.0) * _roll(-ARM_DROP)
	pose[R_ARM] = _pitch(-swing_r - 6.0) * _roll(ARM_DROP)
	# Elbows bend in the T-pose frame (forearm toward +Z), which stays "forward" once lowered.
	pose[L_FOREARM] = _yaw(-elbow_l)
	pose[R_FOREARM] = _yaw(elbow_r)


# --- Baking -------------------------------------------------------------------------

## Samples `pose` over one loop into rotation tracks (and a hips position track).
func _bake(length: float, pose: Callable) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	for i: int in SAMPLES + 1:
		var p := float(i) / SAMPLES
		var time := length * p
		var frame: Dictionary = pose.call(wrapf(p, 0.0, 1.0))
		for key: StringName in frame:
			var bone := skeleton.find_bone(HIPS if key == HIPS_OFFSET else key)
			if not tracks.has(key):
				var t := a.add_track(Animation.TYPE_POSITION_3D if key == HIPS_OFFSET else Animation.TYPE_ROTATION_3D)
				a.track_set_path(t, NodePath(SKELETON_PATH % skeleton.get_bone_name(bone)))
				tracks[key] = t
			var track: int = tracks[key]
			if key == HIPS_OFFSET:
				a.position_track_insert_key(track, time, skeleton.get_bone_rest(bone).origin + (frame[key] as Vector3))
			else:
				a.rotation_track_insert_key(track, time, _local_rotation(bone, frame[key] as Quaternion))
	return a


## Turns a rotation about the model's axes, applied to `bone` in its rest frame, into the
## bone's local pose rotation: rest_local * (G⁻¹ R G), with G its global rest rotation.
func _local_rotation(bone: int, r: Quaternion) -> Quaternion:
	var g := skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	return (rest * (g.inverse() * r * g)).normalized()


static func _pitch(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(deg))


static func _yaw(deg: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(deg))


static func _roll(deg: float) -> Quaternion:
	return Quaternion(Vector3.BACK, deg_to_rad(deg))


## Smooth periodic pulse centred on `center` (phase units), 1 at the peak.
static func _bump(p: float, center: float, width: float) -> float:
	var d := wrapf(p - center, -0.5, 0.5)
	return exp(-d * d / (2.0 * width * width))


## 1 between `from` and `to`, easing to 0 over `edge` either side.
static func _plateau(p: float, from: float, to: float, edge: float) -> float:
	return smoothstep(from - edge, from, p) * (1.0 - smoothstep(to, to + edge, p))
