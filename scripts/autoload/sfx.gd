extends Node
## Sound effects: `Sfx.play(id, at)` plays a SfxBank sound, positional when `at`
## is a Vector3, flat otherwise (UI, the player's own gun). Streams are built on
## first use and cached. Each id has a minimum gap so rapid fire does not stack
## into noise, and voices are stolen oldest-first when the pool is full.

const VOICES_3D := 24
const VOICES_FLAT := 8

var enabled: bool = true
## Added to every sound (dB).
var volume_db: float = 0.0
## Last few ids played (newest last), for tests.
var history: Array[StringName] = []

var _streams: Dictionary = {}
var _last_played_ms: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_flat: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_flat: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Builds the whole bank in the background at startup so first plays never hitch.
var _warm_thread: Thread
var _mutex: Mutex = Mutex.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in VOICES_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool_3d.append(p)
	for i: int in VOICES_FLAT:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool_flat.append(p)
	SfxBank.recipes()  # build the table on this thread before the worker reads it
	_warm_thread = Thread.new()
	_warm_thread.start(warm_up, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	if _warm_thread != null and _warm_thread.is_started():
		_warm_thread.wait_to_finish()
	stop_all()
	_streams.clear()


## Silence every voice (quitting: give the audio server a few frames after this,
## or voices that were playing leak their playbacks).
func stop_all() -> void:
	for p: AudioStreamPlayer3D in _pool_3d:
		p.stop()
		p.stream = null
	for f: AudioStreamPlayer in _pool_flat:
		f.stop()
		f.stream = null


## `at`: Vector3 for a positional sound, null for a flat one. Returns false if
## the id is unknown, sound is off, or the id played too recently.
func play(id: StringName, at: Variant = null, volume_offset_db: float = 0.0) -> bool:
	if not enabled:
		return false
	if not SfxBank.has(id):
		push_warning("Sfx: unknown sound %s" % id)
		return false
	var recipe: Dictionary = SfxBank.recipes()[id]
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(id, -100000)) < int(float(recipe[&"gap"]) * 1000.0):
		return false
	_last_played_ms[id] = now
	var jitter := float(recipe[&"jitter"])
	var pitch := 1.0 + _rng.randf_range(-jitter, jitter)
	var db := float(recipe[&"db"]) + volume_db + volume_offset_db
	if at is Vector3:
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _pool_3d.size()
		p.stream = stream(id)
		p.global_position = at
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()
	else:
		var f := _pool_flat[_next_flat]
		_next_flat = (_next_flat + 1) % _pool_flat.size()
		f.stream = stream(id)
		f.volume_db = db
		f.pitch_scale = pitch
		f.play()
	history.append(id)
	if history.size() > 32:
		history.remove_at(0)
	return true


## The cached stream, built now if the warm-up has not reached it yet.
func stream(id: StringName) -> AudioStreamWAV:
	_mutex.lock()
	var s := _streams.get(id) as AudioStreamWAV
	_mutex.unlock()
	if s == null:
		s = SfxBank.build(id)
		_mutex.lock()
		_streams[id] = s
		_mutex.unlock()
	return s


## Build every stream (runs on the warm-up thread).
func warm_up() -> void:
	for id: StringName in SfxBank.recipes().keys():
		stream(id)


func played(id: StringName) -> bool:
	return history.has(id)


## Forget history and gaps (between tests).
func reset() -> void:
	history.clear()
	_last_played_ms.clear()
