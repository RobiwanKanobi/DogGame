extends Node3D

const DOG_TEXTURE_PATH := "res://assets/dog.png"
const TREE_TEXTURE_PATH := "res://assets/tree.png"
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

@onready var dog_anchor: Node3D = $DogAnchor
@onready var dog_sprite: Sprite3D = $DogAnchor/DogSprite
@onready var camera_rig: Node3D = $CameraRig
@onready var follow_camera: Camera3D = $CameraRig/Camera3D

var _velocity: Vector3 = Vector3.ZERO
var _time := 0.0
var _dog_texture: Texture2D
var _tree_texture: Texture2D


func _ready() -> void:
	_configure_input()
	_dog_texture = load(DOG_TEXTURE_PATH) as Texture2D
	_tree_texture = load(TREE_TEXTURE_PATH) as Texture2D
	_build_ground()
	_build_trees()
	_setup_dog()
	_setup_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	_time += delta
	_update_movement(delta)
	_update_camera(delta)
	_update_cardboard_fx()


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

	dog_anchor.position += _velocity * delta
	dog_anchor.position.x = clamp(dog_anchor.position.x, -WORLD_RADIUS, WORLD_RADIUS)
	dog_anchor.position.z = clamp(dog_anchor.position.z, -WORLD_RADIUS, WORLD_RADIUS)


func _update_camera(delta: float) -> void:
	var desired_position := dog_anchor.position
	camera_rig.position = camera_rig.position.lerp(desired_position, min(1.0, delta * 4.5))


func _update_cardboard_fx() -> void:
	var speed_ratio: float = clampf(_velocity.length() / MOVE_SPEED, 0.0, 1.0)
	var dog_foot_y: float = _sprite_world_half_height(_dog_texture, DOG_PIXEL_SIZE)
	dog_sprite.position.y = dog_foot_y + sin(_time * 10.0) * 0.06 * speed_ratio
	dog_sprite.rotation.z = sin(_time * 8.0) * 0.03 * speed_ratio


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
	var positions := [
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

	for index in positions.size():
		var tree_root := Node3D.new()
		tree_root.name = "Tree_%d" % index
		tree_root.position = positions[index]
		add_child(tree_root)

		var sprite := Sprite3D.new()
		sprite.texture = _tree_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.double_sided = false
		sprite.no_depth_test = false
		sprite.pixel_size = TREE_PIXEL_SIZE
		sprite.offset = Vector2(0.0, -225.0)
		sprite.modulate = Color(0.96, 0.93, 0.88)
		sprite.position.y = _sprite_world_half_height(_tree_texture, TREE_PIXEL_SIZE)
		tree_root.add_child(sprite)

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


func _action_has_key(action_name: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true

	return false
