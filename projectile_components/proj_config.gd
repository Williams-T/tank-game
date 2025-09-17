@tool
extends Resource
class_name ProjectileConfig

@export var config_name: String = "Standard Shell"
@export var movement: MovementComponent
@export var trigger: TriggerComponent
@export var effect: EffectComponent
@export var visual: VisualComponent
@export var lifetime: LifetimeComponent

@export_group("File Operations")
#@export var save_config: bool = false : set = _save_config
#@export var load_config: bool = false : set = _load_config

@export_tool_button("save") var save_button = _save_config.bind(self)
@export_tool_button("load") var load_button = _load_config.bind(self)

const CONFIG_DIR = "res://configurations/projectiles/"

signal config_changed()

func _init():
	property_list_changed.connect(func (): config_changed.emit())
	# Create default components if none assigned
	if not movement:
		movement = MovementComponent.new()
	if not trigger:
		trigger = TriggerComponent.new()
	if not effect:
		effect = EffectComponent.new()
	if not visual:
		visual = VisualComponent.new()
	if not lifetime:
		lifetime = LifetimeComponent.new()

func _save_config(value):
	if not value:
		return
		
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(CONFIG_DIR):
		DirAccess.open("res://").make_dir_recursive(CONFIG_DIR)
	
	# Save as .tres file
	var file_path = CONFIG_DIR + config_name.to_snake_case() + ".tres"
	var result = ResourceSaver.save(self, file_path)
	
	if result == OK:
		print("Config saved to: ", file_path)
	else:
		print("Failed to save config")

func _load_config(value):
	if not value:
		return
		
	# This will trigger the file dialog in the inspector
	# Godot will automatically open file dialog when you click the folder icon
	# that appears next to export_file properties
	pass

# Alternative: Custom file dialog (more control)
@export_file("*.tres", "res://configurations/projectiles") var load_file_path: String : set = _on_file_selected

func _on_file_selected(path: String):
	if path.is_empty():
		return
		
	var loaded_config = load(path)
	if loaded_config is ProjectileConfig:
		# Copy values from loaded config
		config_name = loaded_config.config_name
		movement = loaded_config.movement
		trigger = loaded_config.trigger
		effect = loaded_config.effect
		visual = loaded_config.visual
		lifetime = loaded_config.lifetime
		print("Config loaded from: ", path)
	else:
		print("Invalid config file")
