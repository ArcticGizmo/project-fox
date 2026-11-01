extends SceneTree
## Writes stylised, seamless placeholder surface textures to res://assets/textures/<name>/
## (albedo.png + normal.png) in the hand-painted look of docs/art-pipeline.md: chunky
## shapes, painted top-left light and dark crevices baked into the albedo, colours pulled
## from Ember's palette. Every pattern is built from periodic pieces (wrapped value noise,
## wrapped Voronoi, whole numbers of bricks/planks per tile), so the tiles are seamless.
## A generated texture set replaces one of these by overwriting the same two files.
##   godot --headless --path . -s res://tools/gen_textures.gd            (all)
##   godot --headless --path . -s res://tools/gen_textures.gd -- cobble  (one)

const SIZE := 512
const OUT_DIR := "res://assets/textures"
## Light for the painted shading (from the upper left, tangent space).
const LIGHT := Vector3(-0.5, 0.6, 0.62)

var _h: PackedFloat32Array
## Per-pixel base colour before shading.
var _c: PackedColorArray
## Per-pixel cavity amount (0 open surface .. 1 deep gap), darkens the paint.
var _cav: PackedFloat32Array


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	var makers := {
		"stone_wall": _stone_wall,
		"cobble": _cobble,
		"planks": _planks,
		"brass_plate": _brass_plate,
		"turf": _turf,
		"dirt": _dirt,
	}
	for name: String in makers:
		if not wanted.is_empty() and not name in wanted:
			continue
		var t := Time.get_ticks_msec()
		_h = PackedFloat32Array()
		_h.resize(SIZE * SIZE)
		_c = PackedColorArray()
		_c.resize(SIZE * SIZE)
		_cav = PackedFloat32Array()
		_cav.resize(SIZE * SIZE)
		var strength: float = (makers[name] as Callable).call()
		_write(name, strength)
		print("%s: %d ms" % [name, Time.get_ticks_msec() - t])
	quit()


# --- Patterns: fill _h, _c, _cav; return normal strength ------------------------------

## Stone bricks: 6 courses of 3, offset by half a brick each course, slightly wobbly
## hand-cut edges, each brick its own warm stone shade, dark mortar.
func _stone_wall() -> float:
	var stones := [Color("#b8a58e"), Color("#a48d74"), Color("#c7b59a"), Color("#9c8a78"), Color("#b39a7a")]
	var mortar := Color("#4e3d31")
	var rows := 6
	var cols := 3
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var wu := u + (_fbm(u, v, 4, 3, 11) - 0.5) * 0.025
			var wv := v + (_fbm(u, v, 4, 3, 23) - 0.5) * 0.025
			var ry := wv * rows
			var row := posmod(floori(ry), rows)
			var rx := wu * cols + (0.5 if row % 2 == 1 else 0.0)
			var col := posmod(floori(rx), cols)
			var fx := rx - floorf(rx)
			var fy := ry - floorf(ry)
			# Distance to the brick's edge in brick-height units.
			var edge := minf(minf(fx, 1.0 - fx) * float(rows) / float(cols) * 2.0, minf(fy, 1.0 - fy))
			var id := _hash(col, row, 7)
			var gap := 0.07
			var bevel := 0.16
			var body := smoothstep(gap, gap + bevel, edge)
			var lumps := _fbm(u, v, 8, 3, 31)
			var h := body * (0.75 + 0.25 * lumps) + (_hash(col, row, 9) - 0.5) * 0.12 * body
			var base: Color = stones[int(id * stones.size()) % stones.size()]
			base = base.lerp(base.darkened(0.25), _fbm(u, v, 6, 2, 41) * 0.5)
			_put(x, y, h, mortar.lerp(base, smoothstep(gap * 0.6, gap + 0.02, edge)), 1.0 - smoothstep(0.0, gap + 0.05, edge))
	return 5.0


## Rounded cobbles from wrapped Voronoi cells, packed dirt between.
func _cobble() -> float:
	var stones := [Color("#958879"), Color("#a59684"), Color("#86796d"), Color("#9d9483"), Color("#8c8a82")]
	var grout := Color("#4a3a2d")
	var cells := 7
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var wu := u + (_fbm(u, v, 5, 2, 13) - 0.5) * 0.03
			var wv := v + (_fbm(u, v, 5, 2, 17) - 0.5) * 0.03
			var vor := _voronoi(wu, wv, cells, 3)
			var border := vor.y - vor.x
			var body := smoothstep(0.04, 0.2, border)
			var dome := 1.0 - clampf(vor.x * 1.6, 0.0, 1.0)
			var h := body * (0.55 + 0.45 * dome) + body * (_fbm(u, v, 12, 2, 37) - 0.5) * 0.1
			var base: Color = stones[int(vor.z * stones.size()) % stones.size()]
			base = base.lerp(base.lightened(0.12), dome * 0.5)
			_put(x, y, h, grout.lerp(base, smoothstep(0.02, 0.08, border)), 1.0 - smoothstep(0.0, 0.12, border))
	return 6.0


## Wide wooden boards running along V: 5 per tile, staggered butt joints, stretched grain,
## a pair of nails near each joint.
func _planks() -> float:
	var woods := [Color("#8b5b37"), Color("#9c6a40"), Color("#7b4d2d"), Color("#a3734a")]
	var gap_col := Color("#2b1a10")
	var boards := 5
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var bx := u * boards
			var board := posmod(floori(bx), boards)
			var fx := bx - floorf(bx)
			# Each board is cut once per tile at its own height.
			var cut := _hash(board, 0, 3)
			var fv := v - cut
			fv -= floorf(fv)
			var side := minf(fx, 1.0 - fx) * 6.0
			var butt := minf(fv, 1.0 - fv) * float(boards) * 6.0
			var edge := minf(side, butt)
			var body := smoothstep(0.08, 0.35, edge)
			# Grain runs along the board: lines across fx, wobbling slowly down its length.
			var wobble := _fbm(u, v, 3, 3, 51 + board)
			var grain := 0.5 + 0.5 * sin((fx * 4.0 + wobble * 3.0 + _hash(board, 1, 9) * 4.0) * TAU)
			grain = grain * 0.7 + _fbm(u, v, 24, 2, 57) * 0.3
			var nail := 0.0
			for end: float in [0.04, 0.96]:
				for across: float in [0.25, 0.75]:
					var d := Vector2((fx - across) / float(boards), fv - end).length() * float(SIZE)
					nail = maxf(nail, 1.0 - smoothstep(4.0, 7.0, d))
			var h := body * (0.8 + 0.12 * grain) + nail * 0.15
			var base: Color = woods[int(_hash(board, 0, 5) * woods.size()) % woods.size()]
			base = base.lerp(base.darkened(0.3), grain * 0.35)
			base = base.lerp(Color("#3a2a20"), nail)
			_put(x, y, h, gap_col.lerp(base, smoothstep(0.04, 0.12, edge)), 1.0 - smoothstep(0.0, 0.2, edge))
	return 4.0


## Riveted brass plates, 2x2 per tile, with teal patina creeping in from the seams.
func _brass_plate() -> float:
	var brass := Color("#b88a3c")
	var light_brass := Color("#d1a557")
	var patina := Color("#5d8a7a")
	var seam := Color("#3d2b18")
	var plates := 2
	var rivets := 6
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var px := u * plates
			var py := v * plates
			var fx := px - floorf(px)
			var fy := py - floorf(py)
			var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
			var body := smoothstep(0.01, 0.05, edge)
			# Rivets in a ring just inside each plate's edge.
			var rivet := 0.0
			var inset := 0.07
			for i: int in rivets:
				var t := (float(i) + 0.5) / rivets
				for p: Vector2 in [Vector2(t, inset), Vector2(t, 1.0 - inset), Vector2(inset, t), Vector2(1.0 - inset, t)]:
					var d := Vector2(fx - p.x, fy - p.y).length() * float(SIZE) / plates
					rivet = maxf(rivet, 1.0 - smoothstep(6.0, 11.0, d))
			var dent := _fbm(u, v, 6, 3, 61)
			var h := body * (0.7 + 0.08 * dent) + rivet * 0.2
			var shine := _fbm(u, v, 3, 2, 67)
			var base := brass.lerp(light_brass, shine * 0.6)
			var green := smoothstep(0.62, 0.8, _fbm(u, v, 8, 3, 71) + (1.0 - smoothstep(0.0, 0.1, edge)) * 0.3)
			base = base.lerp(patina, green * 0.6)
			base = base.lerp(light_brass.lightened(0.15), rivet * 0.6)
			_put(x, y, h, seam.lerp(base, smoothstep(0.004, 0.02, edge)), 1.0 - smoothstep(0.0, 0.03, edge))
	return 4.0


## Painterly turf: two greens in soft clumps, darker hollows, a sprinkle of cream and
## orange flowers.
func _turf() -> float:
	var dark := Color("#4f6b2c")
	var mid := Color("#6f8f3a")
	var light := Color("#93ad4f")
	var petals := [Color("#e8d6ca"), Color("#de8643")]
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var clumps := _fbm(u, v, 6, 3, 81)
			var blades := _fbm(u, v, 48, 2, 83)
			var h := clumps * 0.7 + blades * 0.3
			var base := dark.lerp(mid, smoothstep(0.3, 0.55, clumps)).lerp(light, smoothstep(0.55, 0.8, clumps) * 0.8)
			base = base.lerp(base.lightened(0.1), blades * 0.4)
			var vor := _voronoi(u, v, 18, 91)
			var flower := (1.0 - smoothstep(0.08, 0.12, vor.x)) * float(vor.z > 0.82)
			base = base.lerp(petals[int(vor.z * 10.0) % 2] as Color, flower)
			_put(x, y, h + flower * 0.2, base, 1.0 - smoothstep(0.2, 0.45, h))
	return 2.5


## Packed earth with scattered pebbles.
func _dirt() -> float:
	var dark := Color("#5e4129")
	var mid := Color("#7a5634")
	var light := Color("#94704a")
	var pebble := Color("#a39684")
	for y: int in SIZE:
		for x: int in SIZE:
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var n := _fbm(u, v, 5, 4, 101)
			var base := dark.lerp(mid, smoothstep(0.15, 0.5, n)).lerp(light, smoothstep(0.6, 0.85, n) * 0.6)
			var vor := _voronoi(u, v, 9, 107)
			var stone := (1.0 - smoothstep(0.16, 0.24, vor.x)) * float(vor.z > 0.7)
			var h := n * 0.6 + stone * 0.4 * (1.0 - vor.x * 4.0)
			base = base.lerp(pebble.darkened(vor.z * 0.3), stone)
			_put(x, y, h, base, (1.0 - smoothstep(0.15, 0.4, n)) * (1.0 - stone) * 0.6)
	return 3.0


# --- Output ---------------------------------------------------------------------------

func _put(x: int, y: int, h: float, c: Color, cavity: float) -> void:
	var i := y * SIZE + x
	_h[i] = h
	_c[i] = c
	_cav[i] = clampf(cavity, 0.0, 1.0)


## Normal map from the wrapped height, then the painted albedo: base colour lit from the
## upper left by that normal, with crevices darkened (Ember-style baked shading).
func _write(name: String, strength: float) -> void:
	var albedo := PackedByteArray()
	albedo.resize(SIZE * SIZE * 3)
	var normal := PackedByteArray()
	normal.resize(SIZE * SIZE * 3)
	var light := LIGHT.normalized()
	for y: int in SIZE:
		var up := posmod(y - 1, SIZE) * SIZE
		var down := posmod(y + 1, SIZE) * SIZE
		var row := y * SIZE
		for x: int in SIZE:
			var left := posmod(x - 1, SIZE)
			var right := posmod(x + 1, SIZE)
			var dx := (_h[row + right] - _h[row + left]) * strength
			var dy := (_h[down + x] - _h[up + x]) * strength
			# Image rows run down; green-up (OpenGL) normals point +Y toward the top.
			var n := Vector3(-dx, dy, 1.0).normalized()
			var i := (row + x) * 3
			normal[i] = int((n.x * 0.5 + 0.5) * 255.0)
			normal[i + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			normal[i + 2] = int((n.z * 0.5 + 0.5) * 255.0)
			var shade := 0.82 + 0.35 * (n.dot(light) - light.z)
			var c := _c[row + x] * clampf(shade, 0.6, 1.25)
			c = c.lerp(c.darkened(0.55), _cav[row + x] * 0.7)
			albedo[i] = int(clampf(c.r, 0.0, 1.0) * 255.0)
			albedo[i + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
			albedo[i + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
	var dir := OUT_DIR.path_join(name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, albedo).save_png(dir.path_join("albedo.png"))
	Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, normal).save_png(dir.path_join("normal.png"))


# --- Periodic noise -------------------------------------------------------------------

static func _hash(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


## Value noise with `period` cells across the tile, wrapping at the edges.
static func _value(u: float, v: float, period: int, seed: int) -> float:
	var x := u * period
	var y := v * period
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(ix, period)
	var x1 := posmod(ix + 1, period)
	var y0 := posmod(iy, period)
	var y1 := posmod(iy + 1, period)
	var a := lerpf(_hash(x0, y0, seed), _hash(x1, y0, seed), fx)
	var b := lerpf(_hash(x0, y1, seed), _hash(x1, y1, seed), fx)
	return lerpf(a, b, fy)


## Fractal value noise, each octave doubling the (whole-number) period so it still wraps.
static func _fbm(u: float, v: float, period: int, octaves: int, seed: int) -> float:
	var total := 0.0
	var amp := 0.5
	var norm := 0.0
	var p := period
	for o: int in octaves:
		total += _value(u, v, p, seed + o * 17) * amp
		norm += amp
		amp *= 0.5
		p *= 2
	return total / norm


## Wrapped Voronoi with `cells` jittered points per side: (nearest distance, second
## nearest, nearest cell's random id), distances in cell units.
static func _voronoi(u: float, v: float, cells: int, seed: int) -> Vector3:
	var x := u * cells
	var y := v * cells
	var ix := floori(x)
	var iy := floori(y)
	var f1 := 9.0
	var f2 := 9.0
	var id := 0.0
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			var cx := ix + ox
			var cy := iy + oy
			var wx := posmod(cx, cells)
			var wy := posmod(cy, cells)
			var px := cx + 0.15 + 0.7 * _hash(wx, wy, seed)
			var py := cy + 0.15 + 0.7 * _hash(wx, wy, seed + 1)
			var d := Vector2(x - px, y - py).length()
			if d < f1:
				f2 = f1
				f1 = d
				id = _hash(wx, wy, seed + 2)
			elif d < f2:
				f2 = d
	return Vector3(f1, f2, id)
