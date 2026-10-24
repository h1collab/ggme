shader_type spatial;
render_mode specular_disabled;

uniform vec4 ink_color : source_color = vec4(0.65, 0.75, 0.95, 1.0);
uniform bool viewmodel = false;
uniform float grid_strength = 0.0;
uniform float fracture_strength = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec2 cell = abs(fract(world_position.xz / 6.0 - 0.5) - 0.5) * 6.0;
    float line = 1.0 - smoothstep(0.035, 0.075, min(cell.x, cell.y));
    ALBEDO = ink_color.rgb * (1.0 - line * grid_strength);
    // World-space ink fractures: no particles, extra geometry or transparent layers.
    vec3 axis = abs(normalize(world_normal));
    vec2 p = axis.y > 0.6 ? world_position.xz : (axis.x > axis.z ? world_position.zy : world_position.xy);
    float jag = floor(p.y * 2.0) * 0.09 + sin(floor(p.y * 4.0) * 2.3) * 0.13;
    // A sparse broken seam, not tiled error bars on every facade/floor tile.
    float center = 1.7 + sin(floor(p.y / 5.0) * 1.71) * 0.6;
    float seam = abs(p.x + jag - center);
    float crack = (1.0 - smoothstep(0.018, 0.045, seam));
    float segment = step(0.35, fract(sin(floor(p.y / 3.0) * 17.31) * 43758.5453));
    float mask = crack * segment * fracture_strength;
    vec3 inverse_ink = vec3(step(0.35, 0.5 - dot(ink_color.rgb,vec3(0.333333))));
    ALBEDO = mix(ALBEDO, inverse_ink, mask);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    EMISSION = ink_color.rgb * (0.10);
}
void light() {
    float shade = 0.42 + 0.58 * step(0.28, dot(normalize(NORMAL), normalize(LIGHT)));
    float shadow = viewmodel ? (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.0) : ATTENUATION;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade * shadow * 0.55 / 3.14159265;
}
