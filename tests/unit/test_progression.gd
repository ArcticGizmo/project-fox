extends TestCase
## Glimmer, owned weapons, the Magpie Peddler shop, saved pickups (Heartspring,
## GlimmerJar) and the save (Profile, SaveGame, LevelRoot save flow). The runner
## keeps SaveGame in memory and resets it per test; tests that touch the disk use
## their own file and put everything back.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const SLICE := "res://scenes/levels/slice_01.tscn"
const SLICE2 := "res://scenes/levels/slice_02.tscn"
const TEST_SAVE := "user://test_progression_save.json"


func _make_player(at: Vector3 = Vector3(0, 0.05, 0)) -> Player:
	var p := Player.new()
	p.input_provider = ScriptedInputProvider.new()
	p.position = at
	add_child(p)
	return p


func _kill(health: Health) -> void:
	health.apply_damage(DamageInfo.create(100000.0, Vector3.ZERO))


func _glimmer_in_tree() -> Array[Glimmer]:
	var out: Array[Glimmer] = []
	for n: Node in get_tree().get_nodes_in_group(Glimmer.GROUP):
		out.append(n as Glimmer)
	return out


# --- Glimmer ------------------------------------------------------------------

func test_spill_pays_out_the_amount_in_few_motes() -> void:
	add_floor()
	var motes := Glimmer.spill(self, Vector3(0, 1, 0), 137)
	assert_eq(Glimmer.total(motes), 137, "motes add up")
	assert_eq(motes.size(), 1 + 1 + 2 + 2, "greedy denominations 100 + 25 + 5 + 5 + 1 + 1")
	await wait_seconds(1.5)
	for g: Glimmer in motes:
		assert_true(g.is_settled(), "mote settled")
		assert_near(g.global_position.y, Glimmer.HOVER, 0.15, "hovers over the floor")


func test_enemy_death_spills_glimmer_that_flies_to_the_fox() -> void:
	add_floor()
	var player := _make_player()
	await wait_frames(2)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -3), 0.0, 1)
	rat.set_physics_process(false)
	await wait_frames(2)
	assert_eq(rat.glimmer_drop(), rat.xp_value * Enemy.GLIMMER_PER_XP, "default drop follows xp_value")
	var drop := rat.glimmer_drop()
	_kill(rat.health)
	assert_eq(Glimmer.total(_glimmer_in_tree()), drop, "spilled on death")
	var ok := await wait_until(func() -> bool: return player.glimmer == drop, 3.0)
	assert_true(ok, "all of it collected (got %d of %d)" % [player.glimmer, drop])
	assert_eq(_glimmer_in_tree().size(), 0, "motes gone")


func test_glimmer_out_of_reach_waits_for_the_fox() -> void:
	add_floor()
	var player := _make_player()
	var far := player.tuning.glimmer_magnet_radius + 4.0
	var motes := Glimmer.spill(self, Vector3(far, 1, 0), 5)
	await wait_seconds(1.5)
	assert_eq(player.glimmer, 0, "nothing pulled from outside the radius")
	assert_false(motes[0].magnetised, "not magnetised")
	player.global_position = Vector3(far - 2.0, 0.05, 0)
	var ok := await wait_until(func() -> bool: return player.glimmer == 5, 2.0)
	assert_true(ok, "collected once in reach")


func test_motes_expire() -> void:
	add_floor()
	var motes := Glimmer.spill(self, Vector3(0, 1, 0), 1)
	var mote := motes[0]
	mote.age = Glimmer.LIFETIME - 0.05
	await wait_frames(6)
	assert_false(is_instance_valid(mote), "freed after its lifetime")


func test_crate_spills_glimmer() -> void:
	add_floor()
	var crate := Crate.new()
	crate.position = Vector3(10, 0, 0)
	add_child(crate)
	await wait_frames(1)
	_kill(crate.health)
	assert_eq(Glimmer.total(_glimmer_in_tree()), crate.glimmer, "crate's glimmer spilled")


# --- Owned weapons and the shop -------------------------------------------------

func _starter_player() -> Player:
	add_floor()
	var player := _make_player()
	Profile.new().apply(player)
	return player


func test_new_profile_owns_only_the_starters() -> void:
	var player := _starter_player()
	for w: Weapon in player.weapons:
		assert_eq(w.owned, w.data.id in Profile.STARTER_WEAPONS, "%s ownership" % w.data.id)
		if w.data.id in Profile.STARTER_WEAPONS:
			assert_eq(w.data.price, 0, "%s is free" % w.data.id)
		else:
			assert_true(w.data.price > 0, "%s has a price" % w.data.id)
	assert_true(player.current_weapon().owned, "equipped weapon is owned")


func test_switching_skips_locked_weapons() -> void:
	var player := _starter_player()
	var owned_order: Array[int] = []
	for i: int in player.weapons.size():
		if player.weapons[i].owned:
			owned_order.append(i)
	player.select_weapon(owned_order[0])
	var pad := player.input_provider as ScriptedInputProvider
	for k: int in range(1, owned_order.size() + 1):
		pad.next.weapon_next = true
		await wait_frames(1)
		assert_eq(player.current_weapon_index, owned_order[k % owned_order.size()], "next lands on an owned weapon")
	pad.next.weapon_prev = true
	await wait_frames(1)
	assert_eq(player.current_weapon_index, owned_order[owned_order.size() - 1], "prev wraps to the last owned one")
	var locked := player.weapons.find(player.weapon_by_id(&"owl_lens_rifle"))
	var before := player.current_weapon_index
	player.select_weapon(locked)
	assert_eq(player.current_weapon_index, before, "a locked weapon can't be equipped")
	assert_true(Sfx.played(&"locked"), "it clunks")
	# The wheel can highlight a locked slot, but releasing on it keeps the current weapon.
	player.wheel_open = true
	player.wheel_highlight = locked
	player.close_wheel(true)
	assert_eq(player.current_weapon_index, before, "wheel release on a locked slot changes nothing")


func test_shop_sells_locked_weapons_and_refills_ammo() -> void:
	var player := _starter_player()
	var stock := Shop.stock(player)
	assert_eq(stock.size(), player.weapons.size() - Profile.STARTER_WEAPONS.size(), "every locked weapon for sale")
	var salamander := player.weapon_by_id(&"salamander_breath")
	var price := salamander.data.price
	player.add_glimmer(price - 1)
	assert_false(Shop.buy_weapon(player, &"salamander_breath"), "one short: no sale")
	assert_eq(player.glimmer, price - 1, "nothing spent")
	player.add_glimmer(1)
	var granted: Array[Weapon] = []
	player.weapon_granted.connect(func(w: Weapon) -> void: granted.append(w))
	assert_true(Shop.buy_weapon(player, &"salamander_breath"), "bought")
	assert_eq(player.glimmer, 0, "price spent")
	assert_true(salamander.owned, "owned now")
	assert_eq(granted, [salamander] as Array[Weapon], "granted signal")
	assert_eq(salamander.ammo, salamander.max_ammo(), "arrives full")
	assert_false(Shop.buy_weapon(player, &"salamander_breath"), "can't buy twice")
	# Refill: half of one weapon's ammo missing costs half the per-weapon price.
	assert_eq(Shop.refill_cost(player), 0, "all full: free and pointless")
	assert_false(Shop.refill(player), "nothing to refill")
	var w := player.current_weapon()
	w.ammo = w.max_ammo() / 2
	var expected := ceili((1.0 - float(w.ammo) / w.max_ammo()) * Shop.AMMO_REFILL_PER_WEAPON - 0.0001)
	assert_eq(Shop.refill_cost(player), expected, "priced by what's missing")
	player.add_glimmer(expected)
	assert_true(Shop.refill(player), "refilled")
	assert_eq(w.ammo, w.max_ammo(), "full again")
	assert_eq(player.glimmer, 0, "paid")


func test_shop_menu_buys_equips_and_unpauses() -> void:
	var player := _starter_player()
	var menu := ShopMenu.new()
	add_child(menu)
	await wait_frames(1)
	menu.open(player)
	assert_true(get_tree().paused, "trading pauses the game")
	var items := menu.listed_items()
	assert_eq(items[0], ShopMenu.REFILL, "refill first")
	assert_eq(items.size(), 1 + Shop.stock(player).size(), "then every locked weapon")
	var target := items[1]
	assert_false(menu.buy(target), "can't afford it yet")
	player.add_glimmer(player.weapon_by_id(target).data.price)
	assert_true(menu.buy(target), "bought through the menu")
	assert_eq(player.current_weapon().data.id, target, "and equipped")
	assert_false(target in menu.listed_items(), "no longer listed")
	assert_true(Sfx.played(&"purchase"), "purchase sound")
	menu.close()
	assert_false(get_tree().paused, "leaving unpauses")


func test_staff_on_the_bell_opens_trade() -> void:
	add_floor()
	var player := _make_player()
	var stall := MagpiePeddler.new()
	# The stall faces -Z: put it so its bell sits just ahead of the fox.
	stall.position = Vector3(-MagpiePeddler.BELL_POS.x, 0, -1.6 - MagpiePeddler.BELL_POS.z)
	add_child(stall)
	var asked: Array[MagpiePeddler] = []
	stall.trade_requested.connect(func(p: MagpiePeddler) -> void: asked.append(p))
	await wait_frames(10)
	assert_true(stall.prompt.visible, "prompt shows when the fox is near")
	var pad := player.input_provider as ScriptedInputProvider
	pad.next.melee_pressed = true
	var rang := await wait_until(func() -> bool: return asked.size() > 0, 1.0)
	assert_true(rang, "the staff swing rings the bell")
	assert_eq(stall.rings, 1, "once per swing")
	assert_true(Sfx.played(&"bell"), "bell sound")
	# Shots don't: the bell is a ConduitSocket (staff swing only).
	assert_eq(stall.socket.collision_layer, Layers.CONDUCTOR, "bell is staff-only")
	player.global_position = Vector3(0, 0.05, 20)
	await wait_frames(2)
	assert_false(stall.prompt.visible, "prompt hides when far")


# --- Profile and SaveGame -------------------------------------------------------

func test_profile_round_trips_through_json() -> void:
	var p := Profile.new()
	p.glimmer = 1234
	p.owned_weapons.append(&"owl_lens_rifle")
	p.weapon_progress[&"owl_lens_rifle"] = [3, 17]
	p.gadgets = [&"grapple", &"burrow"] as Array[StringName]
	p.heartsprings = 2
	p.mark_collected("slice_01", "Pickups/JarPillar")
	p.mark_collected("slice_01", "Pickups/JarPillar")
	p.set_checkpoint(SLICE, "Checkpoint2")
	var text := JSON.stringify(p.to_dict())
	var back := Profile.from_dict(JSON.parse_string(text) as Dictionary)
	assert_eq(back.glimmer, 1234, "glimmer")
	assert_eq(back.owned_weapons, p.owned_weapons, "owned weapons")
	assert_eq(back.weapon_progress[&"owl_lens_rifle"], [3, 17], "weapon progress")
	assert_eq(back.gadgets, p.gadgets, "gadgets")
	assert_eq(back.heartsprings, 2, "heartsprings")
	assert_true(back.has_collected("slice_01", "Pickups/JarPillar"), "collected")
	assert_eq(back.collected_count("slice_01"), 1, "marked once")
	assert_eq([back.checkpoint_level, back.checkpoint_node], [SLICE, "Checkpoint2"], "checkpoint")
	var junk := Profile.from_dict({"glimmer": "lots", "owned_weapons": 7, "weapon_progress": {"x": 3}})
	assert_eq(junk.glimmer, 0, "bad glimmer falls back")
	assert_eq(junk.owned_weapons, Profile.STARTER_WEAPONS, "bad weapons fall back")
	assert_true(junk.weapon_progress.is_empty(), "bad progress dropped")


func test_apply_and_capture_restore_the_fox() -> void:
	add_floor()
	var player := _make_player()
	var p := Profile.new()
	p.glimmer = 300
	p.owned_weapons.append(&"kraken_lash")
	p.weapon_progress[&"kraken_lash"] = [2, 5]
	p.gadgets = [&"glide"] as Array[StringName]
	p.heartsprings = 3
	p.apply(player)
	assert_eq(player.glimmer, 300, "glimmer")
	var lash := player.weapon_by_id(&"kraken_lash")
	assert_true(lash.owned, "bought weapon owned")
	assert_eq([lash.level, lash.xp], [2, 5], "level and xp")
	assert_true(player.has_gadget(&"glide"), "gadget")
	assert_eq(player.health.max_health, player.max_health_for(3), "heartsprings raise max health")
	assert_eq(player.health.current, player.health.max_health, "full")
	player.add_glimmer(50)
	lash.add_xp(1)
	var q := Profile.new()
	q.capture(player, [&"owl_lens_rifle"] as Array[StringName], [&"glide"] as Array[StringName])
	player.weapon_by_id(&"owl_lens_rifle").owned = true
	q.capture(player, [&"owl_lens_rifle"] as Array[StringName], [&"glide"] as Array[StringName])
	assert_eq(q.glimmer, 350, "glimmer captured")
	assert_eq(q.weapon_progress[&"kraken_lash"], [2, 6], "xp captured")
	assert_false(&"owl_lens_rifle" in q.owned_weapons, "lent weapon not saved as owned")
	assert_false(&"glide" in q.gadgets, "lent gadget not saved")
	assert_eq(q.heartsprings, 3, "heartsprings captured")


func test_save_game_writes_and_reads_its_file() -> void:
	var old_path := SaveGame.path
	SaveGame.path = TEST_SAVE
	SaveGame.persistent = true
	SaveGame.profile = Profile.new()
	SaveGame.profile.glimmer = 77
	SaveGame.profile.owned_weapons.append(&"echo_horn")
	SaveGame.save()
	SaveGame.profile = Profile.new()
	SaveGame.load_from_disk()
	assert_eq(SaveGame.profile.glimmer, 77, "glimmer read back")
	assert_true(&"echo_horn" in SaveGame.profile.owned_weapons, "weapons read back")
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	SaveGame.load_from_disk()
	assert_eq(SaveGame.profile.glimmer, 0, "unreadable file starts a new save")
	SaveGame.wipe()
	assert_false(FileAccess.file_exists(TEST_SAVE), "wipe deletes the file")
	SaveGame.path = old_path
	SaveGame.use_memory_only()


# --- Levels ---------------------------------------------------------------------

func _load(path: String) -> LevelRoot:
	var level := (load(path) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await wait_frames(3)
	return level


func _free_level(level: LevelRoot) -> void:
	remove_child(level)
	level.queue_free()
	await wait_frames(2)


func test_slice_has_a_stall_heartsprings_and_jars() -> void:
	var level := await _load(SLICE)
	var tally := level.pickup_tally()
	assert_eq(tally.get(&"heartspring", Vector2i.ZERO), Vector2i(0, 2), "two Heartsprings")
	assert_eq(tally.get(&"jar", Vector2i.ZERO), Vector2i(0, 6), "six jars")
	var stalls := get_tree().get_nodes_in_group(MagpiePeddler.GROUP)
	assert_eq(stalls.size(), 1, "one Magpie Peddler")
	var stall := stalls[0] as MagpiePeddler
	assert_true(stall.global_position.distance_to(level.player.global_position) < MagpiePeddler.PROMPT_RADIUS,
			"stall's prompt shows from the spawn")
	for w: Weapon in level.player.weapons:
		assert_eq(w.owned, w.data.id in Profile.STARTER_WEAPONS, "new save: %s" % w.data.id)
	stall.ring()
	assert_true(level.shop_menu.is_open, "the bell opens the level's shop")
	level.shop_menu.close()
	await _free_level(level)


func test_level_saves_and_restores_progress() -> void:
	var level := await _load(SLICE)
	var player := level.player
	# A jar: shoot it (any hit), take the glimmer.
	var jar := level.get_node(^"Pickups/JarCoverA") as GlimmerJar
	jar.health.apply_damage(DamageInfo.create(5.0, jar.global_position))
	assert_true(SaveGame.profile.has_collected("slice_01", "Pickups/JarCoverA"), "jar recorded as taken")
	# A Heartspring: walk into it.
	var heart := level.get_node(^"Pickups/HeartspringGrappleLedge") as Heartspring
	player.global_position = heart.global_position
	var found := await wait_until(func() -> bool: return player.heartsprings == 1, 1.0)
	assert_true(found, "Heartspring taken")
	assert_eq(player.health.max_health, player.max_health_for(1), "max health up")
	assert_eq(SaveGame.profile.heartsprings, 1, "saved at once")
	# Buy a weapon and light a checkpoint.
	player.add_glimmer(5000)
	assert_true(Shop.buy_weapon(player, &"owl_lens_rifle"), "bought")
	var cp := level.get_node(^"Checkpoint2") as Checkpoint
	cp.activate(player)
	assert_eq(SaveGame.profile.checkpoint_node, "Checkpoint2", "checkpoint saved")
	var glimmer := player.glimmer
	await _free_level(level)
	assert_eq(SaveGame.profile.glimmer, glimmer, "leaving the level saves")

	var again := await _load(SLICE)
	assert_eq(again.player.glimmer, glimmer, "glimmer back")
	assert_eq(again.player.heartsprings, 1, "heartsprings back")
	assert_true(again.player.owns_weapon(&"owl_lens_rifle"), "bought weapon back")
	assert_true(again.get_node_or_null(^"Pickups/HeartspringGrappleLedge") == null
			or (again.get_node(^"Pickups/HeartspringGrappleLedge") as SavedPickup).is_queued_for_deletion(), "taken Heartspring gone")
	assert_eq(again.pickup_tally()[&"heartspring"], Vector2i(1, 2), "tally counts the earlier find")
	assert_eq(again.pickup_tally()[&"jar"], Vector2i(1, 6), "and the jar")
	var cp2 := again.get_node(^"Checkpoint2") as Checkpoint
	assert_true(again.player.global_position.distance_to(cp2.spawn_position()) < 0.3, "resumes at the last checkpoint")
	assert_true(cp2.active, "that checkpoint is lit")
	assert_true(again.pause_menu.progress_text(again.player).contains("Heartsprings 1/2"), "pause menu shows the tally")
	# Restart Level starts from the pad again but keeps the rest.
	SaveGame.profile.clear_checkpoint()
	await _free_level(again)
	var fresh := await _load(SLICE)
	var spawn := fresh.get_node(^"PlayerSpawn") as Marker3D
	assert_true(fresh.player.global_position.distance_to(spawn.global_position) < 0.3, "no checkpoint: the pad")
	assert_eq(fresh.player.glimmer, glimmer, "glimmer kept")
	await _free_level(fresh)


func test_lent_weapons_and_gadgets_are_not_saved() -> void:
	var level := await _load(SLICE2)
	for w: Weapon in level.player.weapons:
		assert_true(w.owned, "%s lent in slice_02" % w.data.id)
	assert_eq(level.player.gadgets.unlocked.size(), Gadgets.ALL.size(), "every gadget lent")
	level.player.add_glimmer(40)
	await _free_level(level)
	assert_eq(SaveGame.profile.owned_weapons, Profile.STARTER_WEAPONS, "lent weapons not saved")
	assert_true(SaveGame.profile.gadgets.is_empty(), "lent gadgets not saved")
	assert_eq(SaveGame.profile.glimmer, 40, "glimmer earned there is kept")


func test_level_without_save_leaves_the_profile_alone() -> void:
	var level := LevelRoot.new()
	level.uses_save = false
	var floor_block := Block.new()
	floor_block.size = Vector3(50, 1, 50)
	floor_block.position.y = -0.5
	level.add_child(floor_block)
	SaveGame.profile.glimmer = 9
	add_child(level)
	await wait_frames(3)
	for w: Weapon in level.player.weapons:
		assert_true(w.owned, "sandbox owns %s" % w.data.id)
	assert_eq(level.player.glimmer, 0, "save not applied")
	level.player.add_glimmer(500)
	await _free_level(level)
	assert_eq(SaveGame.profile.glimmer, 9, "nothing written")


func test_arena_is_a_sandbox() -> void:
	var arena := Arena.new()
	assert_false(arena.uses_save, "the arena never saves")
	arena.free()


func test_reset_save_asks_twice() -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	await wait_frames(1)
	var asked: Array[int] = [0]
	menu.save_reset_requested.connect(func() -> void: asked[0] += 1)
	menu.open()
	menu.show_debug_page()
	menu.call(&"_on_reset_save")
	assert_eq(asked[0], 0, "first press only arms it")
	menu.call(&"_on_reset_save")
	assert_eq(asked[0], 1, "second press asks the level to wipe")
	assert_false(get_tree().paused, "menu closed")
	menu.open()
	menu.show_debug_page()
	menu.call(&"_on_reset_save")
	assert_eq(asked[0], 1, "re-arms each time the page opens")
	menu.close()
