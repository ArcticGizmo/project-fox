shader_type spatial;
// Textured Block surface (SurfaceStyle). World-space triplanar, so any Block size tiles
// with no UVs and neighbouring Blocks line up. Up-facing faces use the top set, the rest
// the side set; the top set spills down the sides by `lip_depth` with a wavy edge (grass
// over a dirt bank). Box edges get a soft painted highlight, and a very large-scale tint
// variation breaks up visible repeats. Blocks pass their half size per instance.

uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 top_tint : source_color = vec3(1.0);
uniform vec3 side_tint : source_color = vec3(1.0);
// Metres covered by one texture tile.
uniform float tile_size = 2.0;
uniform float normal_strength = 1.0;
uniform float roughness = 0.85;
// How far the top material wraps down the sides (0 = none).
uniform float lip_depth = 0.0;
uniform float blend_sharpness = 6.0;
uniform float edge_highlight = 0.12;
uniform float edge_width = 0.12;
uniform float macro_variation = 0.12;

instance uniform vec3 half_size = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 local_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	local_pos = VERTEX;
}

// Tangent-space normal from a green-up map, scaled. Normal-map imports keep only RG
// (two-channel compression), so z is rebuilt from x and y.
vec3 tangent_normal(sampler2D tex, vec2 uv) {
	vec2 xy = texture(tex, uv).xy * 2.0 - 1.0;
	float z = sqrt(max(0.0, 1.0 - dot(xy, xy)));
	return normalize(vec3(xy * normal_strength, z));
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	w /= (w.x + w.y + w.z);
	vec3 sgn = sign(n + vec3(0.0001));
	vec3 p = world_pos / tile_size;

	// Image "up" is world up on the sides; u runs to the viewer's right on each face.
	vec2 uv_x = vec2(-p.z * sgn.x, -p.y);
	vec2 uv_y = vec2(p.x, p.z);
	vec2 uv_z = vec2(p.x * sgn.z, -p.y);

	// Sides near the top edge take the top material (wavy line, like a grass lip).
	float wave = sin(world_pos.x * 3.1 + world_pos.z * 2.3) * 0.35 + sin(world_pos.x * 7.7 - world_pos.z * 5.9) * 0.15;
	float lip = lip_depth > 0.0 ? step(half_size.y - lip_depth * (0.75 + wave), local_pos.y) : 0.0;
	bool top_face = n.y > 0.0;

	vec3 alb_y = top_face ? texture(top_albedo, uv_y).rgb * top_tint : texture(side_albedo, uv_y).rgb * side_tint;
	vec3 alb_x = mix(texture(side_albedo, uv_x).rgb * side_tint, texture(top_albedo, uv_x).rgb * top_tint, lip);
	vec3 alb_z = mix(texture(side_albedo, uv_z).rgb * side_tint, texture(top_albedo, uv_z).rgb * top_tint, lip);
	vec3 albedo = alb_x * w.x + alb_y * w.y + alb_z * w.z;

	vec3 tn_y = top_face ? tangent_normal(top_normal, uv_y) : tangent_normal(side_normal, uv_y);
	vec3 tn_x = mix(tangent_normal(side_normal, uv_x), tangent_normal(top_normal, uv_x), lip);
	vec3 tn_z = mix(tangent_normal(side_normal, uv_z), tangent_normal(top_normal, uv_z), lip);
	// Each face's tangent (u), bitangent (image up) and normal in world space.
	vec3 nx = vec3(0.0, 0.0, -sgn.x) * tn_x.x + vec3(0.0, 1.0, 0.0) * tn_x.y + vec3(sgn.x, 0.0, 0.0) * tn_x.z;
	vec3 ny = vec3(1.0, 0.0, 0.0) * tn_y.x + vec3(0.0, 0.0, -1.0) * tn_y.y + vec3(0.0, sgn.y, 0.0) * tn_y.z;
	vec3 nz = vec3(sgn.z, 0.0, 0.0) * tn_z.x + vec3(0.0, 1.0, 0.0) * tn_z.y + vec3(0.0, 0.0, sgn.z) * tn_z.z;
	vec3 wn = normalize(nx * w.x + ny * w.y + nz * w.z);

	// Painted edge highlight: distance to the nearest box edge within this face.
	vec3 to_edge = half_size - abs(local_pos);
	vec3 face = step(half_size - 0.001, abs(local_pos));
	vec3 in_face = mix(to_edge, vec3(1e3), face);
	float edge = min(min(in_face.x, in_face.y), in_face.z);
	albedo *= 1.0 + edge_highlight * (1.0 - smoothstep(0.0, edge_width, edge));

	// Slow light/dark drift across big surfaces.
	float macro = texture(side_albedo, world_pos.xz / (tile_size * 9.7) + world_pos.y * 0.013).g;
	albedo *= 1.0 + (macro - 0.5) * 2.0 * macro_variation;

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
