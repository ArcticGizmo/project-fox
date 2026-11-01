class_name Layers
extends RefCounted
## Physics layer bits. Names are mirrored in project.godot [layer_names].
##
## Bodies collide on WORLD / PLAYER / ENEMY.
## Damage only flows between HitBoxes/projectiles and HURTBOX layers, so
## friendly fire is impossible by construction.

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
const PLAYER_HURTBOX := 8
const ENEMY_HURTBOX := 16
## Areas that bounce enemy projectiles back (Hermit Bulwark).
const REFLECTOR := 32
## Things the staff can strike for the Copper Conduit Gauntlet (ConduitSocket on
## lightning barriers and conduit terminals). Only the staff swing masks it.
const CONDUCTOR := 64
