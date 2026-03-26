extends CanvasLayer

signal debug_menu_requested

const MOVE_ACTIONS := {
	"up": &"move_forward",
	"down": &"move_back",
	"left": &"move_left",
	"right": &"move_right",
}


func _ready() -> void:
	layer = 50
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var pad := Control.new()
	pad.name = "TouchPad"
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.anchor_left = 0.0
	pad.anchor_top = 1.0
	pad.anchor_right = 0.0
	pad.anchor_bottom = 1.0
	pad.offset_left = 16.0
	pad.offset_top = -200.0
	pad.offset_right = 16.0 + 200.0
	pad.offset_bottom = -16.0
	pad.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pad)

	var btn_size := Vector2(68.0, 68.0)
	var cx := 100.0
	var cy := 100.0
	var step := 76.0
	_add_dir_button(pad, "up", Vector2(cx, cy - step), btn_size)
	_add_dir_button(pad, "down", Vector2(cx, cy + step), btn_size)
	_add_dir_button(pad, "left", Vector2(cx - step, cy), btn_size)
	_add_dir_button(pad, "right", Vector2(cx + step, cy), btn_size)

	var dbg := Button.new()
	dbg.name = "DebugButton"
	dbg.text = "Debug"
	dbg.focus_mode = Control.FOCUS_NONE
	dbg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dbg.anchor_left = 1.0
	dbg.anchor_top = 0.0
	dbg.anchor_right = 1.0
	dbg.anchor_bottom = 0.0
	dbg.offset_left = -120.0
	dbg.offset_top = 12.0
	dbg.offset_right = -12.0
	dbg.offset_bottom = 52.0
	dbg.mouse_filter = Control.MOUSE_FILTER_STOP
	dbg.pressed.connect(func() -> void: debug_menu_requested.emit())
	root.add_child(dbg)


func _add_dir_button(parent: Control, dir_key: String, pos: Vector2, size: Vector2) -> void:
	var b := Button.new()
	b.name = "Btn_%s" % dir_key
	b.text = _arrow_label(dir_key)
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos - size * 0.5
	b.size = size
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var action: StringName = MOVE_ACTIONS[dir_key]
	b.button_down.connect(func() -> void: Input.action_press(action))
	b.button_up.connect(func() -> void: Input.action_release(action))
	parent.add_child(b)


func _arrow_label(dir_key: String) -> String:
	match dir_key:
		"up":
			return "▲"
		"down":
			return "▼"
		"left":
			return "◀"
		"right":
			return "▶"
		_:
			return "?"
