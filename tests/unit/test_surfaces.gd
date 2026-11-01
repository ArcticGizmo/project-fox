extends TestCase
## Block surface roles, level themes, and the texture sets they use (seamless, imported
## right). Texture checks run over every set in assets/textures, so a generated set that
## is dropped in gets checked too.

const TEXTURE_DIR := "res://assets/textures"


func test_greybox_blocks_keep_their_flat_colour() -> void:
	var b := Block.new()
	b.color = Color(0.2, 0.4, 0.6)
	add_child(b)
	var mat := b._mesh.material_override as StandardMaterial3D
	assert_true(mat != null, "flat material")
	assert_eq(mat.albedo_color, Color(0.2, 0.4, 0.6), "its colour")


func test_roles_use_the_default_theme_outside_a_level() -> void:
	var theme := LevelTheme.default_theme()
	for role: int in [Block.Surface.GROUND, Block.Surface.PATH, Block.Surface.PLATFORM, Block.Surface.WALL, Block.Surface.METAL]:
		var b := Block.new()
		b.surface = role as Block.Surface
		add_child(b)
		var style := theme.style_for(role)
		assert_true(style != null and style.top_albedo != null, "default theme styles role %d" % role)
		assert_eq(b._mesh.material_override, style.material(), "role %d drawn with its style" % role)


func test_a_level_theme_overrides_the_default() -> void:
	# Blocks look for the nearest ancestor with a `level_theme` (LevelRoot has one); a
	# stand-in with just that property avoids building a whole level.
	var stand_in := GDScript.new()
	stand_in.source_code = "extends Node3D\nvar level_theme: LevelTheme\n"
	stand_in.reload()
	var level := Node3D.new()
	level.set_script(stand_in)
	var theme := LevelTheme.new()
	theme.wall = SurfaceStyle.new()
	theme.wall.top_albedo = load(TEXTURE_DIR.path_join("planks/albedo.png")) as Texture2D
	level.set(&"level_theme", theme)
	add_child(level)
	var b := Block.new()
	b.surface = Block.Surface.WALL
	level.add_child(b)
	assert_eq(b._mesh.material_override, theme.wall.material(), "the level's style, not the default")
	assert_true(b._mesh.material_override != LevelTheme.default_theme().wall.material(), "default not used")


func test_gadget_gates_stay_flat_in_a_themed_level() -> void:
	var level := (load("res://scenes/levels/slice_01.tscn") as PackedScene).instantiate()
	var gates := level.find_children("*", "GadgetGate", true, false)
	assert_true(gates.size() >= 4, "slice has gates")
	for g: GadgetGate in gates:
		assert_eq(g.surface, Block.Surface.GREYBOX, "%s keeps its colour language" % g.name)
	var themed := 0
	for b: Block in level.find_children("*", "Block", true, false):
		if b.surface != Block.Surface.GREYBOX:
			themed += 1
	assert_true(themed > 40, "slice geometry is themed (%d)" % themed)
	level.free()


func test_every_texture_set_tiles_and_imports_its_normal_map() -> void:
	var sets := DirAccess.get_directories_at(TEXTURE_DIR)
	assert_true(sets.size() >= 6, "texture sets present")
	for set_name: String in sets:
		var dir := TEXTURE_DIR.path_join(set_name)
		for file: String in ["albedo.png", "normal.png"]:
			var tex := load(dir.path_join(file)) as Texture2D
			assert_true(tex != null, "%s/%s loads" % [set_name, file])
			if tex == null:
				continue
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			var seam := _edge_jump(img)
			assert_true(seam.x <= seam.y * 2.5 + 0.02,
					"%s/%s tiles: edge jump %.3f vs typical %.3f" % [set_name, file, seam.x, seam.y])
		var cfg := ConfigFile.new()
		cfg.load(dir.path_join("normal.png.import"))
		assert_eq(cfg.get_value("params", "compress/normal_map", 0), 1, "%s/normal.png imported as a normal map" % set_name)
		assert_true(bool(cfg.get_value("params", "mipmaps/generate", false)), "%s/normal.png has mipmaps" % set_name)


## (mean colour jump across the wrap seam, mean jump between neighbouring pixels inside),
## over both axes. A seamless tile's wrap looks like any other neighbour pair.
func _edge_jump(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var seam := 0.0
	var inside := 0.0
	var n := 0
	var inside_n := 0
	for i: int in range(0, mini(w, h), 4):
		seam += _diff(img.get_pixel(w - 1, i), img.get_pixel(0, i)) + _diff(img.get_pixel(i, h - 1), img.get_pixel(i, 0))
		n += 2
		# Typical neighbours: seven lines spread across each axis.
		for k: int in range(1, 8):
			var x := w * k / 8 + k
			var y := h * k / 8 + k
			inside += _diff(img.get_pixel(x, i), img.get_pixel(x + 1, i)) + _diff(img.get_pixel(i, y), img.get_pixel(i, y + 1))
			inside_n += 2
	return Vector2(seam / n, inside / inside_n)


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
