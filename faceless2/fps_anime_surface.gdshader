shader_type spatial;
render_mode specular_disabled;

uniform vec4 ink_color : source_color = vec4(0.65, 0.75, 0.95, 1.0);
uniform bool viewmodel = false;
uniform float grid_strength = 0.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 cell = abs(fract(world_position.xz / 6.0 - 0.5) - 0.5) * 6.0;
    float line = 1.0 - smoothstep(0.035, 0.075, min(cell.x, cell.y));
    ALBEDO = ink_color.rgb * (1.0 - line * grid_strength);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    EMISSION = ink_color.rgb * (0.10);
}
void light() {
    float shade = 0.42 + 0.58 * step(0.28, dot(normalize(NORMAL), normalize(LIGHT)));
    float shadow = viewmodel ? (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.0) : ATTENUATION;
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade * shadow * 0.55 / 3.14159265;
}
