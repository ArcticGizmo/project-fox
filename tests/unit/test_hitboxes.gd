extends TestCase


func _box_shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	return cs


func _make_pair() -> Array:
	var health := Health.new()
	health.max_health = 100.0
	add_child(health)
	var hurt := HurtBox.new()
	hurt.collision_layer = Layers.PLAYER_HURTBOX
	hurt.health = health
	hurt.add_child(_box_shape(Vector3.ONE))
	add_child(hurt)
	var hit := HitBox.new()
	hit.collision_mask = Layers.PLAYER_HURTBOX
	hit.damage = 10.0
	hit.add_child(_box_shape(Vector3.ONE))
	hit.position = Vector3(0.3, 0, 0)
	add_child(hit)
	return [hit, hurt, health]


func test_hits_once_per_activation() -> void:
	var pair := _make_pair()
	var hit: HitBox = pair[0]
	var health: Health = pair[2]
	await wait_frames(2)
	hit.active = true
	await wait_frames(10)
	assert_eq(health.current, 90.0, "one hit per activation")
	hit.active = false
	await wait_frames(1)
	hit.active = true
	await wait_frames(3)
	assert_eq(health.current, 80.0, "re-activation hits again")


func test_inactive_deals_nothing() -> void:
	var pair := _make_pair()
	var health: Health = pair[2]
	await wait_frames(10)
	assert_eq(health.current, 100.0, "inactive hitbox is harmless")


func test_repeat_interval_ticks() -> void:
	var pair := _make_pair()
	var hit: HitBox = pair[0]
	var health: Health = pair[2]
	hit.repeat_interval = 0.1
	await wait_frames(2)
	hit.active = true
	await wait_seconds(0.5)
	var hits := roundi((100.0 - health.current) / 10.0)
	assert_true(hits >= 5 and hits <= 6, "expected 5-6 ticks in 0.5s, got %d" % hits)


func test_invulnerable_hurtbox_ignored() -> void:
	var pair := _make_pair()
	var hit: HitBox = pair[0]
	var hurt: HurtBox = pair[1]
	var health: Health = pair[2]
	hurt.invulnerable = true
	await wait_frames(2)
	hit.active = true
	await wait_frames(5)
	assert_eq(health.current, 100.0, "i-frames block damage")


func test_debug_outlines_follow_toggle() -> void:
	var pair := _make_pair()
	var hit: HitBox = pair[0]
	var hurt: HurtBox = pair[1]
	await wait_frames(1)
	var hit_outline := hit.get_node("DebugOutline") as DebugOutline
	var hurt_outline := hurt.get_node("DebugOutline") as DebugOutline
	assert_true(hit_outline != null and hurt_outline != null, "outlines attached")
	assert_eq(hit_outline.line_count(), 12, "box outline has 12 edges")
	assert_false(hit_outline.visible, "hidden by default")
	DebugSettings.show_boxes = true
	assert_true(hit_outline.visible and hurt_outline.visible, "shown when toggled on")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hurt_outline.material_override.get("albedo_color"), hurt.get_debug_color(), "hurtbox colour")
	DebugSettings.show_boxes = false
	assert_false(hit_outline.visible, "hidden when toggled off")


func test_outline_supports_all_shapes() -> void:
	var shapes: Array[Shape3D] = [BoxShape3D.new(), SphereShape3D.new(), CapsuleShape3D.new(), CylinderShape3D.new()]
	var cone := ConvexPolygonShape3D.new()
	cone.points = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, -2), Vector3(-1, 0, -2), Vector3(0, 1, -2)])
	shapes.append(cone)
	for s: Shape3D in shapes:
		var lines := PackedVector3Array()
		DebugOutline.append_shape_lines(lines, s)
		assert_true(lines.size() > 0 and lines.size() % 2 == 0, "%s produced %d points" % [s.get_class(), lines.size()])
