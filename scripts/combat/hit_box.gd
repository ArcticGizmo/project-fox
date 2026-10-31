class_name HitBox
extends Area3D
## Deals damage to overlapping HurtBoxes while `active`. Each entity is hit at
## most once per activation, unless repeat_interval > 0 (flamethrower ticks).
## Set collision_mask to the hurtbox layer this box should hit.

signal hit_landed(hurt_box: HurtBox, info: DamageInfo)

@export var damage: float = 10.0
@export var knockback: float = 6.0
@export var knockback_up: float = 2.0
@export var repeat_interval: float = 0.0
@export var hit_stop: float = 0.0

var active: bool = false:
	set(value):
		if value and not active:
			_hit_times.clear()
		active = value
var source_weapon: Weapon = null

var _hit_times: Dictionary = {}
var _time: float = 0.0
var _outline: DebugOutline


func _init() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0


func _ready() -> void:
	_outline = DebugOutline.attach(self)


func _physics_process(delta: float) -> void:
	_time += delta
	if not active:
		return
	for hb: HurtBox in _pick_hurt_boxes():
		var key := hb.entity_id()
		if _hit_times.has(key):
			if repeat_interval <= 0.0 or _time - float(_hit_times[key]) < repeat_interval - 0.0001:
				continue
		_hit_times[key] = _time
		var info := DamageInfo.create(damage, global_position, knockback)
		info.knockback_up = knockback_up
		info.source_weapon = source_weapon
		if hb.receive(info):
			if hit_stop > 0.0:
				GameFeel.hit_stop(hit_stop)
			hit_landed.emit(hb, info)


## One hurtbox per entity. Area attacks should not crit just because a weak
## spot happens to sit inside the volume, so non-weak hurtboxes win.
func _pick_hurt_boxes() -> Array[HurtBox]:
	var best: Dictionary = {}
	for area: Area3D in get_overlapping_areas():
		var hb := area as HurtBox
		if hb == null:
			continue
		var key := hb.entity_id()
		var current := best.get(key) as HurtBox
		if current == null or (current.is_weak_spot and not hb.is_weak_spot):
			best[key] = hb
	var out: Array[HurtBox] = []
	for hb: HurtBox in best.values():
		out.append(hb)
	return out


func refresh_outline() -> void:
	if _outline != null:
		_outline.rebuild()


func get_debug_color() -> Color:
	return Color(1.0, 0.1, 0.1, 1.0) if active else Color(0.6, 0.1, 0.1, 0.3)
