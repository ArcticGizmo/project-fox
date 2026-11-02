class_name SfxBank
extends RefCounted
## Placeholder sound effects synthesised from short recipes (no audio assets
## yet). Each recipe is a duration plus layers: swept tones (`_t`) and
## low-passed noise (`_n`), each with its own attack/decay envelope. The mix is
## normalised, so a recipe's loudness is set by its `db`, not its layer amps.
## Swap a recipe for a real AudioStream later without touching the callers.

const MIX_RATE := 22050
const PEAK := 0.8

## id -> {dur, layers, db, jitter (random pitch +/-), gap (min seconds between plays)}
static var _recipes: Dictionary = {}


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		_recipes = _build_recipes()
	return _recipes


static func has(id: StringName) -> bool:
	return recipes().has(id)


## A tone layer: `wave` sine/square/saw/tri swept exponentially f0 -> f1.
static func _t(wave: StringName, f0: float, f1: float, amp: float, decay: float, start: float = 0.0, attack: float = 0.004, vib_rate: float = 0.0, vib_depth: float = 0.0) -> Dictionary:
	return {&"kind": &"tone", &"wave": wave, &"f0": f0, &"f1": f1, &"amp": amp, &"decay": decay, &"start": start, &"attack": attack, &"vib_rate": vib_rate, &"vib_depth": vib_depth}


## A noise layer through a one-pole low-pass swept lp0 -> lp1 Hz.
static func _n(lp0: float, lp1: float, amp: float, decay: float, start: float = 0.0, attack: float = 0.002) -> Dictionary:
	return {&"kind": &"noise", &"lp0": lp0, &"lp1": lp1, &"amp": amp, &"decay": decay, &"start": start, &"attack": attack}


static func _r(dur: float, layers: Array[Dictionary], db: float = 0.0, jitter: float = 0.05, gap: float = 0.03) -> Dictionary:
	return {&"dur": dur, &"layers": layers, &"db": db, &"jitter": jitter, &"gap": gap}


static func _build_recipes() -> Dictionary:
	return {
		# Weapons (WeaponData.fire_sound)
		&"shot_repeater": _r(0.09, [_n(7000, 1500, 0.8, 0.025), _t(&"square", 900, 300, 0.3, 0.03)], -6.0, 0.08),
		&"shot_hornet": _r(0.14, [_t(&"saw", 330, 260, 0.6, 0.06, 0.0, 0.01, 45.0, 0.15), _n(3000, 3000, 0.2, 0.04)], -9.0, 0.12),
		&"shot_flame": _r(0.2, [_n(1400, 500, 1.0, 0.09, 0.0, 0.02)], -8.0, 0.1, 0.05),
		&"shot_rifle": _r(0.4, [_n(9000, 700, 0.9, 0.08), _t(&"sine", 150, 55, 0.8, 0.14), _t(&"tri", 2600, 1800, 0.15, 0.05)], -2.0, 0.03),
		&"shot_lash": _r(0.18, [_t(&"sine", 2200, 500, 0.5, 0.05, 0.0, 0.02), _n(8000, 4000, 0.7, 0.02, 0.06)], -5.0, 0.08),
		&"shot_mortar": _r(0.3, [_t(&"sine", 190, 70, 0.9, 0.1), _n(600, 300, 0.5, 0.06)], -3.0, 0.05),
		&"shot_zap": _r(0.24, [_t(&"square", 1300, 280, 0.4, 0.08, 0.0, 0.004, 90.0, 0.35), _n(7000, 5000, 0.4, 0.04)], -8.0, 0.06),
		&"shot_frost": _r(0.3, [_t(&"sine", 2400, 1500, 0.6, 0.12), _t(&"tri", 3600, 3000, 0.3, 0.06), _n(9000, 6000, 0.2, 0.03)], -8.0, 0.08),
		&"shot_spit": _r(0.15, [_n(2600, 700, 0.8, 0.05), _t(&"sine", 520, 240, 0.5, 0.05)], -6.0, 0.1),
		&"shot_silk": _r(0.13, [_t(&"tri", 900, 1900, 0.7, 0.06, 0.0, 0.01), _n(5000, 5000, 0.2, 0.03)], -7.0, 0.08),
		&"shot_horn": _r(0.65, [_t(&"square", 220, 205, 0.35, 0.3, 0.0, 0.05, 6.0, 0.02), _t(&"sine", 110, 108, 0.6, 0.35, 0.0, 0.05)], -6.0, 0.02, 0.2),
		&"deploy": _r(0.22, [_t(&"tri", 420, 840, 0.6, 0.08), _n(4000, 4000, 0.4, 0.015, 0.12)], -6.0),
		&"deploy_chime": _r(0.8, [_t(&"sine", 1320, 1320, 0.6, 0.3), _t(&"sine", 1980, 1980, 0.35, 0.2, 0.06)], -8.0, 0.02),
		&"deploy_heavy": _r(0.35, [_t(&"sine", 130, 75, 0.9, 0.12), _n(900, 400, 0.5, 0.08)], -4.0),
		# Combat
		&"hit": _r(0.08, [_n(4500, 1500, 0.8, 0.02), _t(&"sine", 620, 300, 0.5, 0.03)], -8.0, 0.1, 0.02),
		&"crit": _r(0.22, [_n(5000, 1500, 0.7, 0.02), _t(&"sine", 1760, 1760, 0.5, 0.08), _t(&"sine", 2640, 2640, 0.25, 0.05)], -6.0, 0.03, 0.03),
		&"clank": _r(0.25, [_t(&"sine", 1250, 1240, 0.5, 0.09), _t(&"sine", 1730, 1720, 0.4, 0.07), _t(&"sine", 2470, 2460, 0.3, 0.05), _n(6000, 3000, 0.5, 0.012)], -6.0, 0.06, 0.04),
		&"enemy_die": _r(0.4, [_t(&"square", 420, 70, 0.4, 0.14), _n(1600, 400, 0.6, 0.12)], -5.0, 0.08),
		&"player_hurt": _r(0.25, [_t(&"square", 320, 140, 0.5, 0.08), _n(2500, 800, 0.5, 0.05)], -4.0, 0.05, 0.08),
		&"explosion": _r(0.8, [_n(2600, 180, 1.0, 0.22), _t(&"sine", 95, 38, 0.9, 0.25)], -2.0, 0.08, 0.05),
		&"impact_heavy": _r(0.4, [_t(&"sine", 75, 35, 1.0, 0.16), _n(1300, 300, 0.6, 0.07)], -3.0, 0.06, 0.08),
		# Enemy cues: the wind-up rises (danger coming), attacks are distinct one-shots.
		&"windup": _r(0.55, [_t(&"tri", 220, 760, 0.6, 2.0, 0.0, 0.4, 18.0, 0.04), _n(3000, 6000, 0.12, 2.0, 0.0, 0.4)], -10.0, 0.04, 0.1),
		&"alert": _r(0.22, [_t(&"square", 880, 880, 0.35, 0.05), _t(&"square", 1320, 1320, 0.35, 0.07, 0.08)], -10.0, 0.0, 0.15),
		&"lob": _r(0.18, [_t(&"sine", 320, 140, 0.8, 0.07), _n(1500, 800, 0.3, 0.03)], -7.0, 0.08),
		&"volley": _r(0.2, [_n(6000, 3000, 0.6, 0.05), _t(&"tri", 1600, 900, 0.5, 0.06)], -6.0, 0.05),
		&"charge": _r(0.5, [_n(900, 500, 0.8, 0.3, 0.0, 0.03), _t(&"saw", 95, 80, 0.3, 0.3)], -5.0, 0.05),
		&"roll": _r(0.6, [_n(700, 400, 0.8, 0.4, 0.0, 0.05), _t(&"sine", 60, 70, 0.4, 0.4, 0.0, 0.05, 9.0, 0.1)], -5.0, 0.05),
		&"dive": _r(0.5, [_n(2000, 5000, 0.7, 0.4, 0.0, 0.2), _t(&"sine", 900, 450, 0.25, 0.35)], -7.0, 0.05),
		# Player
		&"jump": _r(0.09, [_t(&"tri", 300, 620, 0.6, 0.04)], -13.0, 0.06, 0.05),
		&"double_jump": _r(0.18, [_t(&"tri", 420, 950, 0.5, 0.06), _n(3500, 1500, 0.4, 0.06)], -11.0, 0.05),
		&"dodge": _r(0.2, [_n(2800, 600, 1.0, 0.08, 0.0, 0.03)], -9.0, 0.08),
		&"land": _r(0.12, [_n(600, 300, 0.8, 0.04), _t(&"sine", 130, 60, 0.6, 0.05)], -9.0, 0.08, 0.1),
		&"swing": _r(0.16, [_n(3200, 900, 1.0, 0.05, 0.0, 0.035)], -10.0, 0.1, 0.05),
		# UI
		&"wheel_open": _r(0.1, [_t(&"sine", 500, 760, 0.6, 0.04)], -12.0, 0.0),
		&"wheel_select": _r(0.06, [_t(&"sine", 980, 980, 0.6, 0.02)], -12.0, 0.0, 0.02),
		&"level_up": _r(0.6, [_t(&"square", 523, 523, 0.25, 0.08), _t(&"square", 659, 659, 0.25, 0.08, 0.08), _t(&"square", 784, 784, 0.25, 0.08, 0.16), _t(&"sine", 1046, 1046, 0.6, 0.2, 0.24)], -6.0, 0.0, 0.2),
		&"pause": _r(0.08, [_t(&"sine", 440, 440, 0.6, 0.03)], -12.0, 0.0),
		# Gadgets
		&"grapple": _r(0.16, [_t(&"square", 600, 1300, 0.35, 0.05), _n(5000, 2000, 0.3, 0.04)], -8.0, 0.05),
		&"glide": _r(0.3, [_n(2500, 1200, 0.8, 0.12, 0.0, 0.06)], -11.0, 0.05, 0.2),
		&"dig": _r(0.35, [_n(900, 400, 1.0, 0.1, 0.0, 0.02), _n(1800, 600, 0.4, 0.05, 0.12)], -6.0, 0.08),
		&"conduit_charge": _r(0.45, [_t(&"saw", 200, 1200, 0.35, 0.3, 0.0, 0.03, 60.0, 0.1), _n(8000, 6000, 0.3, 0.1)], -7.0, 0.03),
		&"power_on": _r(0.7, [_t(&"sine", 220, 880, 0.6, 0.4, 0.0, 0.05), _t(&"square", 110, 440, 0.15, 0.4, 0.0, 0.05)], -6.0, 0.0),
	}


## Renders a recipe to a 16-bit mono stream. Deterministic per id.
static func build(id: StringName) -> AudioStreamWAV:
	var r: Dictionary = recipes()[id]
	var dur := float(r[&"dur"])
	var n := int(dur * MIX_RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for layer: Dictionary in r[&"layers"]:
		_render_layer(layer, buf, dur, rng)
	var peak := 0.0001
	for i: int in n:
		peak = maxf(peak, absf(buf[i]))
	var gain := PEAK / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i: int in n:
		# Short fade-out so nothing clicks at the end.
		var tail := clampf(float(n - i) / (MIX_RATE * 0.005), 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain * tail, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func _render_layer(l: Dictionary, buf: PackedFloat32Array, dur: float, rng: RandomNumberGenerator) -> void:
	var start := float(l[&"start"])
	var span := maxf(0.001, dur - start)
	var amp := float(l[&"amp"])
	var attack := maxf(0.0005, float(l[&"attack"]))
	var decay := maxf(0.001, float(l[&"decay"]))
	var first := int(start * MIX_RATE)
	var is_tone: bool = l[&"kind"] == &"tone"
	# Hoisted out of the per-sample loop (dictionary reads dominate otherwise).
	var f_start := float(l.get(&"f0", l.get(&"lp0", 1.0)))
	var f_ratio := float(l.get(&"f1", l.get(&"lp1", 1.0))) / f_start
	var vib_depth := float(l.get(&"vib_depth", 0.0))
	var vib_w := TAU * float(l.get(&"vib_rate", 0.0))
	var wave: StringName = l.get(&"wave", &"sine")
	var phase := 0.0
	var lp := 0.0
	for i: int in range(first, buf.size()):
		var t := float(i - first) / MIX_RATE
		var u := t / span
		var env := minf(1.0, t / attack) * exp(-maxf(0.0, t - attack) / decay)
		if env < 0.0005 and t > attack:
			break
		var v: float
		var f := f_start * pow(f_ratio, u)
		if is_tone:
			if vib_depth != 0.0:
				f *= 1.0 + vib_depth * sin(vib_w * t)
			phase = fmod(phase + f / MIX_RATE, 1.0)
			v = _wave(wave, phase)
		else:
			var a := 1.0 - exp(-TAU * f / MIX_RATE)
			lp += a * (rng.randf_range(-1.0, 1.0) - lp)
			# A low cutoff also lowers the level; undo that so amps mean the same
			# thing for noise at any cutoff.
			v = lp / sqrt(a / (2.0 - a))
		buf[i] += v * amp * env


static func _wave(kind: StringName, p: float) -> float:
	match kind:
		&"square":
			return 1.0 if p < 0.5 else -1.0
		&"saw":
			return 2.0 * p - 1.0
		&"tri":
			return 1.0 - 4.0 * absf(p - 0.5)
	return sin(TAU * p)
