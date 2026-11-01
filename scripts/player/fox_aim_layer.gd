class_name FoxAimLayer
extends SkeletonModifier3D
## Upper-body layer applied after the AnimationPlayer: sets the gun arm's bones to the
## aim pose, blended over whatever clip is playing by `influence` (0 = clip only, 1 = full
## aim). The legs, hips and chest keep animating underneath. FoxModel fills `rotations`
## (bone index -> local pose rotation) and drives `influence`.

var rotations: Dictionary = {}


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	for bone: int in rotations:
		sk.set_bone_pose_rotation(bone, rotations[bone] as Quaternion)
