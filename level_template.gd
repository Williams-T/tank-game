extends Node2D

@onready var cam : Camera2D = $Tank/Camera2D

func _ready() -> void:
	var cb = CodebaseExporter.new()
	cb.export_codebase_to_file()
