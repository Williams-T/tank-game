extends Camera2D

@export_range(3.0, 100.0) var move_speed = 3.0
@export_range(0.5, 2.0) var zoom_speed = 1.0
var x_inverted = false
var target_zoom : float = 1.0
var current_zoom : float = 1.0
var target_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
var temp_vector : Vector2 = Vector2.ZERO
var shaky = true
var targets : Array[Node] = []
var split := false
@onready var split_layer := $SplitLayer
@onready var left_cam := $SplitLayer/Panel/HBoxContainer/LeftContainer/SubViewport/Camera2D
@onready var right_cam := $SplitLayer/Panel/HBoxContainer/RightContainer/SubViewport/Camera2D

var left_cam_path
var right_cam_path

func _enter_tree() -> void:
	temp_vector.x = current_zoom
	temp_vector.y = current_zoom
	current_pos = position
	zoom = temp_vector
	enabled = true
	make_current()

func _set_zoom(value = 1.0):
	target_zoom = value

func _physics_process(delta: float) -> void:
	if !split:
		if split_layer.visible != split:
			toggle_split(split)
		if abs(current_zoom - target_zoom) > 0.1:
			if temp_vector.x != target_zoom or temp_vector.y != target_zoom:
				temp_vector.x = target_zoom
				temp_vector.y = target_zoom
			zoom = zoom.lerp(temp_vector, delta * zoom_speed)
			current_zoom = zoom.x
		var targets_size = targets.size()
		if targets_size > 0:
			if targets_size == 1:
				if target_pos != targets[0].position:
					target_pos = targets[0].position
				if target_zoom != 2.0:
					target_zoom = 2.0
			else:
				target_pos = determine_midpoint(targets)
				target_zoom = determine_zoom(targets)
		if current_pos.distance_to(target_pos)>0.1:
			#if randf() > 0.95:
				#target_pos += Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			position = position.lerp(target_pos, delta * move_speed)
			current_pos = position
	else:
		if split_layer.visible != split:
			toggle_split(split)

func x_invert(val:bool):
	if !left_cam_path or !right_cam_path:
		return
	if val:
		targets[0].remote_transform.remote_path = right_cam_path
		targets[1].remote_transform.remote_path = left_cam_path
		x_inverted = true
	else:
		targets[0].remote_transform.remote_path = left_cam_path
		targets[1].remote_transform.remote_path = right_cam_path
		x_inverted = false

func toggle_split(val:bool):
	if (left_cam.get_parent() as SubViewport).world_2d != get_world_2d():
		var world = get_world_2d()
		left_cam.get_parent().world_2d = world
		right_cam.get_parent().world_2d = world
	if val == true:
		if left_cam_path and right_cam_path:
			split_layer.visible = val
		else:
			if targets.size() > 0:
				var min_x = INF
				var max_x = -INF
				for i in targets:
					if i is Tank:
						if !left_cam_path:
							left_cam_path = left_cam.get_path()
							i.remote_transform.remote_path = left_cam_path
						elif !right_cam_path:
							right_cam_path = right_cam.get_path()
							i.remote_transform.remote_path = right_cam_path
	else:
		split_layer.visible = val

func set_target(player : Tank):
	if !left_cam_path:
		pass
	elif !right_cam_path:
		pass
	else:
		pass
func determine_midpoint(locations : Array):
	var size : float = locations.size()
	var total_lats : float = 0.0
	var total_longs : float = 0.0
	for item in locations:
		total_lats += item.position.x
		total_longs += item.position.y
	temp_vector.x = total_lats / size
	temp_vector.y = total_longs / size
	if shaky and randf()>0.9:
		temp_vector += Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
	return temp_vector

func determine_zoom(locations: Array) -> float:
	# Get viewport dimensions
	var viewport_size = get_viewport_rect().size
	
	# Find the bounding box of all targets
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	
	for target in locations:
		var pos = target.position
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
	
	# Calculate required view area with padding
	var padding = 300.0  # Adjust for comfortable framing
	var required_width = (max_x - min_x) + padding * 2
	var required_height = (max_y - min_y) + padding * 2
	
	# Calculate zoom needed for each dimension
	# Lower zoom values = zoomed out (see more)
	var zoom_for_width = viewport_size.x / required_width
	var zoom_for_height = viewport_size.y / required_height
	
	# Use the smaller zoom to ensure everything fits
	var final_zoom = min(zoom_for_width, zoom_for_height)
	
	# Clamp to reasonable limits
	return clamp(final_zoom, 0.05, 3.0)  # Adjust min/max as needed
