extends TestCase


func _make(max_hp: float) -> Health:
	var h := Health.new()
	h.max_health = max_hp
	add_child(h)
	return h


func test_damage_and_clamp() -> void:
	var h := _make(50.0)
	assert_eq(h.current, 50.0, "starts full")
	assert_eq(h.apply_damage(DamageInfo.create(20.0, Vector3.ZERO)), 20.0, "dealt")
	assert_eq(h.current, 30.0, "after hit")
	assert_eq(h.apply_damage(DamageInfo.create(100.0, Vector3.ZERO)), 30.0, "overkill clamps")
	assert_true(h.is_dead, "dead at zero")


func test_died_emits_once_and_dead_ignores_damage() -> void:
	var h := _make(10.0)
	var deaths: Array[int] = [0]
	h.died.connect(func(_i: DamageInfo) -> void: deaths[0] += 1)
	h.apply_damage(DamageInfo.create(10.0, Vector3.ZERO))
	h.apply_damage(DamageInfo.create(10.0, Vector3.ZERO))
	assert_eq(deaths[0], 1, "died count")


func test_heal_caps_at_max() -> void:
	var h := _make(100.0)
	h.apply_damage(DamageInfo.create(30.0, Vector3.ZERO))
	h.heal(50.0)
	assert_eq(h.current, 100.0, "healed to max")
