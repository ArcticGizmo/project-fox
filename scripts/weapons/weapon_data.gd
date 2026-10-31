class_name WeaponData
extends Resource
## Definition of a weapon: identity, behaviour script and per-level stats.
## xp_to_next_level[i] is the XP needed to go from level i+1 to level i+2,
## so it must have exactly levels.size() - 1 entries.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
## Script extending Weapon that implements the firing behaviour.
@export var weapon_script: GDScript
@export var ammo_per_shot: int = 1
@export var xp_to_next_level: PackedInt32Array = PackedInt32Array()
@export var levels: Array[WeaponLevelStats] = []


func max_level() -> int:
	return levels.size()


func stats_for(level: int) -> WeaponLevelStats:
	return levels[clampi(level - 1, 0, levels.size() - 1)]


## Empty array means valid.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if levels.is_empty():
		problems.append("%s: no levels" % id)
	if xp_to_next_level.size() != levels.size() - 1:
		problems.append("%s: xp_to_next_level needs %d entries, has %d" % [id, levels.size() - 1, xp_to_next_level.size()])
	if weapon_script == null:
		problems.append("%s: missing weapon_script" % id)
	for i: int in levels.size():
		var s := levels[i]
		if s == null:
			problems.append("%s: level %d is null" % [id, i + 1])
			continue
		if s.damage <= 0.0 or s.fire_interval <= 0.0 or s.max_ammo <= 0:
			problems.append("%s: level %d has non-positive damage/fire_interval/max_ammo" % [id, i + 1])
	return problems
