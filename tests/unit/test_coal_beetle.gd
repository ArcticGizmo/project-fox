extends TestCase
## Coal Beetle: crawls leaving burning coals, stokes then belches coals that leave embers,
## scorches up close, shrugs off fire and is quenched by frost.

const BEETLE := "res://scenes/enemies/coal_beetle.tscn"
const TIMING_TOLERANCE := 0.04


func _embers() -> Array[CoalEmber]:
	var out: Array[CoalEmber] = []
	for n: Node in find_children("*", "CoalEmber", true, false):
		out.append(n as CoalEmber)
	return out


func test_wears_its_model_and_telegraphs_light_it() -> void:
	add_floor()
	var beetle := spawn_enemy(BEETLE, Vector3.ZERO) as CoalBeetle
	await wait_frames(1)
	assert_true(beetle.model != null, "has a model")
	assert_true(beetle.visual.find_children("*", "MeshInstance3D", true, false).size() >= 1, "model meshes under the visual")
	assert_false(beetle._model_materials.is_empty(), "model materials claimed")
	var bounds := AABB()
	var first := true
	for mi: MeshInstance3D in beetle.model.find_children("*", "MeshInstance3D", true, false):
		var box := beetle.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	assert_near(bounds.position.y, 0.0, 0.05, "model stands on the ground")
	assert_true(bounds.size.y <= beetle.body_size.y + 0.01, "model fits the body height")
	beetle.telegraph = 1.0
	beetle.set_physics_process(false)
	beetle._update_visuals(1.0 / 60.0)
	assert_true(beetle._model_materials[0].emission.r > 0.5, "telegraph glows on the model")


func test_crawl_drops_embers_that_burn_without_knockback() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var beetle := spawn_enemy(BEETLE, Vector3(0, 0, -16), PI) as CoalBeetle
	var dropped := await wait_until(func() -> bool: return beetle.embers_dropped >= 2, beetle.ember_drop_interval * 3.0)
	assert_true(dropped, "dropped embers while crawling; log=%s" % [beetle.state_log])
	var e := _embers()[0]
	assert_true(e.global_position.z < beetle.global_position.z, "embers fall behind it")
	beetle.queue_free()
	# Stand in a fresh patch: DoT ticks, no shove.
	var patch := CoalEmber.spawn(self, dummy.global_position, beetle.ember_radius, beetle.ember_damage, 3.0)
	await wait_seconds(patch.tick * 4.0 + 0.05)
	assert_true(dummy.hits.size() >= 4 and dummy.hits.size() <= 5, "ticks every %.2fs (%d hits)" % [patch.tick, dummy.hits.size()])
	for h: DamageInfo in dummy.hits:
		assert_true(h.is_dot, "ember damage is DoT")
		assert_near(h.amount, patch.damage, 0.01, "tick damage")
	await wait_seconds(3.0)
	assert_false(is_instance_valid(patch), "embers go out")


func test_stoke_then_belch_coals_that_leave_embers() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var beetle := spawn_enemy(BEETLE, Vector3(0, 0, -9), PI) as CoalBeetle
	var belched := await wait_until(func() -> bool: return beetle.coals_belched > 0, beetle.belch_cooldown + beetle.stoke_time + 1.0)
	assert_true(belched, "belched; log=%s" % [beetle.state_log])
	assert_eq(beetle.coals_belched, beetle.belch_count, "a full belch")
	assert_near(state_time_in_log(beetle.state_log, "recover") - state_time_in_log(beetle.state_log, "stoke"),
			beetle.stoke_time, TIMING_TOLERANCE, "stoke telegraph length")
	var before := _embers().size()
	await wait_seconds(beetle.lob_flight_time + 0.1)
	assert_true(dummy.hits.size() >= 1, "the centre coal lands on a stationary target")
	assert_near(dummy.hits[0].amount, beetle.lob_damage, 0.01, "coal damage")
	var landed := 0
	for e: CoalEmber in _embers():
		if Vector2(e.global_position.x, e.global_position.z).length() <= beetle.belch_spread + 0.5:
			landed += 1
	assert_true(landed >= beetle.belch_count, "every coal left embers round the target (%d, %d before)" % [landed, before])


func test_scorches_up_close() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var beetle := spawn_enemy(BEETLE, Vector3(0, 0, -2.4), PI) as CoalBeetle
	var done := await wait_until(func() -> bool: return beetle.state == &"recover", 2.0)
	assert_true(done, "scorched; log=%s" % [beetle.state_log])
	assert_true(state_time_in_log(beetle.state_log, "scorch_windup") >= 0.0, "scorch, not a belch")
	assert_near(state_time_in_log(beetle.state_log, "recover") - state_time_in_log(beetle.state_log, "scorch_windup"),
			beetle.scorch_windup_time, TIMING_TOLERANCE, "scorch telegraph length")
	assert_eq(dummy.hits.size(), 1, "one burst")
	assert_near(dummy.damage_taken(), beetle.scorch_damage, 0.01, "scorch damage")
	assert_true(dummy.hits[0].knockback > 0.0, "it shoves")


func test_frost_quenches_a_stoke_and_exposes() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var beetle := spawn_enemy(BEETLE, Vector3(0, 0, -9), PI) as CoalBeetle
	var stoking := await wait_until(func() -> bool: return beetle.state == &"stoke", beetle.belch_cooldown + 1.0)
	assert_true(stoking, "stoking; log=%s" % [beetle.state_log])
	beetle.add_chill(beetle.quench_chill + 0.05, 2.0)
	await wait_frames(2)
	assert_eq(beetle.state, &"quenched", "doused; log=%s" % [beetle.state_log])
	assert_true(beetle.is_exposed(), "exposed")
	await wait_seconds(beetle.stoke_time)
	assert_eq(beetle.coals_belched, 0, "no belch")
	var dropped := beetle.embers_dropped
	beetle.add_chill(1.0 - beetle.chill - 0.01, 2.0)
	await wait_seconds(beetle.ember_drop_interval * 2.0)
	assert_eq(beetle.embers_dropped, dropped, "no embers while chilled")


func test_fire_does_not_burn_it() -> void:
	add_floor()
	var beetle := spawn_enemy(BEETLE, Vector3.ZERO) as CoalBeetle
	beetle.set_physics_process(false)
	beetle.apply_burn(20.0, 2.0, null)
	assert_eq(beetle._burn_left, 0.0, "no burn")
