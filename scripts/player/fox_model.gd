class_name FoxModel
extends Node3D
## The fox's rigged mesh (Ember_the_Foxling.glb, Mixamo skeleton). Pure presentation:
## the player calls `update()` each frame with its ground speed and `flash` for hurt.
##
## The GLB ships one in-place "Running" clip and a T-pose, so an "Idle" clip (arms down,
## a slow breath) is built here from the skeleton's rest pose.

const SCENE: PackedScene = preload("res://imported_models/Ember_the_Foxling/Ember_the_Foxling.glb")
## Authored height of the GLB (ear tips), scaled up to the player's capsule.
const MODEL_HEIGHT := 1.7
## Ground speed the Running clip's cadence was authored for; faster or slower scales it.
const RUN_CLIP_SPEED := 7.0
## Below this ground speed the fox idles.
const RUN_MIN_SPEED := 0.6
const BLEND_TIME := 0.15
const IDLE_LENGTH := 2.4

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
	lib.add_animation(&"Idle", _build_idle())
	anim.remove_animation_library(&"")
	anim.add_animation_library(&"", lib)
	anim.play(&"Idle")


## `speed` is horizontal ground speed; airborne poses fall back to idle for now.
func update(speed: float, on_floor: bool) -> void:
	if on_floor and speed > RUN_MIN_SPEED:
		if anim.current_animation != &"Running":
			anim.play(&"Running", BLEND_TIME)
		anim.speed_scale = clampf(speed / RUN_CLIP_SPEED, 0.5, 1.6)
	else:
		if anim.current_animation != &"Idle":
			anim.play(&"Idle", BLEND_TIME)
		anim.speed_scale = 1.0


func flash(amount: float) -> void:
	material.emission = Color(1.0, 0.1, 0.1) * amount


func _build_idle() -> Animation:
	var a := Animation.new()
	a.length = IDLE_LENGTH
	a.loop_mode = Animation.LOOP_LINEAR
	# Arms hang down and a little out from the T-pose.
	_add_arm_track(a, &"mixamorig_LeftArm", &"mixamorig_LeftForeArm", Vector3(0.35, -1.0, 0.1), 0.06)
	_add_arm_track(a, &"mixamorig_RightArm", &"mixamorig_RightForeArm", Vector3(-0.35, -1.0, 0.1), 0.06)
	# Breathing: the chest tips back and forth a few degrees.
	_add_sway_track(a, &"mixamorig_Spine1", Vector3.RIGHT, deg_to_rad(2.0))
	_add_sway_track(a, &"mixamorig_Head", Vector3.RIGHT, deg_to_rad(-1.5))
	return a


## Rotates `bone` so the direction to `child` points along `target` (skeleton space),
## swinging by `sway` radians over the clip.
func _add_arm_track(a: Animation, bone: StringName, child: StringName, target: Vector3, sway: float) -> void:
	var b := skeleton.find_bone(bone)
	var c := skeleton.find_bone(child)
	var parent_rest := skeleton.get_bone_global_rest(skeleton.get_bone_parent(b))
	var rest := skeleton.get_bone_global_rest(b)
	var dir := (skeleton.get_bone_global_rest(c).origin - rest.origin).normalized()
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("SmartRigArmature/Skeleton3D:%s" % bone))
	for i: int in 3:
		var s := sway * (1.0 if i == 1 else 0.0)
		var aim := Quaternion(dir, target.normalized()) * Quaternion(Vector3.FORWARD, s * signf(target.x))
		var local := parent_rest.basis.inverse() * (Basis(aim) * rest.basis)
		a.rotation_track_insert_key(t, IDLE_LENGTH * i * 0.5, local.get_rotation_quaternion())


func _add_sway_track(a: Animation, bone: StringName, axis: Vector3, angle: float) -> void:
	var b := skeleton.find_bone(bone)
	var rest := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("SmartRigArmature/Skeleton3D:%s" % bone))
	for i: int in 3:
		var r := rest * Quaternion(axis, angle * (1.0 if i == 1 else 0.0))
		a.rotation_track_insert_key(t, IDLE_LENGTH * i * 0.5, r)
