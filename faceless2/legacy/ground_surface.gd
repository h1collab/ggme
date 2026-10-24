extends RefCounted

# World-space sampling keeps adjacent road tiles seamless. The original gravel
# photograph supplies small detail; low-frequency variation breaks repetition.
static func make(source: BaseMaterial3D, forest := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool forest_floor = false;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
vec3 gravel_detail(vec2 p) {
 // Rotate a second sample and blend slowly, avoiding identical repeated patches.
 vec3 a=texture(gravel,p).rgb;
 vec3 b=texture(gravel,mat2(vec2(0.8,-0.6),vec2(0.6,0.8))*p+vec2(13.7,9.2)).rgb;
 return mix(a,b,smoothstep(0.25,0.75,noise(p*0.16))*0.55);
}
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 vec2 uv=p*0.48;
 vec3 fine=gravel_detail(uv);
 vec3 broad=texture(gravel,p*0.117+vec2(0.37,0.61)).rgb;
 float patches=noise(p*0.21)*0.65+noise(p*0.067+8.3)*0.35;
 float edge=smoothstep(2.8,4.15,abs(p.x)+noise(p*0.65)*0.25);
 float wander=noise(vec2(p.y*0.06,0.0))*0.17-0.085;
 float tracks=exp(-pow((abs(p.x+wander)-1.12)/0.33,2.0));
 float damp=smoothstep(0.57,0.82,patches)*(0.35+0.65*tracks);
 vec3 earth=mix(fine,broad,0.24)*vec3(0.62,0.54,0.44);
 earth*=mix(0.77,1.15,patches)*(1.0-tracks*0.16);
 vec3 litter=mix(vec3(0.040,0.033,0.021),vec3(0.095,0.068,0.033),patches);
 float leaves=smoothstep(0.60,0.83,noise(p*5.2))*0.09;
 earth=mix(earth,litter+fine*0.09+leaves*vec3(0.12,0.085,0.035),forest_floor?1.0:edge*0.82);
 float runoff=smoothstep(0.68,0.88,noise(p*0.42+vec2(12.0,3.0)))*edge;
 earth*=1.0-runoff*0.22;
 ALBEDO=earth*(1.0-damp*0.24);
 METALLIC=0.0;
 ROUGHNESS=forest_floor?0.96:mix(0.94,0.57,damp);
 SPECULAR=forest_floor?0.0:0.27;
 float h=dot(fine,vec3(0.333));
 float hx=dot(gravel_detail(uv+vec2(0.002,0)).rgb,vec3(0.333));
 float hy=dot(gravel_detail(uv+vec2(0,0.002)).rgb,vec3(0.333));
 NORMAL_MAP=normalize(vec3((h-hx)*3.0,(h-hy)*3.0,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.55;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("gravel", source.albedo_texture)
	material.set_shader_parameter("forest_floor", forest)
	return material

static func forest_height(x: float, z: float) -> float:
	# Flat within every accessible shoulder; rolling terrain beyond barriers.
	var edge := smoothstep(8.8, 14.0, absf(x))
	return edge * (0.65 + 0.45 * sin(x * 0.22 + z * 0.09) + 0.24 * sin(z * 0.27 - x * 0.11))

static func terrain(plane: PlaneMesh, origin: Vector3) -> ArrayMesh:
	plane.subdivide_width = 54
	plane.subdivide_depth = 114
	var arrays := plane.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		var world := vertices[index] + origin
		vertices[index].y = forest_height(world.x, world.z)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, plane.material)
	var smooth := SurfaceTool.new()
	smooth.create_from(mesh, 0)
	smooth.generate_normals()
	smooth.generate_tangents()
	return smooth.commit()
