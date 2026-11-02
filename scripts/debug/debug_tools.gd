class_name DebugTools
extends RefCounted
## Testing shortcuts behind the pause menu's Debug page: reach any weapon level,
## enemy or boss phase in seconds. Static so tests can call them directly.

const SPAWN_DISTANCE := 8.0
## Spawnable enemies: the wave table plus anything wave-less (the boss).
const EXTRA_ENEMIES: Dictionary = {
	&"stag": preload("res://scenes/enemies/furnace_stag.tscn"),
}


static func enemy_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in WaveManager.ENEMY_SCENES:
		out.append(k)
	for k: StringName in EXTRA_ENEMIES:
		out.append(k)
	return out


static func enemy_scene(kind: StringName) -> PackedScene:
	if WaveManager.ENEMY_SCENES.has(kind):
		return WaveManager.ENEMY_SCENES[kind] as PackedScene
	return EXTRA_ENEMIES.get(kind) as PackedScene


## Every weapon owned (as if bought; saved in levels that save).
static func own_all_weapons(player: Player) -> void:
	for w: Weapon in player.weapons:
		player.grant_weapon(w.data.id)


## Every weapon to its max level (full ammo).
static func max_all_weapons(player: Player) -> void:
	for w: Weapon in player.weapons:
		while not w.is_max_level():
			w.add_xp(w.xp_needed() - w.xp)


## Spawns `kind` SPAWN_DISTANCE in front of the player, facing it, aware.
## Wave-less like a wave enemy: respawns do not rebuild it.
static func spawn_enemy(player: Player, kind: StringName) -> Enemy:
	var scene := enemy_scene(kind)
	if scene == null or player.get_parent() == null:
		return null
	var e := scene.instantiate() as Enemy
	var fwd := player.facing_forward()
	e.position = player.global_position + fwd * SPAWN_DISTANCE + Vector3.UP * 0.1
	e.rotation.y = Player.yaw_of(-fwd)
	e.make_always_aware()
	player.get_parent().add_child(e)
	return e


## The first living boss in the tree, or null.
static func boss(tree: SceneTree) -> Enemy:
	for n: Node in tree.get_nodes_in_group(&"bosses"):
		var e := n as Enemy
		if e != null and not e.health.is_dead:
			return e
	return null


## Drops the boss's health just under the threshold of `phase` (it roars into it).
static func boss_to_phase(tree: SceneTree, phase: int) -> bool:
	var b := boss(tree) as FurnaceStag
	if b == null:
		return false
	var fraction := b.phase_2_at if phase == 2 else b.phase_3_at
	var target := b.health.max_health * fraction - 1.0
	if b.health.current > target:
		b.health.apply_damage(DamageInfo.create(b.health.current - target, b.global_position))
	if not b.aware:
		b.become_aware()
	return true
