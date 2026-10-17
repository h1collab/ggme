shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

// Original Kenney atlas defines authored material regions. Detail maps are
// verified Poly Haven Metal Plate 02 CC0, projected in MODEL space so they
// remain attached to the original moving GLB (no generated geometry).
uniform sampler2D source_atlas : source_color, filter_nearest;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_metallic : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_scale = 7.0;
uniform float normal_strength = 0.12;
varying vec3 local_position;
varying vec3 local_normal;
varying mat3 normal_to_view;

vec3 projected(sampler2D tex, vec3 p, vec3 weights) {
	return texture(tex,p.zy).rgb*weights.x + texture(tex,p.xz).rgb*weights.y + texture(tex,p.xy).rgb*weights.z;
}
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
	normal_to_view = MODELVIEW_NORMAL_MATRIX;
}
void fragment() {
	vec3 authored = texture(source_atlas,UV).rgb;
	float value = dot(authored,vec3(0.2126,0.7152,0.0722));
	float accent = step(authored.g+0.03,authored.r)*step(authored.g+0.05,authored.b);
	float alloy = smoothstep(0.28,0.65,value)*(1.0-accent);
	vec3 n = normalize(local_normal);
	vec3 weights = pow(abs(n),vec3(6.0));
	weights /= max(dot(weights,vec3(1.0)),0.0001);
	vec3 p = local_position*detail_scale;
	vec3 wear = projected(detail_albedo,p,weights);
	float wear_value = dot(wear,vec3(0.3333));
	vec3 graphite = vec3(0.035,0.043,0.052)+value*vec3(0.48,0.51,0.55);
	vec3 finish = mix(graphite,vec3(0.075,0.16,0.15),accent*0.8);
	ALBEDO = finish*(0.88+wear_value*0.34);
	float rough = projected(detail_roughness,p,weights).r;
	ROUGHNESS = mix(0.72,clamp(rough*0.68,0.30,0.63),alloy);
	METALLIC = alloy*projected(detail_metallic,p,weights).r*0.78;
	SPECULAR = 0.42;
	vec3 nx = texture(detail_normal,p.zy).rgb*2.0-1.0;
	vec3 ny = texture(detail_normal,p.xz).rgb*2.0-1.0;
	vec3 nz = texture(detail_normal,p.xy).rgb*2.0-1.0;
	vec3 mapped = vec3(nx.z*sign(n.x),nx.y,nx.x)*weights.x;
	mapped += vec3(ny.x,ny.z*sign(n.y),ny.y)*weights.y;
	mapped += vec3(nz.x,nz.y,nz.z*sign(n.z))*weights.z;
	NORMAL = normalize(normal_to_view*normalize(mix(n,mapped,normal_strength)));
}
