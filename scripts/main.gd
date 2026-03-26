extends Node3D

const DOG_TEXTURE_PATH := "res://assets/dog.png"
const COMPANION_BREED_TEXTURE_PATHS: Array[String] = [
	"res://assets/Cartoon Finnish Lapphund.png",
	"res://assets/Happy Icelandic Sheepdog.png",
]
const COMPANION_DOG_SCRIPT := preload("res://scripts/companion_dog.gd")
const RECRUIT_DISTANCE := 2.8
const COMPANION_MIN_TREE_DIST := 4.5
const COMPANION_MIN_START_DIST := 6.0
const COMPANION_MIN_SEPARATION := 5.0

const TREE_WORLD_POSITIONS: Array[Vector3] = [
	Vector3(-16.0, 0.0, -10.0),
	Vector3(-12.0, 0.0, 6.0),
	Vector3(-6.0, 0.0, 16.0),
	Vector3(4.0, 0.0, -15.0),
	Vector3(9.0, 0.0, 13.0),
	Vector3(16.0, 0.0, -6.0),
	Vector3(19.0, 0.0, 7.0),
	Vector3(-20.0, 0.0, 2.0),
	Vector3(0.0, 0.0, 20.0),
	Vector3(22.0, 0.0, 20.0),
]
const TREE_TEXTURE_PATH := "res://assets/tree.png"
const DEBUG_MENU_SCENE := preload("res://scenes/debug_menu.tscn")
const MOBILE_TOUCH_UI_SCENE := preload("res://scenes/mobile_touch_ui.tscn")
const TREE_OCCLUSION_SHADER := preload("res://shaders/tree_occlusion_punch.gdshader")
const DOG_OUTLINE_SHADER := preload("res://shaders/dog_occlusion_outline.gdshader")

const ACTION_MOVE_LEFT := "move_left"
const ACTION_MOVE_RIGHT := "move_right"
const ACTION_MOVE_FORWARD := "move_forward"
const ACTION_MOVE_BACK := "move_back"

const MOVE_SPEED := 8.0
const TURN_SPEED := 10.0
const WORLD_RADIUS := 24.0

const DOG_PIXEL_SIZE := 0.0035
const TREE_PIXEL_SIZE := 0.018
const CENTER_LIGHT_HEIGHT := 8.0
const CENTER_LIGHT_ENERGY := 4.0
const CENTER_LIGHT_RANGE := 45.0

const TREE_PHYSICS_LAYER := 2
const TREE_CAPSULE_RADIUS := 3.6
const TREE_CAPSULE_HEIGHT := 26.0
const TREE_CAPSULE_CENTER_Y := 13.0
const TREE_STUMP_RADIUS := 0.52
const TREE_STUMP_HEIGHT := 0.28
const TREE_STUMP_CENTER_Y := 0.14
## Same X as Tree_8 at (0,0,20); dog slightly toward camera so trunk sits between cam and dog.
const DEBUG_OCCLUSION_TEST_POS := Vector3(0.0, 0.0, 17.35)
const PUNCH_RADIUS_UV := 0.11
## Billboard dog is wider than one trunk ray; sample laterally + vertically so outline matches visible overlap.
const OCCLUSION_LATERAL_OFFSET := 0.34
const OCCLUSION_EXTRA_HEIGHT_FRAC := 0.55

@onready var dog_anchor: CharacterBody3D = $DogAnchor
@onready var dog_sprite: Sprite3D = $DogAnchor/DogSprite
@onready var camera_rig: Node3D = $CameraRig
@onready var follow_camera: Camera3D = $CameraRig/Camera3D

var _velocity: Vector3 = Vector3.ZERO
var _time := 0.0
var _dog_texture: Texture2D
var _tree_texture: Texture2D

var _tree_punch_material: ShaderMaterial
var _dog_outline_sprite: Sprite3D
var _debug_menu: CanvasLayer

var _debug_outline := false
var _debug_xray := false
var _debug_punch := false
var _dog_occluded := false
var _companions: Array[Node] = []
var _companion_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_configure_input()
	_dog_texture = load(DOG_TEXTURE_PATH) as Texture2D
	_tree_texture = load(TREE_TEXTURE_PATH) as Texture2D
	_tree_punch_material = ShaderMaterial.new()
	_tree_punch_material.shader = TREE_OCCLUSION_SHADER
	_tree_punch_material.set_shader_parameter("albedo_tex", _tree_texture)
	_tree_punch_material.set_shader_parameter("modulate_color", Color(0.96, 0.93, 0.88))
	_tree_punch_material.set_shader_parameter("punch_enabled", false)
	_tree_punch_material.set_shader_parameter("punch_radius_uv", PUNCH_RADIUS_UV)
	_build_ground()
	_build_trees()
	_setup_dog()
	_spawn_companion_dogs()
	_setup_camera()
	_setup_debug_menu()
	_setup_mobile_touch_ui()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_debug_menu.toggle_visible()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			_teleport_dog_for_occlusion_test()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_time += delta
	_update_movement(delta)
	_try_recruit_companions()
	_update_camera(delta)
	_update_cardboard_fx()
	_update_occlusion_debug()


func _update_movement(delta: float) -> void:
	var input_vector := Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_FORWARD,
		ACTION_MOVE_BACK
	)

	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)

	if move_direction.length() > 0.0:
		move_direction = move_direction.normalized()
		_velocity = move_direction * MOVE_SPEED
		var facing := Vector3(move_direction.x, 0.0, move_direction.z)
		dog_anchor.rotation.y = lerp_angle(dog_anchor.rotation.y, atan2(facing.x, facing.z), TURN_SPEED * delta)
		dog_sprite.flip_h = move_direction.x < 0.0
	else:
		_velocity = _velocity.lerp(Vector3.ZERO, min(1.0, delta * 6.0))

	dog_anchor.velocity = Vector3(_velocity.x, 0.0, _velocity.z)
	dog_anchor.move_and_slide()
	_velocity = Vector3(dog_anchor.velocity.x, 0.0, dog_anchor.velocity.z)
	var p := dog_anchor.position
	p.x = clampf(p.x, -WORLD_RADIUS, WORLD_RADIUS)
	p.z = clampf(p.z, -WORLD_RADIUS, WORLD_RADIUS)
	dog_anchor.position = p


func _update_camera(delta: float) -> void:
	var desired_position := dog_anchor.position
	camera_rig.position = camera_rig.position.lerp(desired_position, min(1.0, delta * 4.5))


func _update_cardboard_fx() -> void:
	var speed_ratio: float = clampf(_velocity.length() / MOVE_SPEED, 0.0, 1.0)
	var dog_foot_y: float = _sprite_world_half_height(_dog_texture, DOG_PIXEL_SIZE)
	var bob := sin(_time * 10.0) * 0.06 * speed_ratio
	var tilt := sin(_time * 8.0) * 0.03 * speed_ratio
	dog_sprite.position.y = dog_foot_y + bob
	dog_sprite.rotation.z = tilt
	_dog_outline_sprite.position = dog_sprite.position
	_dog_outline_sprite.rotation.z = dog_sprite.rotation.z
	_dog_outline_sprite.flip_h = dog_sprite.flip_h


func _dog_ray_origin() -> Vector3:
	var half_h: float = _sprite_world_half_height(_dog_texture, DOG_PIXEL_SIZE)
	return dog_anchor.global_position + Vector3(0.0, half_h, 0.0)


func _dog_occlusion_sample_points() -> Array[Vector3]:
	var half_h: float = _sprite_world_half_height(_dog_texture, DOG_PIXEL_SIZE)
	var base: Vector3 = dog_anchor.global_position
	var ry: float = dog_anchor.global_rotation.y
	var forward := Vector3(sin(ry), 0.0, cos(ry))
	var right := Vector3.UP.cross(forward)
	var heights: Array[float] = [half_h, half_h * (1.0 + OCCLUSION_EXTRA_HEIGHT_FRAC)]
	var laterals: Array[float] = [0.0, -OCCLUSION_LATERAL_OFFSET, OCCLUSION_LATERAL_OFFSET]
	var out: Array[Vector3] = []
	for h in heights:
		for lat in laterals:
			out.append(base + Vector3(0.0, h, 0.0) + right * lat)
	return out


func _ray_hits_tree_layer(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = TREE_PHYSICS_LAYER
	return not space.intersect_ray(query).is_empty()


func _update_occlusion_debug() -> void:
	var cam_from: Vector3 = follow_camera.global_position
	var punch_anchor: Vector3 = _dog_ray_origin()
	_dog_occluded = false
	for sample in _dog_occlusion_sample_points():
		if _ray_hits_tree_layer(cam_from, sample):
			_dog_occluded = true
			break

	var punch_on: bool = _debug_punch and _dog_occluded
	_tree_punch_material.set_shader_parameter("punch_enabled", punch_on)
	if punch_on:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var screen_px: Vector2 = follow_camera.unproject_position(punch_anchor)
			var uv := Vector2(
				screen_px.x / vp_size.x,
				1.0 - (screen_px.y / vp_size.y)
			)
			_tree_punch_material.set_shader_parameter("punch_center_uv", uv)

	if _debug_xray and _dog_occluded:
		dog_sprite.no_depth_test = true
		dog_sprite.sorting_offset = 12.0
	else:
		dog_sprite.no_depth_test = false
		dog_sprite.sorting_offset = 0.0

	var show_outline: bool = _debug_outline and _dog_occluded and not (_debug_xray and _dog_occluded)
	_dog_outline_sprite.visible = show_outline


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	plane.subdivide_depth = 4
	plane.subdivide_width = 4
	ground.mesh = plane
	ground.material_override = _make_ground_material()
	add_child(ground)


func _build_trees() -> void:
	for index in TREE_WORLD_POSITIONS.size():
		var tree_root := Node3D.new()
		tree_root.name = "Tree_%d" % index
		tree_root.position = TREE_WORLD_POSITIONS[index]
		add_child(tree_root)

		var sprite := Sprite3D.new()
		sprite.texture = _tree_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.double_sided = false
		sprite.no_depth_test = false
		sprite.pixel_size = TREE_PIXEL_SIZE
		sprite.offset = Vector2(0.0, -225.0)
		sprite.modulate = Color(0.96, 0.93, 0.88)
		sprite.position.y = _sprite_world_half_height(_tree_texture, TREE_PIXEL_SIZE)
		sprite.material_override = _tree_punch_material
		tree_root.add_child(sprite)

		var body := StaticBody3D.new()
		body.collision_layer = TREE_PHYSICS_LAYER
		body.collision_mask = 0
		body.position = Vector3(0.0, TREE_CAPSULE_CENTER_Y, 0.0)
		tree_root.add_child(body)

		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = TREE_CAPSULE_RADIUS
		capsule.height = TREE_CAPSULE_HEIGHT
		shape.shape = capsule
		body.add_child(shape)

		var stump := StaticBody3D.new()
		stump.collision_layer = TREE_PHYSICS_LAYER
		stump.collision_mask = 0
		stump.position = Vector3(0.0, TREE_STUMP_CENTER_Y, 0.0)
		tree_root.add_child(stump)
		var stump_shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = TREE_STUMP_RADIUS
		cyl.height = TREE_STUMP_HEIGHT
		stump_shape.shape = cyl
		stump.add_child(stump_shape)

		var base := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.25
		cylinder.bottom_radius = 0.45
		cylinder.height = 0.25
		base.mesh = cylinder
		base.position = Vector3(0.0, 0.12, 0.0)
		base.material_override = _make_cardboard_edge_material(Color(0.59, 0.49, 0.34))
		tree_root.add_child(base)


func _setup_dog() -> void:
	dog_sprite.texture = _dog_texture
	dog_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	dog_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	dog_sprite.double_sided = false
	dog_sprite.pixel_size = DOG_PIXEL_SIZE
	dog_sprite.offset = Vector2(0.0, -110.0)
	dog_sprite.shaded = true
	dog_sprite.position.y = _sprite_world_half_height(_dog_texture, DOG_PIXEL_SIZE)

	_dog_outline_sprite = Sprite3D.new()
	_dog_outline_sprite.name = "DogOutline"
	_dog_outline_sprite.texture = _dog_texture
	_dog_outline_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_dog_outline_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_dog_outline_sprite.double_sided = false
	_dog_outline_sprite.pixel_size = DOG_PIXEL_SIZE
	_dog_outline_sprite.offset = Vector2(0.0, -110.0)
	_dog_outline_sprite.shaded = false
	_dog_outline_sprite.position = dog_sprite.position
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = DOG_OUTLINE_SHADER
	outline_mat.set_shader_parameter("albedo_tex", _dog_texture)
	_dog_outline_sprite.material_override = outline_mat
	_dog_outline_sprite.visible = false
	_dog_outline_sprite.sorting_offset = 8.0
	dog_anchor.add_child(_dog_outline_sprite)


func _companion_texture_paths() -> Array[String]:
	var out: Array[String] = []
	for p in COMPANION_BREED_TEXTURE_PATHS:
		if ResourceLoader.exists(p):
			out.append(p)
		else:
			out.append(DOG_TEXTURE_PATH)
	return out.slice(0, 2)


func _spawn_companion_dogs() -> void:
	_companion_rng.randomize()
	var spawn_points: Array[Vector3] = []
	var next_slot := 0

	for path in _companion_texture_paths():
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null:
			tex = _dog_texture

		var pos := _random_companion_spawn(spawn_points)
		spawn_points.append(pos)

		var companion := Node3D.new()
		companion.set_script(COMPANION_DOG_SCRIPT)
		companion.name = "CompanionDog_%d" % next_slot
		add_child(companion)
		companion.call(
			"setup",
			tex,
			DOG_PIXEL_SIZE,
			Vector2(0.0, -110.0),
			pos,
			_companion_rng.randf() * TAU
		)
		_companions.append(companion)
		next_slot += 1


func _random_companion_spawn(existing: Array[Vector3]) -> Vector3:
	var margin := 3.0
	var min_c := -WORLD_RADIUS + margin
	var max_c := WORLD_RADIUS - margin
	for attempt in 48:
		var x := _companion_rng.randf_range(min_c, max_c)
		var z := _companion_rng.randf_range(min_c, max_c)
		var candidate := Vector3(x, 0.0, z)
		if candidate.distance_to(dog_anchor.position) < COMPANION_MIN_START_DIST:
			continue
		if not _is_clear_of_trees(candidate, COMPANION_MIN_TREE_DIST):
			continue
		var ok := true
		for p in existing:
			if candidate.distance_to(p) < COMPANION_MIN_SEPARATION:
				ok = false
				break
		if ok:
			return candidate
	return Vector3(10.0, 0.0, -8.0)


func _is_clear_of_trees(p: Vector3, min_dist: float) -> bool:
	for tp in TREE_WORLD_POSITIONS:
		var flat := Vector3(tp.x, 0.0, tp.z)
		if p.distance_to(flat) < min_dist:
			return false
	return true


var _next_follower_slot := 0


func _try_recruit_companions() -> void:
	for c in _companions:
		if c == null:
			continue
		if not c.has_method("is_joined") or not c.has_method("join"):
			continue
		if c.call("is_joined"):
			continue
		if dog_anchor.position.distance_to(c.position) <= RECRUIT_DISTANCE:
			c.call("join", dog_anchor, dog_sprite, _next_follower_slot)
			_next_follower_slot += 1


func _setup_camera() -> void:
	camera_rig.position = dog_anchor.position
	follow_camera.position = Vector3(0.0, 12.0, 12.0)
	follow_camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	follow_camera.fov = 52.0

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -36.0, 0.0)
	sun.light_energy = 1.35 * 0.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var center_light := OmniLight3D.new()
	center_light.position = Vector3(0.0, CENTER_LIGHT_HEIGHT, 0.0)
	center_light.light_energy = CENTER_LIGHT_ENERGY
	center_light.omni_range = CENTER_LIGHT_RANGE
	center_light.omni_attenuation = 0.8
	center_light.shadow_enabled = false
	camera_rig.add_child(center_light)

	var fill := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.11, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.82)
	environment.ambient_light_energy = 0.65
	environment.glow_enabled = true
	environment.glow_bloom = 0.15
	fill.environment = environment
	add_child(fill)


func _setup_debug_menu() -> void:
	_debug_menu = DEBUG_MENU_SCENE.instantiate() as CanvasLayer
	add_child(_debug_menu)
	_debug_menu.outline_toggled.connect(_on_debug_outline_toggled)
	_debug_menu.xray_toggled.connect(_on_debug_xray_toggled)
	_debug_menu.punch_toggled.connect(_on_debug_punch_toggled)


func _setup_mobile_touch_ui() -> void:
	var touch_ui: CanvasLayer = MOBILE_TOUCH_UI_SCENE.instantiate() as CanvasLayer
	touch_ui.name = "MobileTouchUI"
	add_child(touch_ui)
	if touch_ui.has_signal("debug_menu_requested"):
		touch_ui.debug_menu_requested.connect(_on_mobile_debug_pressed)


func _on_mobile_debug_pressed() -> void:
	_debug_menu.toggle_visible()


func _on_debug_outline_toggled(on: bool) -> void:
	_debug_outline = on


func _on_debug_xray_toggled(on: bool) -> void:
	_debug_xray = on


func _on_debug_punch_toggled(on: bool) -> void:
	_debug_punch = on
	if not on:
		_tree_punch_material.set_shader_parameter("punch_enabled", false)


func _make_ground_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.12, 0.06)
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _make_cardboard_edge_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _configure_input() -> void:
	_add_key_binding(ACTION_MOVE_LEFT, [KEY_A, KEY_LEFT])
	_add_key_binding(ACTION_MOVE_RIGHT, [KEY_D, KEY_RIGHT])
	_add_key_binding(ACTION_MOVE_FORWARD, [KEY_W, KEY_UP])
	_add_key_binding(ACTION_MOVE_BACK, [KEY_S, KEY_DOWN])


func _add_key_binding(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for keycode in keycodes:
		if _action_has_key(action_name, keycode):
			continue

		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


func _sprite_world_half_height(texture: Texture2D, pixel_size: float) -> float:
	if texture == null:
		return 0.0
	return float(texture.get_height()) * pixel_size * 0.5


func _teleport_dog_for_occlusion_test() -> void:
	dog_anchor.position = DEBUG_OCCLUSION_TEST_POS
	_velocity = Vector3.ZERO
	camera_rig.position = dog_anchor.position
	dog_anchor.rotation.y = 0.0
	dog_sprite.flip_h = false


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true

	return false
