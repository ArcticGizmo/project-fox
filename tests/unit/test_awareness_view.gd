extends TestCase
## Awareness readability: "?" / "!" markers, the AI debug view (F4) and idle
## flavour fidgets while resting.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"
const GULL := "res://scenes/enemies/bombardier_gull.tscn"
const FALCON := "res://scenes/enemies/brass_falcon.tscn"


func before_each() -> void:
	DebugSettings.show_ai = false
	add_floor()


func _placed(path: String, at: Vector3, yaw: float = 0.0) -> Enemy:
	return spawn_enemy(path, at, yaw, 1, false)


func _views() -> int:
	var n := 0
	for e: Node in get_tree().get_nodes_in_group(&"enemies"):
		if is_ancestor_of(e) and (e as Enemy).ai_view != null and is_instance_valid((e as Enemy).ai_view):
			n += 1
	return n


func test_ai_debug_toggle_creates_and_frees_views() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	var rat := _placed(RAT, Vector3(4, 0, 0))
	await wait_frames(1)
	assert_true(bull.ai_view == null and rat.ai_view == null, "no overlay while off")
	DebugSettings.show_ai = true
	await wait_frames(2)
	assert_eq(_views(), 2, "one view per enemy")
	assert_true(bull.ai_view.has_lines(), "bull overlay drew its rings and cone")
	assert_true(bull.ai_view.label.text.contains("rest"), "label shows the state: %s" % bull.ai_view.label.text)
	var late := _placed(BULL, Vector3(-4, 0, 0))
	await wait_frames(1)
	assert_true(late.ai_view != null, "enemies spawned while on get a view")
	var view := bull.ai_view
	DebugSettings.show_ai = false
	await wait_frames(1)
	assert_false(is_instance_valid(view), "views are freed when toggled off")
	assert_eq(_views(), 0, "none left")


func test_debug_view_label_tracks_suspicion_and_noise() -> void:
	DebugSettings.show_ai = true
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, -10))
	var sus := await wait_until(func() -> bool: return bull.suspicion > 0.3, bull.notice_time * 2.0)
	assert_true(sus, "suspicion rising")
	assert_true(bull.ai_view.label.text.contains("fill"), "label shows filling: %s" % bull.ai_view.label.text)
	assert_true(bull.los_checked and not bull.los_blocked, "clear LOS drawn green")
	NoiseEvent.emit(Vector3(3, 0, 3), 5.0, self)
	await wait_frames(1)
	var owners := 0
	for e: Node in get_children():
		if e is Enemy and (e as Enemy).ai_view.draws_noise():
			owners += 1
	assert_eq(owners, 1, "exactly one view draws noise pulses")
	DebugSettings.show_ai = false


func test_markers_follow_awareness_states() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	await wait_frames(2)
	assert_eq(bull.marker.mode(), &"", "nothing at rest")
	assert_false(bull.marker.visible, "hidden at rest")
	add_dummy_target(Vector3(0, 0, -12))
	var sus := await wait_until(func() -> bool: return bull.state == Enemy.SUSPICIOUS, 1.0)
	assert_true(sus, "suspicious")
	await wait_frames(1)
	assert_eq(bull.marker.mode(), &"?", "? while suspicious")
	assert_true(bull.marker.visible and bull.marker.question.visible, "? shown")
	var alert := await wait_until(func() -> bool: return bull.state == Enemy.ALERT, bull.notice_time * 3.0)
	assert_true(alert, "alert")
	await wait_frames(1)
	assert_eq(bull.marker.mode(), &"!", "! during alert")
	assert_true(bull.marker.exclaim.visible and not bull.marker.question.visible, "! shown, ? hidden")
	var aware := await wait_until(func() -> bool: return bull.aware, bull.alert_time + 0.3)
	assert_true(aware, "aware")
	await wait_frames(1)
	assert_false(bull.marker.visible, "hidden once aware")


func test_idle_flavour_never_arms_hitboxes_or_glows() -> void:
	var enemies: Array[Enemy] = []
	var x := -8.0
	for path: String in [BULL, RAT, TOAD, GULL, FALCON]:
		enemies.append(_placed(path, Vector3(x, 0, 0)))
		x += 4.0
	for e: Enemy in enemies:
		e.rest_time_min = 100.0
		e.rest_time_max = 100.0
		e.wander_radius = 0.0
		e.enter_state(Enemy.REST)
	var moved: Dictionary = {}
	for _i: int in 240:
		await wait_frames(1)
		for e: Enemy in enemies:
			assert_eq(e.state, Enemy.REST, "%s still resting" % e.display_name)
			assert_eq(e.telegraph, 0.0, "%s never glows" % e.display_name)
			for c: Node in e.get_children():
				if c is HitBox:
					assert_false((c as HitBox).active, "%s hitbox %s idle" % [e.display_name, c.name])
			if e.visual_pitch != 0.0 or e.visual_yaw != 0.0 or e.visual_offset != Vector3.ZERO or e.visual_scale != Vector3.ONE:
				moved[e.display_name] = true
			assert_true(e.visual_pitch <= 0.0, "%s never pitches up (falcon dive wind-up)" % e.display_name)
	assert_eq(moved.size(), enemies.size(), "every enemy fidgets: %s" % [moved.keys()])


func test_pause_menu_toggles_ai_view() -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	menu.call(&"_on_toggle_ai")
	assert_true(DebugSettings.show_ai, "on from the menu")
	menu.call(&"_on_toggle_ai")
	assert_false(DebugSettings.show_ai, "and off")
	menu.queue_free()
