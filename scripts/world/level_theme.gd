@tool
class_name LevelTheme
extends Resource
## One setting's look: Block surface roles mapped to SurfaceStyles, plus the sky, sun,
## haze and grading LevelRoot builds the environment from. A level picks its theme with
## `LevelRoot.level_theme`; Blocks without a level (tests, tools) use DEFAULT_PATH.
## Retheming a level swaps this resource: no Block moves, so no layout retest is needed.

const DEFAULT_PATH := "res://data/themes/storybook_town.tres"

@export var ground: SurfaceStyle
@export var path: SurfaceStyle
@export var platform: SurfaceStyle
@export var wall: SurfaceStyle
@export var metal: SurfaceStyle

@export_group("Atmosphere")
@export var sky_top: Color = Color(0.36, 0.5, 0.68)
@export var sky_horizon: Color = Color(0.93, 0.78, 0.58)
@export var ground_horizon: Color = Color(0.55, 0.45, 0.36)
@export var ground_bottom: Color = Color(0.22, 0.17, 0.14)
@export var sun_color: Color = Color(1.0, 0.9, 0.74)
@export var sun_energy: float = 1.25
## Sun pitch and yaw (degrees).
@export var sun_angle: Vector2 = Vector2(-52.0, 35.0)
@export var ambient_energy: float = 0.75
## Distance haze: a warm aerial perspective that softens far geometry and the abyss.
@export var fog_color: Color = Color(0.82, 0.8, 0.74)
@export var fog_density: float = 0.0022
@export var fog_sky_affect: float = 0.1
@export var ssao_intensity: float = 1.6
@export var saturation: float = 1.05

static var _default: LevelTheme


static func default_theme() -> LevelTheme:
	if _default == null:
		_default = load(DEFAULT_PATH) as LevelTheme
	return _default


## The style for a Block.Surface role (null for GREYBOX or an unset role).
func style_for(role: int) -> SurfaceStyle:
	match role:
		Block.Surface.GROUND:
			return ground
		Block.Surface.PATH:
			return path
		Block.Surface.PLATFORM:
			return platform
		Block.Surface.WALL:
			return wall
		Block.Surface.METAL:
			return metal
	return null
