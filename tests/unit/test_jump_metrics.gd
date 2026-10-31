extends TestCase
## Real jumps with the Player and scripted input on little test courses, many
## lanes side by side in one run: the highest ledge a standing jump (pressed
## against the wall) gets onto, and the widest gap a full-speed running jump
## clears edge to edge (jump pressed as the fox's centre passes the edge). The
## double jump is tried at the apex and at points further down the fall.
## Results are printed; LevelMetrics' design limits must be reachable and its
## gadget-gate minimums must not be (so a gate really needs its gadget).

const LANE_SPACING := 6.0
const TRIAL_FRAMES := 150

## Double-jump timings for gaps: metres fallen below the first apex.
const DJ_DROPS: Array[float] = [0.0, 1.9]


class Trial:
	var player: Player
	var pad: ScriptedInputProvider
	var is_gap: bool
	var value: float
	var double: bool
	var dj_drop: float
	var jumped: bool = false
	var double_done: bool = false
	var apex: float = -INF
	var start_frame: int = 10
	var landed: bool = false


var trials: Array[Trial] = []
var _lane: int = 0


func _block(center: Vector3, size: Vector3) -> void:
	var b := Block.new()
	b.size = size
	b.position = center
	add_child(b)


func _player(at: Vector3) -> Array:
	var pad := ScriptedInputProvider.new()
	var p := Player.new()
	p.input_provider = pad
	p.position = at
	add_child(p)
	return [p, pad]


func _add_ledge(height: float, double: bool) -> void:
	var x := _lane * LANE_SPACING
	_lane += 1
	_block(Vector3(x, -0.5, 3.0), Vector3(3, 1, 8))  # ground, z -1..7
	_block(Vector3(x, height * 0.5 - 0.5, -3.0), Vector3(3, height + 1.0, 4))  # wall face at z=-1
	var t := Trial.new()
	var pp := _player(Vector3(x, 0.05, 0.0))
	t.player = pp[0]
	t.pad = pp[1]
	t.is_gap = false
	t.value = height
	t.double = double
	t.start_frame = 30  # walk into the wall first
	trials.append(t)


func _add_gap(gap: float, double: bool, dj_drop: float) -> void:
	var x := _lane * LANE_SPACING
	_lane += 1
	_block(Vector3(x, -0.5, 15.0), Vector3(3, 1, 30))  # takeoff, edge at z=0
	_block(Vector3(x, -0.5, -gap - 10.0), Vector3(3, 1, 20))  # landing, edge at z=-gap
	var t := Trial.new()
	var pp := _player(Vector3(x, 0.05, 8.0))
	t.player = pp[0]
	t.pad = pp[1]
	t.is_gap = true
	t.value = gap
	t.double = double
	t.dj_drop = dj_drop
	trials.append(t)


func _step(t: Trial, frame: int) -> void:
	var p := t.player
	if frame < t.start_frame:
		t.pad.next.move = Vector2(0, -1) if t.is_gap or frame > 5 else Vector2.ZERO
		return
	t.pad.next.move = Vector2(0, -1)
	if not t.jumped:
		if not t.is_gap or p.global_position.z <= 0.0:
			t.jumped = true
			t.pad.next.jump_pressed = true
			t.pad.next.jump_held = true
		return
	t.apex = maxf(t.apex, p.global_position.y)
	if _succeeded(t):
		t.landed = true
	if t.double and not t.double_done and p.velocity.y <= 0.0 and p.global_position.y <= t.apex - t.dj_drop:
		t.double_done = true
		t.pad.next.jump_pressed = true


func _succeeded(t: Trial) -> bool:
	var p := t.player
	if t.is_gap:
		return p.is_on_floor() and p.global_position.y > -0.2 and p.global_position.z < -t.value
	return p.is_on_floor() and p.global_position.y > t.value - 0.2


func _run_all() -> void:
	for frame: int in TRIAL_FRAMES:
		for t: Trial in trials:
			_step(t, frame)
		await get_tree().physics_frame


## Best value that succeeded for the matching trials (0 if none did).
func _best(is_gap: bool, double: bool, dj_drop: float = -1.0) -> float:
	var best := 0.0
	for t: Trial in trials:
		if t.is_gap == is_gap and t.double == double and (dj_drop < 0.0 or is_equal_approx(t.dj_drop, dj_drop)):
			if t.landed:
				best = maxf(best, t.value)
	return best


func _range(from: float, to: float, step: float) -> Array[float]:
	var out: Array[float] = []
	var v := from
	while v <= to + 0.001:
		out.append(snappedf(v, 0.01))
		v += step
	return out


func test_measured_jump_limits_fit_level_metrics() -> void:
	for h: float in _range(1.8, 2.8, 0.1):
		_add_ledge(h, false)
	for h: float in _range(3.2, 4.4, 0.1):
		_add_ledge(h, true)
	for g: float in _range(5.0, 7.5, 0.25):
		_add_gap(g, false, 0.0)
	for drop: float in DJ_DROPS:
		for g: float in _range(8.5, 12.0, 0.25):
			_add_gap(g, true, drop)
	await wait_frames(2)
	await _run_all()

	var single_ledge := _best(false, false)
	var double_ledge := _best(false, true)
	var single_gap := _best(true, false)
	var apex_gap := _best(true, true, 0.0)
	var double_gap := _best(true, true)
	print("    jump metrics: single ledge %.2f m, double ledge %.2f m, single gap %.2f m, " % [single_ledge, double_ledge, single_gap]
		+ "double gap %.2f m at apex / %.2f m best (drops %s: %s)" % [apex_gap, double_gap, str(DJ_DROPS),
		str(DJ_DROPS.map(func(d: float) -> float: return _best(true, true, d)))])

	assert_true(single_ledge >= LevelMetrics.STEP_MAX + LevelMetrics.MARGIN, "single jump ledge %.2f covers steps" % single_ledge)
	assert_true(double_ledge >= LevelMetrics.LEDGE_MAX + LevelMetrics.MARGIN, "double jump ledge %.2f covers path ledges" % double_ledge)
	assert_true(single_gap >= LevelMetrics.SINGLE_GAP_MAX + LevelMetrics.MARGIN, "single jump gap %.2f" % single_gap)
	assert_true(apex_gap >= LevelMetrics.GAP_MAX + LevelMetrics.MARGIN, "apex double jump gap %.2f covers path gaps" % apex_gap)
	assert_true(double_ledge <= LevelMetrics.GATE_LEDGE_MIN - LevelMetrics.MARGIN, "gated ledges (%.1f m) out of reach (%.2f)" % [LevelMetrics.GATE_LEDGE_MIN, double_ledge])
	assert_true(double_gap <= LevelMetrics.GATE_GAP_MIN - LevelMetrics.MARGIN, "gated gaps (%.1f m) out of reach (%.2f)" % [LevelMetrics.GATE_GAP_MIN, double_gap])
	# Sanity: each search range found its limit inside it (not at an end).
	assert_true(single_ledge > 1.8 and single_ledge < 2.8, "single ledge limit inside the search range")
	assert_true(double_ledge > 3.2 and double_ledge < 4.4, "double ledge limit inside the search range")
	assert_true(single_gap > 5.0 and single_gap < 7.5, "single gap limit inside the search range")
	assert_true(apex_gap > 8.5 and double_gap < 12.0, "double gap limit inside the search range")
