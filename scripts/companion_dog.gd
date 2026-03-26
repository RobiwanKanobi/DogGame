class_name CompanionDog
extends Node3D

const MOVE_SPEED := 8.0
const FOLLOW_BASE := 1.85
const SLOT_SPACING := 1.05
const LATERAL_STAGGER := 0.5
const CATCHUP_SPEED := 10.5
const ALIGN_TURN := 9.0
const WORLD_RADIUS := 24.0

var _sprite: Sprite3D
var _texture: Texture2D
var _pixel_size: float
var _sprite_offset_y: float

var _leader: Node3D
var _leader_sprite: Sprite3D
var _slot_index: int = 0
var _joined: bool = false
var _time_offset: float = 0.0


func setup(
	texture: Texture2D,
	pixel_size: float,
	sprite_pixel_offset: Vector2,
	spawn_position: Vector3,
	bob_time_offset: float
) -> void:
	_texture = texture
	_pixel_size = pixel_size
	_time_offset = bob_time_offset
	position = spawn_position
	position.y = 0.0

	_sprite = Sprite3D.new()
	_sprite.texture = texture
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.double_sided = false
	_sprite.pixel_size = pixel_size
	_sprite.offset = sprite_pixel_offset
	_sprite.shaded = true
	_sprite_offset_y = _half_height()
	_sprite.position.y = _sprite_offset_y
	add_child(_sprite)


func is_joined() -> bool:
	return _joined


func join(leader: Node3D, leader_sprite: Sprite3D, slot: int) -> void:
	_leader = leader
	_leader_sprite = leader_sprite
	_slot_index = slot
	_joined = true


func _half_height() -> float:
	if _texture == null:
		return 0.0
	return float(_texture.get_height()) * _pixel_size * 0.5


func _physics_process(delta: float) -> void:
	if not _joined or _leader == null:
		return

	var forward := Vector3(sin(_leader.rotation.y), 0.0, cos(_leader.rotation.y))
	var right := Vector3.UP.cross(forward)
	var back_dist := FOLLOW_BASE + float(_slot_index) * SLOT_SPACING
	var side_sign := 1.0 if (_slot_index % 2) == 0 else -1.0
	var side := side_sign * LATERAL_STAGGER * (1.0 + 0.35 * float(_slot_index))
	var target := _leader.position - forward * back_dist + right * side
	target.y = 0.0

	var to_target := target - position
	var dist := to_target.length()
	var dir := Vector3.ZERO
	if dist > 0.001:
		dir = to_target / dist
		var speed := minf(MOVE_SPEED * 1.08, dist * CATCHUP_SPEED)
		position += dir * speed * delta

	position.x = clampf(position.x, -WORLD_RADIUS, WORLD_RADIUS)
	position.z = clampf(position.z, -WORLD_RADIUS, WORLD_RADIUS)

	if dist > 0.25:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), ALIGN_TURN * delta)
		_sprite.flip_h = dir.x < 0.0
	else:
		rotation.y = lerp_angle(rotation.y, _leader.rotation.y, 6.0 * delta)
		if _leader_sprite:
			_sprite.flip_h = _leader_sprite.flip_h

	_bob_sprite(delta)


func _bob_sprite(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _time_offset
	var speed_ratio := 0.0
	var main_node := get_parent()
	if main_node != null and "_velocity" in main_node:
		var vel: Vector3 = main_node._velocity
		speed_ratio = clampf(vel.length() / MOVE_SPEED, 0.0, 1.0)

	var bob := sin(t * 10.0) * 0.06 * speed_ratio
	var tilt := sin(t * 8.0) * 0.03 * speed_ratio
	_sprite.position.y = _sprite_offset_y + bob
	_sprite.rotation.z = tilt
