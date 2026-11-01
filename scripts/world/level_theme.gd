@tool
class_name LevelTheme
extends Resource
## Maps Block surface roles to SurfaceStyles for one setting. A level picks its theme with
## `LevelRoot.theme`; Blocks without a level (tests, tools) use DEFAULT.
## Retheming a level swaps this resource: no Block moves, so no layout retest is needed.

const DEFAULT_PATH := "res://data/themes/storybook_town.tres"

@export var ground: SurfaceStyle
@export var path: SurfaceStyle
@export var platform: SurfaceStyle
@export var wall: SurfaceStyle
@export var metal: SurfaceStyle

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
