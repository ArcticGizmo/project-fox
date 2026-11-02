class_name HeldModel
extends RefCounted
## Builds a hand-held weapon model for FoxModel.gun_mount (whose -Z runs down the arm).
## Meshy gun exports are centred on their bounds with the barrel along -X; this turns the
## barrel to -Z, scales the model to `length` metres along it, and puts `grip` (a point in
## the model's own coordinates) on the mount's origin.
## A "Tip" child marks the muzzle: the barrel's far (-X) end on the model's centre line.

const TIP := &"Tip"


static func build(scene: PackedScene, grip: Vector3, length: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "HeldModel"
	var inner := scene.instantiate() as Node3D
	var bounds := AABB()
	var first := true
	for mi: MeshInstance3D in inner.find_children("*", "MeshInstance3D", true, false):
		var box := _to(inner, mi) * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var k := length / maxf(bounds.size.x, 0.001)
	# Barrel -X -> -Z (a quarter turn about Y), then a quarter roll about the barrel: with
	# the arm raised to aim (FoxModel aim pose) the mount's -X is up, its +Y the fox's right.
	var basis := (Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.UP, -PI * 0.5)).scaled(Vector3.ONE * k)
	inner.transform = Transform3D(basis, -(basis * grip))
	pivot.add_child(inner)
	var tip := Node3D.new()
	tip.name = TIP
	tip.position = basis * (Vector3(bounds.position.x, 0.0, 0.0) - grip)
	pivot.add_child(tip)
	return pivot


static func _to(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
