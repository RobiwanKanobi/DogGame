shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 0.92, 0.2, 1.0);
uniform float outline_width : hint_range(0.5, 4.0) = 1.5;

void vertex() {
	vec3 cam_right = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 cam_forward = normalize(cross(cam_right, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(cam_right, 0.0),
			vec4(0.0, 1.0, 0.0),
			vec4(cam_forward, 0.0),
			MODEL_MATRIX[3]);
}

void fragment() {
	vec2 ts = vec2(textureSize(albedo_tex, 0));
	vec2 px = outline_width / ts;
	float a = texture(albedo_tex, UV).a;
	if (a < 0.5) {
		discard;
	}

	float wn = texture(albedo_tex, UV + vec2(0.0, px.y)).a;
	float ws = texture(albedo_tex, UV - vec2(0.0, px.y)).a;
	float we = texture(albedo_tex, UV + vec2(px.x, 0.0)).a;
	float ww = texture(albedo_tex, UV - vec2(px.x, 0.0)).a;

	if (wn > 0.5 && ws > 0.5 && we > 0.5 && ww > 0.5) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
