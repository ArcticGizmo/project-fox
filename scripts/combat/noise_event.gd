class_name NoiseEvent
extends RefCounted
## Sounds that unaware enemies can hear. A noise carries `radius` metres; an
## enemy hears it when that circle overlaps its own `hearing_range`
## (distance <= radius + hearing_range). Hearing needs no line of sight.
## Callers: weapon fire (WeaponData.noise_radius), the staff slam landing and
## Explosion.detonate().
##
## Every emit is kept for RECORD_TIME seconds in `recent` (dictionaries with
## position, radius, time in seconds, heard count) so a debug view can draw it.

const RECORD_TIME := 2.0
const MAX_RECORDS := 64

static var recent: Array[Dictionary] = []


## Returns the number of enemies that heard it. `source` only supplies the
## scene tree (the weapon, the player, the exploding node).
static func emit(position: Vector3, radius: float, source: Node) -> int:
	if radius <= 0.0 or source == null or not source.is_inside_tree():
		return 0
	var heard := 0
	for n: Node in source.get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e.hear(position, radius):
			heard += 1
	_record(position, radius, heard)
	return heard


## Emits younger than `max_age` seconds, oldest first.
static func recent_emits(max_age: float = RECORD_TIME) -> Array[Dictionary]:
	var now := _now()
	var out: Array[Dictionary] = []
	for r: Dictionary in recent:
		if now - float(r[&"time"]) <= max_age:
			out.append(r)
	return out


static func _record(position: Vector3, radius: float, heard: int) -> void:
	var now := _now()
	while not recent.is_empty() and (now - float(recent[0][&"time"]) > RECORD_TIME or recent.size() >= MAX_RECORDS):
		recent.pop_front()
	recent.append({&"position": position, &"radius": radius, &"time": now, &"heard": heard})


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
