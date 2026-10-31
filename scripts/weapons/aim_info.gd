class_name AimInfo
extends RefCounted
## Where a weapon should fire this frame. Built by the player (or a test).

var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
## Aim-assist target, may be null.
var target: Node3D = null
var point: Vector3 = Vector3.ZERO
## Where the reticle ray hit, ignoring aim assist.
var raw_point: Vector3 = Vector3.ZERO


static func create(p_origin: Vector3, p_direction: Vector3, p_target: Node3D = null) -> AimInfo:
	var aim := AimInfo.new()
	aim.origin = p_origin
	aim.direction = p_direction.normalized()
	aim.target = p_target
	aim.point = p_origin + aim.direction * 30.0
	aim.raw_point = aim.point
	return aim
