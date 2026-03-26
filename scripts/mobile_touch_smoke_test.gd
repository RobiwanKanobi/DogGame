extends SceneTree

## Ensures main scene contains touch UI and CanvasLayers for mobile + debug.
## Run: godot --headless --path . -s res://scripts/mobile_touch_smoke_test.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var root_node: Node = main_scene.instantiate()
	root.add_child(root_node)
	await process_frame

	var has_touch := false
	var has_debug := false
	for c in root_node.get_children():
		if c.name == "MobileTouchUI":
			has_touch = true
		elif c is CanvasLayer and str(c.name).begins_with("DebugMenu"):
			has_debug = true
		elif c is CanvasLayer:
			var dn: String = String(c.name)
			if dn.findn("debug") >= 0:
				has_debug = true

	if not has_touch:
		push_error("MOBILE_TOUCH_SMOKE: missing MobileTouchUI")
		quit(1)
		return
	if not has_debug:
		push_error("MOBILE_TOUCH_SMOKE: missing debug CanvasLayer")
		quit(1)
		return

	print("MOBILE_TOUCH_SMOKE: PASS")
	quit(0)
