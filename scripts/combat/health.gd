class_name Health
extends Node

signal damaged(amount: float, info: DamageInfo)
signal healed(amount: float)
signal died(info: DamageInfo)
signal changed(current: float, maximum: float)

@export var max_health: float = 100.0

var current: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	reset()


func reset() -> void:
	current = max_health
	is_dead = false
	changed.emit(current, max_health)


## Returns the damage actually dealt.
func apply_damage(info: DamageInfo) -> float:
	if is_dead or info.amount <= 0.0:
		return 0.0
	var dealt := minf(info.amount, current)
	current -= dealt
	damaged.emit(dealt, info)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit(info)
	return dealt


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var before := current
	current = minf(max_health, current + amount)
	if current > before:
		healed.emit(current - before)
		changed.emit(current, max_health)


func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
