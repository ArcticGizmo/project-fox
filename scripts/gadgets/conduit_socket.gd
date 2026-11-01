class_name ConduitSocket
extends Area3D
## The part of a lightning barrier or conduit terminal the staff can strike
## (Copper Conduit Gauntlet). Sits on Layers.CONDUCTOR, which only the staff
## swing HitBox masks, so enemies, hazards and weapons never touch it. The
## ConduitGauntlet on the player finds sockets inside a live swing and calls
## `receiver.conduit_struck(gauntlet, unlocked)` once per swing.

const DEBUG_COLOR := Color(0.95, 0.6, 0.25, 0.8)

## Node with `conduit_struck(gauntlet: ConduitGauntlet, unlocked: bool) -> void`.
var receiver: Node
var _outline: DebugOutline


func _init() -> void:
	monitoring = false
	monitorable = true
	collision_layer = Layers.CONDUCTOR
	collision_mask = 0


func _ready() -> void:
	_outline = DebugOutline.attach(self)


## A box socket under `parent` that forwards staff strikes to `to`.
static func make(parent: Node, socket_name: String, size: Vector3, offset: Vector3, to: Node) -> ConduitSocket:
	var s := ConduitSocket.new()
	s.name = socket_name
	s.receiver = to
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	s.add_child(cs)
	parent.add_child(s)
	return s


func strike(gauntlet: ConduitGauntlet, unlocked: bool) -> void:
	if receiver != null and is_instance_valid(receiver) and receiver.has_method(&"conduit_struck"):
		receiver.call(&"conduit_struck", gauntlet, unlocked)


func get_debug_color() -> Color:
	return DEBUG_COLOR
