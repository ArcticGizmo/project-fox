class_name WeaponLevelStats
extends Resource
## Stats for one weapon level. Each weapon only reads the fields it uses.

@export var damage: float = 10.0
## Seconds between shots (or between damage ticks for continuous weapons).
@export var fire_interval: float = 0.5
@export var max_ammo: int = 30
@export var projectile_count: int = 1
@export var projectile_speed: float = 20.0
@export var spread_deg: float = 0.0
## Extra enemies a shot can pass through.
@export var pierce: int = 0
## Homing turn rate in degrees per second.
@export var homing_deg_per_sec: float = 0.0
@export var max_range: float = 30.0
@export var area_radius: float = 0.0
@export var knockback: float = 4.0
@export var burn_dps: float = 0.0
@export var burn_duration: float = 0.0
## Extra multiplier on weak-spot hits.
@export var crit_multiplier: float = 1.0
@export var hit_stop: float = 0.0
## Lifetime of things the weapon leaves behind (mine fuse, sentry lifetime).
@export var duration: float = 0.0
## Interval for secondary actions (e.g. a sentry's own shots).
@export var sub_interval: float = 0.0
