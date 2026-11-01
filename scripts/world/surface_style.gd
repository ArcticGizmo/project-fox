@tool
class_name SurfaceStyle
extends Resource
## How one surface role looks: a top texture set (up-facing faces) and a side set, tiled
## in world space by block_surface.gdshader. Textures follow assets/textures/<name>/
## (albedo.png + green-up normal.png); see docs/art-pipeline.md.

const SHADER: Shader = preload("res://scripts/world/block_surface.gdshader")

@export var top_albedo: Texture2D
@export var top_normal: Texture2D
@export var side_albedo: Texture2D
@export var side_normal: Texture2D
@export var top_tint: Color = Color.WHITE
@export var side_tint: Color = Color.WHITE
## Metres covered by one texture tile.
@export var tile_size: float = 2.0
@export var normal_strength: float = 1.0
@export_range(0.0, 1.0) var roughness: float = 0.85
## How far the top set wraps down the sides (grass over a bank); 0 for none.
@export var lip_depth: float = 0.0

var _material: ShaderMaterial


## One shared material per style (Blocks pass their size as instance parameters).
func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"top_albedo", top_albedo)
		_material.set_shader_parameter(&"top_normal", top_normal)
		_material.set_shader_parameter(&"side_albedo", side_albedo if side_albedo != null else top_albedo)
		_material.set_shader_parameter(&"side_normal", side_normal if side_normal != null else top_normal)
		_material.set_shader_parameter(&"top_tint", top_tint)
		_material.set_shader_parameter(&"side_tint", side_tint)
		_material.set_shader_parameter(&"tile_size", tile_size)
		_material.set_shader_parameter(&"normal_strength", normal_strength)
		_material.set_shader_parameter(&"roughness", roughness)
		_material.set_shader_parameter(&"lip_depth", lip_depth)
	return _material
