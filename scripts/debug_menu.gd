extends CanvasLayer

signal outline_toggled(enabled: bool)
signal xray_toggled(enabled: bool)
signal punch_toggled(enabled: bool)

@onready var _panel: Panel = $Root/Panel
@onready var _outline_cb: CheckBox = $Root/Panel/Margin/VBox/OutlineCheck
@onready var _xray_cb: CheckBox = $Root/Panel/Margin/VBox/XRayCheck
@onready var _punch_cb: CheckBox = $Root/Panel/Margin/VBox/PunchCheck


func _ready() -> void:
	layer = 100
	visible = false
	_outline_cb.toggled.connect(func(on: bool) -> void: outline_toggled.emit(on))
	_xray_cb.toggled.connect(func(on: bool) -> void: xray_toggled.emit(on))
	_punch_cb.toggled.connect(func(on: bool) -> void: punch_toggled.emit(on))
	_set_focus_none_recursive(self)


func toggle_visible() -> void:
	visible = not visible


func is_open() -> bool:
	return visible


func _set_focus_none_recursive(n: Node) -> void:
	if n is Control:
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		_set_focus_none_recursive(c)
