@tool
extends EditorScenePostImport
## Import script for static Meshy exports, which come centred on their bounds: moves
## the root's children so the bottom centre sits on the origin (the model convention
## for everything but held items, see docs/art-pipeline.md). Set it as the GLB's
## `import_script/path`.


func _post_import(scene: Node) -> Object:
	var root := scene as Node3D
	if root == null:
		return scene
	var bounds := AABB()
	var first := true
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var box := _to_root(root, m) * m.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return scene
	var shift := -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for c: Node in root.get_children():
		if c is Node3D:
			(c as Node3D).position += shift
	return scene


func _to_root(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
