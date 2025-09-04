extends Node2D

@onready var cam : Camera2D = $Tank/Camera2D

#func _ready() -> void:
	#var cb = CodebaseExporter.new()
	#cb.export_codebase_to_file()
	

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_left", true):
		#cam.translate(Vector2(-10,0))
	#if event.is_action_pressed("ui_right", true):
		#cam.translate(Vector2(10,0))
	#if event.is_action_pressed("ui_down", true):
		#cam.translate(Vector2(0,10))
	#if event.is_action_pressed("ui_up", true):
		#cam.translate(Vector2(0,-10))
	#pass
