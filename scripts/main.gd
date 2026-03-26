extends Node3D

const DOG_TEXTURE_PATH := "res://assets/dog.svg"
const TREE_TEXTURE_PATH := "res://assets/tree.svg"

const MOVE_SPEED := 8.0
const TURN_SPEED := 10.0
const WORLD_RADIUS := 24.0

@onready var dog_anchor: Node3D = $DogAnchor
@onready var dog_sprite: Sprite3D = $DogAnchor/DogSprite
@onready var camera_rig: Node3D = $CameraRig
@onready var follow_camera: Camera3D = $CameraRig/Camera3D

var _velocity: Vector3 = Vector3.ZERO
var _time := 0.0
var _dog_texture: Texture2D
var _tree_texture: Texture2D


func _ready() -> void:
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
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
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
	dog_sprite.position.y = 1.9 + sin(_time * 10.0) * 0.06 * speed_ratio
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
		sprite.pixel_size = 0.009
		sprite.offset = Vector2(0.0, -225.0)
		sprite.modulate = Color(0.96, 0.93, 0.88)
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
	dog_sprite.pixel_size = 0.007
	dog_sprite.offset = Vector2(0.0, -110.0)
	dog_sprite.shaded = true


func _setup_camera() -> void:
	camera_rig.position = dog_anchor.position
	follow_camera.position = Vector3(0.0, 12.0, 12.0)
	follow_camera.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
	follow_camera.fov = 52.0

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -36.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

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
	material.albedo_color = Color(0.29, 0.37, 0.23)
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _make_cardboard_edge_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
