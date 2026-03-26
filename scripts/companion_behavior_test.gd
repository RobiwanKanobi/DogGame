extends SceneTree

## Headless integration test: companions recruit and stay behind the leader.
## Run: godot --headless --path /workspace -s res://scripts/companion_behavior_test.gd

var _main: Node3D


func _init() -> void:
	_main = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(_main)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame

	var companions := _companion_nodes()
	if companions.size() < 2:
		_fail("Expected at least 2 CompanionDog_* nodes, got %d" % companions.size())
		return

	var dog: Node3D = _main.dog_anchor as Node3D
	for c in companions:
		dog.global_position = c.global_position
		var joined_this := false
		for _f in 90:
			await physics_frame
			if c.has_method("is_joined") and c.call("is_joined"):
				joined_this = true
				break
		if not joined_this:
			_fail("Companion %s did not join after teleport" % c.name)
			return

	Input.action_press("move_forward")
	for _i in 180:
		await physics_frame
	Input.action_release("move_forward")

	await physics_frame

	if not _verify_behind_leader():
		return

	print("COMPANION_BEHAVIOR_TEST: PASS")
	quit(0)


func _companion_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in _main.get_children():
		if str(c.name).begins_with("CompanionDog_") and c is Node3D:
			out.append(c as Node3D)
	return out


func _all_joined() -> bool:
	for c in _companion_nodes():
		if c.has_method("is_joined") and not c.call("is_joined"):
			return false
	return true


func _leader_forward() -> Vector3:
	var dog: Node3D = _main.dog_anchor as Node3D
	return Vector3(sin(dog.rotation.y), 0.0, cos(dog.rotation.y))


func _verify_behind_leader() -> bool:
	var dog: Node3D = _main.dog_anchor as Node3D
	var forward := _leader_forward()
	var dog_pos := dog.global_position
	for c in _companion_nodes():
		if not c.has_method("is_joined") or not c.call("is_joined"):
			_fail("Companion not joined at verify")
			return false
		var rel := c.global_position - dog_pos
		rel.y = 0.0
		if rel.length() < 0.01:
			_fail("Companion on top of leader")
			return false
		var rel_n := rel.normalized()
		var behind_dot := forward.dot(rel_n)
		if behind_dot > -0.15:
			_fail(
				"Companion not behind leader (dot=%.3f dist=%.2f)" % [behind_dot, rel.length()]
			)
			return false
	return true


func _fail(msg: String) -> void:
	push_error("COMPANION_BEHAVIOR_TEST: FAIL — %s" % msg)
	quit(1)
