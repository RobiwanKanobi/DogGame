extends Node2D


func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var hello := Label.new()
	hello.text = "Hello World"
	ui.add_child(hello)
	hello.reset_size()
	var vp := get_viewport().get_visible_rect().size
	hello.position = (vp - hello.size) * 0.5
