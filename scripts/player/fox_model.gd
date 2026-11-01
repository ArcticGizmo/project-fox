class_name FoxModel
extends Node3D
## The fox's rigged mesh (Ember_the_Foxling.glb, Mixamo skeleton). Pure presentation:
## the player calls `update()` each frame with its motion and state, `play_action()` for
## one-shots, `aim()` for the gun arm, and `flash` for hurt. The gun rides in the right
## hand (`gun_mount`); `FoxAimLayer` raises that arm over whatever clip is playing.
##
## The GLB ships one in-place "Running" clip and a T-pose; every other clip is baked here
## from the rest pose (locomotion, air, actions, staff: see the pose functions). Clip
## lengths that must match gameplay timing (swings, slam recovery) come from PlayerTuning.
## Poses are written as rotations about the model's own axes (X = the fox's left, Y = up,
## Z = forward, as authored in the GLB) applied to each bone in its rest frame, so a
## child's rotation rides on its parent's:
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

## Crossfade into one-shots and held states: short, so actions read immediately.
const ACTION_BLEND_TIME := 0.06
## Rising faster than this (m/s) shows the jump pose; slower, the fall.
const APEX_SPEED := 1.5
## Shorter hops land without the squash.
const LAND_MIN_AIR_TIME := 0.3

const IDLE_LENGTH := 3.2
const WALK_LENGTH := 0.9
const JUMP_LENGTH := 0.5
const FALL_LENGTH := 0.8
const DOUBLE_JUMP_LENGTH := 0.42
const LAND_LENGTH := 0.32
## Covers the dodge (0.22 s) plus a beat, so a dodge never runs out of clip.
const DODGE_LENGTH := 0.3
const HURT_LENGTH := 0.4
const SLAM_RISE_LENGTH := 0.4
const SLAM_FALL_LENGTH := 0.3
const GLIDE_LENGTH := 1.6
const REEL_LENGTH := 0.5
## Swing clips by combo step: the two alternating sweeps, then the overhead finisher.
const SWINGS: Array[StringName] = [&"SwingRight", &"SwingLeft", &"SwingOverhead"]

## Hips turn toward the travel direction up to this far (degrees) while the chest keeps facing.
const TWIST_MAX := 65.0
## Travel more than this far (degrees) from facing plays locomotion backwards instead.
const BACKWARD_ANGLE := 105.0
## How fast the hip twist follows (per second, exponential).
const TWIST_RATE := 10.0
## How fast the gun arm rises to aim / drops back (influence per second).
const AIM_RATE := 10.0
## Re-solve the aim arm when the aim pitch moves this far (degrees).
const AIM_PITCH_STEP := 2.0
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
## Follows the right hand; its -Z runs along the forearm (the gun's barrel direction).
var gun_mount: Node3D
var aim_layer: FoxAimLayer
var twist_layer: FoxTwistLayer

var _tuning: PlayerTuning
## Clip last started (locomotion, hold or action), so held one-shots don't restart.
var _playing: StringName = &""
var _action: StringName = &""
var _aim_target: float = 0.0
var _aim_pitch: float = 0.0
var _aim_solved_pitch: float = INF
var _travel_yaw: float = 0.0
var _backwards: bool = false
var _was_on_floor: bool = true
var _air_time: float = 0.0
var _thigh_length: float = 0.27
var _shin_length: float = 0.23


func _init(height: float = MODEL_HEIGHT, tuning: PlayerTuning = null) -> void:
	name = "FoxModel"
	_tuning = tuning if tuning != null else PlayerTuning.new()
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
	var hip := skeleton.get_bone_global_rest(skeleton.find_bone(L_THIGH)).origin
	var knee := skeleton.get_bone_global_rest(skeleton.find_bone(L_SHIN)).origin
	var ankle := skeleton.get_bone_global_rest(skeleton.find_bone(L_FOOT)).origin
	_thigh_length = hip.distance_to(knee)
	_shin_length = knee.distance_to(ankle)
	lib.add_animation(&"Idle", _bake(IDLE_LENGTH, _idle_pose))
	lib.add_animation(&"Walk", _bake(WALK_LENGTH, _walk_pose))
	lib.add_animation(&"Jump", _bake(JUMP_LENGTH, _jump_pose))
	lib.add_animation(&"Fall", _bake(FALL_LENGTH, _fall_pose))
	lib.add_animation(&"DoubleJump", _bake(DOUBLE_JUMP_LENGTH, _double_jump_pose, false))
	lib.add_animation(&"Land", _bake(LAND_LENGTH, _land_pose, false))
	lib.add_animation(&"Dodge", _bake(DODGE_LENGTH, _dodge_pose, false))
	lib.add_animation(&"Hurt", _bake(HURT_LENGTH, _hurt_pose, false))
	for i: int in SWINGS.size():
		lib.add_animation(SWINGS[i], _bake_swing(i))
	lib.add_animation(&"SlamRise", _bake(SLAM_RISE_LENGTH, _slam_rise_pose))
	lib.add_animation(&"SlamFall", _bake(SLAM_FALL_LENGTH, _slam_fall_pose))
	lib.add_animation(&"SlamLand", _bake(_tuning.slam_recovery, _slam_land_pose, false))
	lib.add_animation(&"Glide", _bake(GLIDE_LENGTH, _glide_pose))
	lib.add_animation(&"Reel", _bake(REEL_LENGTH, _reel_pose))
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", lib)
	anim.play(&"Idle")
	_playing = &"Idle"
	_build_gun_mount()
	twist_layer = FoxTwistLayer.new()
	twist_layer.hips = skeleton.find_bone(HIPS)
	twist_layer.spine = skeleton.find_bone(SPINE)
	skeleton.add_child(twist_layer)
	aim_layer = FoxAimLayer.new()
	aim_layer.influence = 0.0
	skeleton.add_child(aim_layer)


## A BoneAttachment on the right hand with a child whose -Z runs down the arm (wrist to
## fingertips), so a gun parented there points wherever the arm points.
func _build_gun_mount() -> void:
	var hand := skeleton.find_bone(&"mixamorig_RightHand")
	var attach := BoneAttachment3D.new()
	attach.name = "RightHand"
	attach.bone_name = &"mixamorig_RightHand"
	skeleton.add_child(attach)
	var g := skeleton.get_bone_global_rest(hand)
	# In the T-pose the right arm points along the model's -X.
	var along_arm := Basis.looking_at(Vector3.LEFT, Vector3.UP)
	gun_mount = Node3D.new()
	gun_mount.name = "GunMount"
	gun_mount.transform = Transform3D(g.basis.inverse() * along_arm, g.basis.inverse() * Vector3(-0.07, -0.02, 0.0))
	attach.add_child(gun_mount)


## Called every frame. `speed` is horizontal ground speed, `vertical_speed` the body's
## y velocity. `hold` names a clip the player's state demands for as long as it lasts
## (e.g. &"Dodge"); it beats everything. Otherwise a one-shot from `play_action` runs to
## its end, then ground locomotion or the air poses take over. Landing is detected here
## from the motion; the player calls play_action for events only it knows (double jump, hurt).
func update(speed: float, on_floor: bool, vertical_speed: float = 0.0, hold: StringName = &"") -> void:
	if not on_floor:
		_air_time += _dt()
	elif not _was_on_floor:
		if _air_time > LAND_MIN_AIR_TIME and speed < RUN_EXIT_SPEED:
			play_action(&"Land")
		_air_time = 0.0
	_was_on_floor = on_floor
	_update_aim()
	var travelling := on_floor and speed > IDLE_SPEED and hold == &"" and _action == &""
	var twist := clampf(_travel_yaw, -deg_to_rad(TWIST_MAX), deg_to_rad(TWIST_MAX)) if travelling else 0.0
	twist_layer.yaw = lerpf(twist_layer.yaw, twist, 1.0 - exp(-TWIST_RATE * _dt()))

	if _action != &"":
		var finished := anim.current_animation != _action
		var cancelled := (hold != &"") or (_action == &"Land" and (not on_floor or speed > RUN_ENTER_SPEED)) \
				or (_action == &"DoubleJump" and on_floor)
		if finished or cancelled:
			_action = &""
	var clip := hold
	if clip == &"" and _action != &"":
		return
	if clip == &"":
		clip = _locomotion_clip(speed, on_floor, vertical_speed)
	if clip != _playing:
		anim.play(clip, ACTION_BLEND_TIME if hold != &"" else BLEND_TIME)
		_playing = clip
	match clip:
		&"Running":
			anim.speed_scale = clampf(speed / RUN_CLIP_SPEED, 0.6, 1.6) * (-1.0 if _backwards else 1.0)
		&"Walk":
			anim.speed_scale = clampf(speed / WALK_CLIP_SPEED, 0.5, 1.6) * (-1.0 if _backwards else 1.0)
		_:
			anim.speed_scale = 1.0


## Reports the body's world velocity so the legs can step along it when it differs from
## facing (strafing, firing on the move): the hips turn toward it (FoxTwistLayer), and
## travel mostly backwards plays the walk/run in reverse. Call before update().
func set_travel(world_velocity: Vector3) -> void:
	# Into the model's frame (it faces +Z inside this node, which faces -Z).
	var v := (global_basis.inverse() * world_velocity).rotated(Vector3.UP, PI) if is_inside_tree() \
			else world_velocity.rotated(Vector3.UP, PI)
	if Vector2(v.x, v.z).length() < IDLE_SPEED:
		_travel_yaw = 0.0
		_backwards = false
		return
	var angle := atan2(v.x, v.z)
	_backwards = absf(angle) > deg_to_rad(BACKWARD_ANGLE)
	_travel_yaw = wrapf(angle + PI, -PI, PI) if _backwards else angle


## Plays a one-shot clip (Land, DoubleJump, Hurt, a swing, ...) over locomotion until it
## ends. `duration` > 0 stretches or squeezes the clip to last that long.
func play_action(clip: StringName, duration: float = 0.0) -> void:
	_action = clip
	_playing = clip
	anim.play(clip, ACTION_BLEND_TIME)
	# Restart even if this clip was already playing (a second hit, a re-landing).
	anim.seek(0.0, true)
	anim.speed_scale = anim.current_animation_length / duration if duration > 0.0 else 1.0


## The staff swing for combo step `index` (the last step is the overhead finisher).
func play_swing(index: int, combo_length: int, duration: float) -> void:
	var clip := SWINGS[2] if index == combo_length - 1 else SWINGS[index % 2]
	play_action(clip, duration)


func current_action() -> StringName:
	return _action


## Raise (or lower) the gun arm; `pitch_deg` tilts it up (+) or down (-) to the target.
func aim(on: bool, pitch_deg: float = 0.0) -> void:
	_aim_target = 1.0 if on else 0.0
	_aim_pitch = clampf(pitch_deg, -45.0, 60.0)


func _update_aim() -> void:
	aim_layer.influence = move_toward(aim_layer.influence, _aim_target, AIM_RATE * _dt())
	aim_layer.active = aim_layer.influence > 0.0
	if absf(_aim_pitch - _aim_solved_pitch) < AIM_PITCH_STEP:
		return
	_aim_solved_pitch = _aim_pitch
	# Right arm straight out ahead (dropped to hanging, swung up to horizontal, then the
	# pitch), elbow almost locked, shoulder squared; local rotations for the layer.
	var arm := _pitch(-(90.0 + _aim_pitch)) * _roll(90.0)
	aim_layer.rotations = {
		skeleton.find_bone(R_SHOULDER): _local_rotation(skeleton.find_bone(R_SHOULDER), _roll(-4.0)),
		skeleton.find_bone(R_ARM): _local_rotation(skeleton.find_bone(R_ARM), arm),
		skeleton.find_bone(R_FOREARM): _local_rotation(skeleton.find_bone(R_FOREARM), _yaw(6.0)),
	}


func _locomotion_clip(speed: float, on_floor: bool, vertical_speed: float) -> StringName:
	if not on_floor:
		# Jump eases into Fall around the top of the arc.
		return &"Jump" if vertical_speed > APEX_SPEED else &"Fall"
	if speed <= IDLE_SPEED:
		return &"Idle"
	var running := anim.current_animation == &"Running"
	return &"Running" if speed > (RUN_EXIT_SPEED if running else RUN_ENTER_SPEED) else &"Walk"


func _dt() -> float:
	return get_physics_process_delta_time() if is_inside_tree() else 1.0 / 60.0


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


## Rising: one knee driven up, the other leg trailing, arms pumping up and out; a small
## flutter so the hold doesn't freeze.
func _jump_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var pose := _stance()
	pose[SPINE] = _pitch(-4.0)
	pose[SPINE2] = _pitch(-3.0)
	pose[HEAD] = _pitch(-6.0)
	_set_arms(pose, 35.0 + w * 4.0, -15.0 - w * 4.0, 30.0, 30.0, 45.0, 45.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 55.0 + w * 3.0, 80.0, 20.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, -12.0, 35.0, 25.0)
	return pose


## Dropping: legs reaching down for the floor, arms out for balance, head tipped to
## watch the landing; a slow paddle of the limbs.
func _fall_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var pose := _stance()
	pose[SPINE] = _pitch(6.0)
	pose[HEAD] = _pitch(8.0)
	_set_arms(pose, 10.0 + w * 5.0, 10.0 - w * 5.0, 25.0, 25.0, 25.0 + w * 6.0, 25.0 - w * 6.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 20.0, 35.0 + w * 6.0, 10.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, 8.0, 20.0 - w * 6.0, 10.0)
	return pose


## A tucked forward flip: curl in, rotate once around the hips, open out into the fall.
func _double_jump_pose(p: float) -> Dictionary:
	var tuck := sin(PI * p)
	var spin := smoothstep(0.0, 1.0, p) * 360.0
	var pose := _stance()
	pose[HIPS_OFFSET] = Vector3(0, 0.22 * tuck, 0)
	pose[HIPS] = _pitch(spin)
	pose[SPINE] = _pitch(20.0 * tuck)
	pose[SPINE1] = _pitch(10.0 * tuck)
	pose[HEAD] = _pitch(20.0 * tuck)
	var elbow := 25.0 + 70.0 * tuck
	_set_arms(pose, 10.0 + 50.0 * tuck, 10.0 + 50.0 * tuck, elbow, elbow, 30.0 + 40.0 * tuck, 30.0 + 40.0 * tuck)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 20.0 + 75.0 * tuck, 30.0 + 95.0 * tuck, 20.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, 10.0 + 80.0 * tuck, 20.0 + 100.0 * tuck, 20.0)
	return pose


## Impact squash: the knees soak it up fast (feet planted), arms swing forward for
## balance, then the body rises back to standing.
func _land_pose(p: float) -> Dictionary:
	var d := lerpf(0.6, 1.0, smoothstep(0.0, 0.12, p)) if p < 0.12 else 1.0 - smoothstep(0.12, 1.0, p)
	var pose := _stance()
	_crouch(pose, 40.0 * d, 75.0 * d)
	pose[SPINE] = _pitch(18.0 * d)
	pose[HEAD] = _pitch(-10.0 * d)
	_set_arms(pose, 25.0 * d, 25.0 * d, 14.0 + 20.0 * d, 14.0 + 20.0 * d, ARM_DROP - 30.0 * d, ARM_DROP - 30.0 * d)
	return pose


## A low forward dash: snaps into a lunge, chest down, arms swept back, eyes ahead.
func _dodge_pose(p: float) -> Dictionary:
	var d := smoothstep(0.0, 0.3, p)
	var pose := _stance()
	pose[HIPS_OFFSET] = Vector3(0, -_leg_drop(45.0 * d, 60.0 * d), 0)
	pose[SPINE] = _pitch(22.0 * d)
	pose[SPINE2] = _pitch(8.0 * d)
	pose[HEAD] = _pitch(-15.0 * d)
	_set_arms(pose, -45.0 * d, -45.0 * d, 10.0, 10.0, ARM_DROP - 10.0 * d, ARM_DROP - 10.0 * d)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 45.0 * d, 60.0 * d, (45.0 - 60.0) * d)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, -35.0 * d, 25.0 * d, 30.0 * d)
	return pose


## Flinch: snaps back from the hit (chest and head thrown back, arms flung up), then
## recovers. The knockback itself moves the body; this is the reaction on top.
func _hurt_pose(p: float) -> Dictionary:
	var d := smoothstep(0.0, 0.12, p) if p < 0.12 else 1.0 - smoothstep(0.12, 1.0, p)
	var pose := _stance()
	_crouch(pose, 15.0 * d, 25.0 * d)
	pose[SPINE] = _pitch(-16.0 * d)
	pose[SPINE2] = _pitch(-8.0 * d)
	pose[HEAD] = _pitch(-14.0 * d) * _roll(6.0 * d)
	_set_arms(pose, 25.0 * d, 25.0 * d, 14.0 + 30.0 * d, 14.0 + 30.0 * d, ARM_DROP - 35.0 * d, ARM_DROP - 35.0 * d)
	return pose


## Staff swing for combo step `index`, timed off PlayerTuning: the strike lands over the
## staff's own sweep (0 to melee_active_end, eased fast-out like the staff), holds the
## follow-through, then eases back toward standing for the blend out.
func _bake_swing(index: int) -> Animation:
	var times := _tuning.melee_swing_time
	var length := times[mini(index, times.size() - 1)] if index < 2 else times[times.size() - 1]
	var strike_end := clampf(_tuning.melee_active_end / length, 0.1, 0.9)
	var pose: Callable = [_swing_right_pose, _swing_left_pose, _swing_overhead_pose][index]
	return _bake(length, pose.bind(strike_end), false)


## (strike progress, how much of the pose is still held) for a swing at phase p.
func _swing_curve(p: float, strike_end: float) -> Vector2:
	var s := ease(clampf(p / strike_end, 0.0, 1.0), 0.4)
	var hold := 1.0 - smoothstep(strike_end + 0.15, 1.0, p)
	return Vector2(s, hold)


## Forehand: wound up to the fox's right, the hips lead and the chest whips the staff
## across to the left; the free arm swings back for balance, the head stays on target.
func _swing_right_pose(p: float, strike_end: float) -> Dictionary:
	var c := _swing_curve(p, strike_end)
	return _sweep_pose(lerpf(-35.0, 40.0, c.x), lerpf(-20.0, 120.0, c.x), 25.0, c.y)


## Backhand: the mirror, from across the body back out to the right.
func _swing_left_pose(p: float, strike_end: float) -> Dictionary:
	var c := _swing_curve(p, strike_end)
	return _sweep_pose(lerpf(35.0, -40.0, c.x), lerpf(130.0, 10.0, c.x), lerpf(55.0, 15.0, c.x), c.y)


## A horizontal staff sweep: `twist` turns hips and chest (+ = left), `arm` swings the
## right arm about the vertical (+ = forward/across), `elbow` bends it; all scaled by `k`.
func _sweep_pose(twist: float, arm: float, elbow: float, k: float) -> Dictionary:
	var pose := _stance()
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 18.0 * k, 22.0 * k, -4.0 * k)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, -12.0 * k, 14.0 * k, 26.0 * k)
	pose[HIPS_OFFSET] = Vector3(0, -_leg_drop(18.0 * k, 22.0 * k), 0)
	pose[HIPS] = _yaw(twist * 0.3 * k)
	pose[SPINE] = _yaw(twist * 0.3 * k) * _pitch(6.0 * k)
	pose[SPINE2] = _yaw(twist * 0.4 * k)
	pose[HEAD] = _yaw(-twist * 0.6 * k)
	_set_arms(pose, -20.0 * k * signf(twist), 0.0, 30.0, 14.0, ARM_DROP - 10.0 * k)
	# The staff arm: near shoulder height, swung about the vertical.
	pose[R_ARM] = _yaw(arm * k) * _roll(lerpf(ARM_DROP, 15.0, k))
	pose[R_FOREARM] = _yaw(lerpf(14.0, elbow, k))
	return pose


## Finisher: staff raised two-handed overhead, then chopped down with a step and a
## crunch through the chest.
func _swing_overhead_pose(p: float, strike_end: float) -> Dictionary:
	var c := _swing_curve(p, strike_end)
	var s := c.x
	var k := c.y
	var pose := _stance()
	var front := lerpf(10.0, 35.0, s) * k
	var front_knee := lerpf(10.0, 55.0, s) * k
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, front, front_knee, front - front_knee)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, lerpf(-5.0, -22.0, s) * k, lerpf(5.0, 20.0, s) * k, 25.0 * s * k)
	pose[HIPS_OFFSET] = Vector3(0, -_leg_drop(front, front_knee) + 0.05 * (1.0 - s) * k, 0)
	pose[SPINE] = _pitch(lerpf(-12.0, 28.0, s) * k)
	pose[SPINE2] = _pitch(lerpf(-4.0, 10.0, s) * k)
	pose[HEAD] = _pitch(lerpf(-8.0, 6.0, s) * k)
	var swing := lerpf(160.0, 50.0, s) * k
	var elbow := lerpf(14.0, lerpf(40.0, 10.0, s), k)
	var drop := lerpf(ARM_DROP, 88.0, k)
	_set_arms(pose, swing, swing, elbow, elbow, drop, drop)
	return pose


## Hovering before the slam (or the pounce): knees tucked, staff hoisted overhead.
func _slam_rise_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var pose := _stance()
	pose[SPINE] = _pitch(-10.0)
	pose[HEAD] = _pitch(-6.0)
	_set_arms(pose, 165.0 + w * 4.0, 165.0 + w * 4.0, 30.0, 30.0, 85.0, 85.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 60.0, 95.0, 20.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, 50.0, 100.0, 20.0)
	return pose


## Plunging: chest over the staff, arms driving it down ahead, legs trailing straight.
func _slam_fall_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var pose := _stance()
	pose[SPINE] = _pitch(28.0)
	pose[HEAD] = _pitch(10.0)
	_set_arms(pose, 60.0 + w * 3.0, 60.0 + w * 3.0, 10.0, 10.0, 88.0, 88.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, -6.0, 15.0, 25.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, -10.0, 20.0, 25.0)
	return pose


## Slam impact: a deep crouch with the staff driven into the ground, then rising.
func _slam_land_pose(p: float) -> Dictionary:
	var d := 1.0 - smoothstep(0.35, 1.0, p)
	var pose := _stance()
	_crouch(pose, 50.0 * d, 95.0 * d)
	pose[SPINE] = _pitch(30.0 * d)
	pose[HEAD] = _pitch(-12.0 * d)
	var drop := lerpf(ARM_DROP, 88.0, d)
	_set_arms(pose, 45.0 * d, 45.0 * d, lerpf(14.0, 10.0, d), lerpf(14.0, 10.0, d), drop, drop)
	return pose


## Gliding under the leaf cloak: arms spread wide to hold it open, chest pitched into
## the dive, legs trailing; a slow bob and a little bank so it rides the air.
func _glide_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var bank := sin(TAU * p + 0.8)
	var pose := _stance()
	pose[HIPS] = _pitch(18.0) * _roll(bank * 3.0)
	pose[SPINE] = _pitch(20.0 + w * 2.0)
	pose[SPINE2] = _pitch(4.0)
	pose[HEAD] = _pitch(-30.0)
	_set_arms(pose, -12.0, -12.0, 12.0, 12.0, 8.0 + w * 5.0 - bank * 4.0, 8.0 + w * 5.0 + bank * 4.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, -18.0 + w * 3.0, 30.0, 35.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, -10.0 - w * 3.0, 40.0, 35.0)
	return pose


## Reeled in by the grapple-tail: streamlined toward the ring, arms swept back, knees
## tucked, a quick flutter from the pull.
func _reel_pose(p: float) -> Dictionary:
	var w := sin(TAU * p)
	var pose := _stance()
	pose[SPINE] = _pitch(12.0)
	pose[HEAD] = _pitch(-14.0)
	_set_arms(pose, -40.0 + w * 4.0, -40.0 - w * 4.0, 18.0, 18.0, 72.0, 72.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 35.0 + w * 4.0, 75.0, 25.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, 20.0 - w * 4.0, 60.0, 25.0)
	return pose


## Every animated bone at its plain standing pose (arms down), so key poses only list
## what they change and every clip drives the same tracks.
func _stance() -> Dictionary:
	var pose := {HIPS_OFFSET: Vector3.ZERO}
	for bone: StringName in [HIPS, SPINE, SPINE1, SPINE2, NECK, HEAD, L_SHOULDER, R_SHOULDER]:
		pose[bone] = Quaternion.IDENTITY
	_set_arms(pose, 0.0, 0.0, 14.0, 14.0)
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, 0.0, 0.0, 0.0)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, 0.0, 0.0, 0.0)
	return pose


## Both legs bent the same with feet flat, and the hips lowered so the feet stay on the floor.
func _crouch(pose: Dictionary, forward: float, knee: float) -> void:
	_set_leg(pose, L_THIGH, L_SHIN, L_FOOT, forward, knee, forward - knee)
	_set_leg(pose, R_THIGH, R_SHIN, R_FOOT, forward, knee, forward - knee)
	pose[HIPS_OFFSET] = Vector3(0, -_leg_drop(forward, knee), 0)


## How far the hips sink when a leg swings `forward` and the knee folds `knee` (degrees).
func _leg_drop(forward: float, knee: float) -> float:
	var reach := _thigh_length * cos(deg_to_rad(forward)) + _shin_length * cos(deg_to_rad(forward - knee))
	return _thigh_length + _shin_length - reach


## Drops both arms out of the T-pose (`drop_*` degrees below horizontal). `swing_*`
## swings each arm forward (degrees), `elbow_*` folds the forearm forward.
func _set_arms(pose: Dictionary, swing_l: float, swing_r: float, elbow_l: float, elbow_r: float,
		drop_l: float = ARM_DROP, drop_r: float = ARM_DROP) -> void:
	# Lowered about Z, then swung about X so the swing is always fore/aft.
	pose[L_ARM] = _pitch(-swing_l - 6.0) * _roll(-drop_l)
	pose[R_ARM] = _pitch(-swing_r - 6.0) * _roll(drop_r)
	# Elbows bend in the T-pose frame (forearm toward +Z), which stays "forward" once lowered.
	pose[L_FOREARM] = _yaw(-elbow_l)
	pose[R_FOREARM] = _yaw(elbow_r)


# --- Baking -------------------------------------------------------------------------

## Samples `pose` over the clip (p from 0 to 1) into rotation tracks and a hips position
## track. Looping clips wrap p = 1 back to 0; one-shots get their true end pose.
func _bake(length: float, pose: Callable, loop: bool = true) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for i: int in SAMPLES + 1:
		var p := float(i) / SAMPLES
		var time := length * p
		var frame: Dictionary = pose.call(wrapf(p, 0.0, 1.0) if loop else p)
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
