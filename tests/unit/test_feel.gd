extends TestCase
## Rumble (GameFeel) and placeholder sound (Sfx / SfxBank): the bank builds,
## every caller's id exists, and gameplay events reach both.

const PANGOLIN := "res://scenes/enemies/brass_pangolin.tscn"
const BULL := "res://scenes/enemies/brass_bull.tscn"

var player: Player
var pad: ScriptedInputProvider


func _add_player() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)
	Sfx.reset()


func test_every_recipe_builds_a_clean_stream() -> void:
	for id: StringName in SfxBank.recipes():
		var wav := SfxBank.build(id)
		var r: Dictionary = SfxBank.recipes()[id]
		assert_eq(wav.data.size(), int(float(r[&"dur"]) * SfxBank.MIX_RATE) * 2, "%s length" % id)
		var peak := 0
		for i: int in range(0, wav.data.size(), 2):
			peak = maxi(peak, absi(wav.data.decode_s16(i)))
		assert_true(peak > 3000, "%s is audible (peak %d)" % [id, peak])
		assert_true(peak <= int(SfxBank.PEAK * 32767.0) + 1, "%s normalised (peak %d)" % [id, peak])


func test_ids_used_in_code_and_data_exist() -> void:
	for f: String in DirAccess.get_files_at("res://data/weapons"):
		if not f.ends_with(".tres"):
			continue
		var data := load("res://data/weapons/" + f) as WeaponData
		assert_true(SfxBank.has(data.fire_sound), "%s fire_sound %s" % [data.id, data.fire_sound])
		assert_true(data.fire_rumble.z > 0.0, "%s has a fire rumble" % data.id)
	# Every Sfx.play(&"...") literal in the scripts names a recipe.
	var re := RegEx.create_from_string("Sfx\\.play\\(&\"([a-z_]+)\"")
	for dir: String in ["res://scripts/enemies", "res://scripts/player", "res://scripts/gadgets", "res://scripts/combat", "res://scripts/ui", "res://scripts/weapons"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(f))
			for m: RegExMatch in re.search_all(text):
				assert_true(SfxBank.has(StringName(m.get_string(1))), "%s plays unknown sound %s" % [f, m.get_string(1)])


func test_rumble_keeps_the_stronger_request() -> void:
	GameFeel.rumble(0.2, 0.8, 0.5)
	GameFeel.rumble(0.1, 0.1, 0.1)
	assert_eq(GameFeel.last_rumble, Vector3(0.2, 0.8, 0.5), "weaker request ignored while the strong one runs")
	GameFeel.rumble(0.9, 0.9, 0.2)
	assert_eq(GameFeel.last_rumble, Vector3(0.9, 0.9, 0.2), "stronger request takes over")
	GameFeel.rumble_enabled = false
	GameFeel.reset()
	GameFeel.rumble(1.0, 1.0, 1.0)
	GameFeel.rumble_enabled = true
	assert_eq(GameFeel.last_rumble, Vector3.ZERO, "rumble off")


func test_shake_and_hit_stop_rumble() -> void:
	GameFeel.shake(0.5)
	assert_near(GameFeel.last_rumble.y, GameFeel.SHAKE_RUMBLE.y * 0.5, 0.001, "shake thumps in proportion")
	GameFeel.reset()
	GameFeel.hit_stop(0.06)
	assert_near(GameFeel.last_rumble.y, GameFeel.HIT_STOP_RUMBLE.y, 0.001, "hit-stop thumps even with time-stop off")


func test_firing_plays_the_weapon_sound_and_rumble() -> void:
	await _add_player()
	pad.next.weapon_slot = player.weapon_paths.find("res://data/weapons/owl_lens_rifle.tres")
	await wait_frames(2)
	pad.next.fire_held = true
	await wait_frames(2)
	pad.next.fire_held = false
	var data := player.current_weapon().data
	assert_true(Sfx.played(data.fire_sound), "played %s; history=%s" % [data.fire_sound, Sfx.history])
	assert_eq(GameFeel.last_rumble, data.fire_rumble, "weapon rumble")


func test_player_moves_have_sounds() -> void:
	await _add_player()
	pad.next.jump_pressed = true
	await wait_frames(2)
	assert_true(Sfx.played(&"jump"), "jump")
	await wait_seconds(1.2)
	assert_true(Sfx.played(&"land"), "land; history=%s" % [Sfx.history])
	pad.next.dodge_pressed = true
	await wait_frames(2)
	assert_true(Sfx.played(&"dodge"), "dodge")
	assert_eq(GameFeel.last_rumble, player.tuning.rumble_dodge, "dodge rumble")
	await wait_seconds(0.5)
	pad.next.melee_pressed = true
	await wait_frames(2)
	assert_true(Sfx.played(&"swing"), "staff swing; history=%s" % [Sfx.history])


func test_enemy_hits_deaths_and_telegraphs_sound() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -12), PI) as BrassBull
	var winding := await wait_until(func() -> bool: return bull.state == &"windup", 4.0)
	assert_true(winding, "bull winds up")
	await wait_frames(1)
	assert_true(Sfx.played(&"windup"), "telegraph cue; history=%s" % [Sfx.history])
	bull.hurt_box.receive(DamageInfo.create(5.0, bull.global_position + Vector3.UP * 3.0))
	assert_true(Sfx.played(&"hit"), "hit sound")
	bull.health.apply_damage(DamageInfo.create(1000.0, bull.global_position))
	assert_true(Sfx.played(&"enemy_die"), "death sound")
	dummy.queue_free()


func test_armour_clanks_instead_of_hitting() -> void:
	add_floor()
	var p := spawn_enemy(PANGOLIN, Vector3.ZERO, 0.0, 1, false) as BrassPangolin
	await wait_frames(1)
	Sfx.reset()
	p.hurt_box.receive(DamageInfo.create(10.0, p.global_position + p.forward() * 4.0))
	assert_true(Sfx.played(&"clank"), "blocked hit clanks")
	assert_false(Sfx.played(&"hit"), "and does not also thud")
	Sfx.reset()
	p.hurt_box.receive(DamageInfo.create(10.0, p.global_position - p.forward() * 4.0))
	assert_true(Sfx.played(&"hit"), "rear hit thuds")
	assert_false(Sfx.played(&"clank"), "no clank from behind")
