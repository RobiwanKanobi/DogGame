shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 modulate_color : source_color = vec4(0.96, 0.93, 0.88, 1.0);
uniform bool punch_enabled = false;
uniform vec2 punch_center_uv = vec2(0.5, 0.5);
uniform float punch_radius_uv = 0.09;

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
	vec4 tex = texture(albedo_tex, UV);
	float a = tex.a * modulate_color.a;
	if (a < 0.5) {
		discard;
	}

	if (punch_enabled) {
		vec2 aspect = vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
		vec2 d = (SCREEN_UV - punch_center_uv) * aspect;
		if (length(d) < punch_radius_uv) {
			discard;
		}
	}

	ALBEDO = tex.rgb * modulate_color.rgb;
	ALPHA = a;
}
