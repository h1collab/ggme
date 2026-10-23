shader_type spatial;
render_mode unshaded, depth_prepass_alpha, cull_back;

// Texture-free anime spirit hands. Keep the original skinning and grip.
uniform vec4 core_color : source_color = vec4(0.025, 0.012, 0.085, 0.94);
uniform vec4 edge_color : source_color = vec4(0.46, 0.18, 1.0, 1.0);
uniform vec4 spirit_color : source_color = vec4(0.14, 0.85, 1.0, 1.0);

void fragment() {
    vec3 n = normalize(NORMAL);
    float facing = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
    float rim = pow(1.0 - facing, 2.4);
    float band = step(0.38, dot(n, normalize(vec3(-0.4, 0.8, 0.5))));
    float flow = sin(UV.y * 34.0 - TIME * 1.8 + sin(UV.x * 17.0) * 1.6);
    float vein = smoothstep(0.94, 1.0, flow) * 0.22;
    vec3 ink = core_color.rgb * mix(0.65, 1.65, band);
    vec3 aura = mix(edge_color.rgb, spirit_color.rgb, smoothstep(0.65, 1.0, rim));
    ALBEDO = ink + aura * (rim * 0.8 + vein);
    EMISSION = aura * (rim * 0.65 + vein * 0.4);
    ALPHA = mix(core_color.a, 1.0, rim);
}
