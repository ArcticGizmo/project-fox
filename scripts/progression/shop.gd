class_name Shop
extends RefCounted
## What a Magpie Peddler sells and the rules for buying (ShopMenu is only the
## UI): every weapon the fox doesn't own yet at WeaponData.price, and a refill
## of all owned weapons' ammo priced by how much is missing.

## Glimmer for refilling one weapon from empty to full.
const AMMO_REFILL_PER_WEAPON := 40


## Locked weapons in wheel order.
static func stock(player: Player) -> Array[Weapon]:
	var out: Array[Weapon] = []
	for w: Weapon in player.weapons:
		if not w.owned:
			out.append(w)
	return out


static func can_afford(player: Player, price: int) -> bool:
	return player.glimmer >= price


## Spends the price and grants the weapon. False if owned or too dear.
static func buy_weapon(player: Player, id: StringName) -> bool:
	var w := player.weapon_by_id(id)
	if w == null or w.owned or not can_afford(player, w.data.price):
		return false
	player.spend_glimmer(w.data.price)
	player.grant_weapon(id)
	return true


## 0 when every owned weapon is full.
static func refill_cost(player: Player) -> int:
	var missing := 0.0
	for w: Weapon in player.weapons:
		if w.owned and w.max_ammo() > 0:
			missing += 1.0 - float(w.ammo) / float(w.max_ammo())
	return ceili(missing * AMMO_REFILL_PER_WEAPON - 0.0001)


static func refill(player: Player) -> bool:
	var cost := refill_cost(player)
	if cost <= 0 or not can_afford(player, cost):
		return false
	player.spend_glimmer(cost)
	for w: Weapon in player.weapons:
		if w.owned:
			w.add_ammo(w.max_ammo())
	return true
