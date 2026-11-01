extends TestCase
## Dressing props, the dressing-vs-critical-path rule, and model conventions for every
## model under assets/ (docs/art-pipeline.md, "Model conventions").

const MODEL_DIRS := ["characters", "props", "weapons", "enemies", "gameplay"]
const LEVELS := ["res://scenes/main.tscn", "res://scenes/levels/slice_01.tscn"]
## Headroom above a critical-path top that colliding dressing must leave clear.
const WALK_CLEARANCE := 2.0


func test_placeholder_prop_with_box_collision() -> void:
	var p := Prop.new()
	p.placeholder = Prop.Placeholder.BARREL
	p.collision = Prop.Collision.BOX
	add_child(p)
	var b := p.local_bounds()
	assert_near(b.position.y, 0.0, 0.01, "sits on its origin")
	var body := p.get_node(^"Collision") as StaticBody3D
	assert_true(body != null, "has a body")
	assert_eq(body.collision_layer, Layers.WORLD, "world layer")
	var shape := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_true(shape.size.is_equal_approx(b.size), "box fits the model")


func test_prop_without_collision_has_no_body() -> void:
	var p := Prop.new()
	p.placeholder = Prop.Placeholder.LANTERN
	add_child(p)
	assert_true(p.get_node_or_null(^"Collision") == null, "no body")
	assert_true(p.is_in_group(&"dressing"), "dressing group")


func test_fit_height_scales_a_model() -> void:
	var p := Prop.new()
	p.model = load("res://assets/characters/ember/Ember_the_Foxling.glb") as PackedScene
	p.fit_height = 0.85
	add_child(p)
	assert_near(p.local_bounds().size.y, 0.85, 0.01, "scaled to the requested height")


func test_colliding_dressing_stays_out_of_the_critical_path() -> void:
	for path: String in LEVELS:
		var level := (load(path) as PackedScene).instantiate()
		add_child(level)
		var walk: Array[AABB] = []
		for b: Block in level.find_children("*", "Block", true, false):
			if b.is_in_group(&"critical_path"):
				var at := b.global_position
				walk.append(AABB(Vector3(at.x - b.size.x * 0.5, at.y + b.size.y * 0.5, at.z - b.size.z * 0.5),
						Vector3(b.size.x, WALK_CLEARANCE, b.size.z)))
		for p: Prop in level.find_children("*", "Prop", true, false):
			if p.collision == Prop.Collision.NONE:
				continue
			for w: AABB in walk:
				assert_false(p.world_bounds().intersects(w), "%s: %s blocks the critical path" % [path.get_file(), p.name])
		level.free()


func test_models_follow_the_conventions() -> void:
	var count := 0
	for category: String in MODEL_DIRS:
		var dir := "res://assets".path_join(category)
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for model_dir: String in DirAccess.get_directories_at(dir):
			for file: String in DirAccess.get_files_at(dir.path_join(model_dir)):
				if not file.ends_with(".glb"):
					continue
				count += 1
				var label := "%s/%s/%s" % [category, model_dir, file]
				var scene := load(dir.path_join(model_dir).path_join(file)) as PackedScene
				assert_true(scene != null, "%s loads" % label)
				if scene == null:
					continue
				var root := scene.instantiate() as Node3D
				add_child(root)
				var bounds := _bounds(root)
				root.free()
				var reach := maxf(bounds.size.x, bounds.size.z)
				if category == "weapons":
					# Held items: origin at the grip, so it must lie within the model.
					assert_true(bounds.grow(0.02).has_point(Vector3.ZERO), "%s: origin (the grip) inside the model" % label)
				else:
					assert_near(bounds.position.y, 0.0, maxf(0.05, bounds.size.y * 0.03), "%s: origin at its base" % label)
				assert_true(absf(bounds.get_center().x) <= reach * 0.25 + 0.05 and absf(bounds.get_center().z) <= reach * 0.25 + 0.05,
						"%s: centred on its origin (centre %s)" % [label, bounds.get_center()])
				assert_true(bounds.size.y > 0.03 and bounds.size.y < 30.0, "%s: plausible size in metres (%.2f m)" % [label, bounds.size.y])
	assert_true(count >= 1, "found models (Ember at least)")


func _bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var box := root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
