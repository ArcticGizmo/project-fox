class_name FoxTwistLayer
extends SkeletonModifier3D
## Turns the hips (and with them the legs) toward the direction of travel while the chest
## keeps facing where the fox faces, so strafing and drifting sideways step the right way
## instead of moonwalking. Applied after the AnimationPlayer, before the aim layer.
## FoxModel drives `yaw` (radians about the model's up axis, + = toward the fox's left).

var yaw: float = 0.0
var hips: int = -1
var spine: int = -1


func _process_modification_with_delta(_delta: float) -> void:
	if is_zero_approx(yaw) or hips < 0:
		return
	var sk := get_skeleton()
	var turn := Quaternion(Vector3.UP, yaw)
	# The hips are the root, so their pose is in skeleton (model) space.
	var hips_old := sk.get_bone_pose_rotation(hips)
	sk.set_bone_pose_rotation(hips, turn * hips_old)
	# Keep the spine's global rotation: undo the turn in the hips' old frame.
	var spine_old := sk.get_bone_pose_rotation(spine)
	sk.set_bone_pose_rotation(spine, hips_old.inverse() * turn.inverse() * hips_old * spine_old)
