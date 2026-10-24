shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float width_pixels = 1.5;
void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec2 direction = view_normal.xy;
    direction /= max(length(direction), 0.001);
    clip.xy += direction * width_pixels * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
}
void fragment() {
    ALBEDO = vec3(0.018, 0.023, 0.065);
}
