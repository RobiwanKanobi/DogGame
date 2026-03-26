extends CanvasLayer

## On-screen D-pad + debug toggle. Do not use a full-screen IGNORE parent — it lets touches fall through to 3D on web.

signal debug_menu_requested

const MOVE_ACTIONS := {
	"up": &"move_forward",
	"down": &"move_back",
	"left": &"move_left",
	"right": &"move_right",
}

## touch index (mouse uses -1) -> action held by that pointer
var _pointer_action: Dictionary = {}


func _ready() -> void:
	layer = 50
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			_release_pointer(st.index)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_release_pointer(-1)


func _release_pointer(pointer_id: int) -> void:
	if not _pointer_action.has(pointer_id):
		return
	var act: StringName = _pointer_action[pointer_id]
	Input.action_release(act)
	_pointer_action.erase(pointer_id)


func _build_ui() -> void:
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
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(pad)

	var btn_size := Vector2(72.0, 72.0)
	var cx := 100.0
	var cy := 100.0
	var step := 80.0
	_add_dir_panel(pad, "up", Vector2(cx, cy - step), btn_size)
	_add_dir_panel(pad, "down", Vector2(cx, cy + step), btn_size)
	_add_dir_panel(pad, "left", Vector2(cx - step, cy), btn_size)
	_add_dir_panel(pad, "right", Vector2(cx + step, cy), btn_size)

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
	add_child(dbg)


func _add_dir_panel(parent: Control, dir_key: String, center: Vector2, size: Vector2) -> void:
	var p := Panel.new()
	p.name = "Pad_%s" % dir_key
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.custom_minimum_size = size
	p.position = center - size * 0.5
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.18)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)

	var action: StringName = MOVE_ACTIONS[dir_key]
	var label := Label.new()
	label.text = _arrow_label(dir_key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label)

	p.gui_input.connect(func(ev: InputEvent) -> void: _on_pad_gui_input(ev, action, p))
	parent.add_child(p)


func _on_pad_gui_input(event: InputEvent, action: StringName, ctrl: Control) -> void:
	var pointer_id := -1
	var pressed := false

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		pointer_id = st.index
		pressed = st.pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pointer_id = -1
		pressed = mb.pressed
	else:
		return

	if pressed:
		# One pointer, one move action; release previous if re-pressing same finger elsewhere
		if _pointer_action.has(pointer_id):
			var prev: StringName = _pointer_action[pointer_id]
			if prev != action:
				Input.action_release(prev)
		Input.action_press(action)
		_pointer_action[pointer_id] = action
	else:
		if _pointer_action.get(pointer_id) == action:
			Input.action_release(action)
			_pointer_action.erase(pointer_id)

	ctrl.accept_event()


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
