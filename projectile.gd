extends Node2D
class_name Projectile

signal projectile_hit(impact_position: Vector2, impact_angle: float, target_type: String, target: Node)

# Projectile parameters
var origin: Vector2
var launch_angle: float
var initial_velocity: float
var gravity: float = 980.0

# Trajectory calculation
var velocity_x: float
var velocity_y: float
var flight_time: float = 0.0
var impact_time: float = -1.0
var impact_position: Vector2
var impact_angle: float

# Visual
var trail_points: Array[Vector2] = []
var max_trail_length: int = 20

# Static method for getting trajectory arc
static func get_trajectory_arc(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50) -> Array[Vector2]:
	var trajectory_points: Array[Vector2] = []
	
	# Calculate velocity components
	var velocity_x = power * cos(angle)
	var velocity_y = power * sin(angle)
	var gravity = 980.0
	
	# Calculate impact time
	var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, gravity, terrain)
	
	# Generate points along the arc
	for i in range(points_count + 1):
		var t = (float(i) / float(points_count)) * impact_time
		var x = origin.x + velocity_x * t
		var y = origin.y + velocity_y * t + 0.5 * gravity * t * t
		var point = Vector2(x, y)
		
		# Check if we've hit terrain early
		if terrain:
			var terrain_height = get_terrain_height_at_x_static(point.x, terrain)
			if point.y >= terrain_height:
				# Add the impact point and stop
				trajectory_points.append(Vector2(point.x, terrain_height))
				break
		
		trajectory_points.append(point)
	
	return trajectory_points

# Static method for calculating impact time
static func calculate_impact_time_static(origin: Vector2, velocity_x: float, velocity_y: float, gravity: float, terrain: Node = null) -> float:
	if not terrain:
		# Fallback: flat ground at y=1200
		var a = 0.5 * gravity
		var b = velocity_y
		var c = origin.y - 1200.0
		
		var discriminant = b * b - 4 * a * c
		if discriminant < 0:
			return 20.0  # Default max time
		
		var t1 = (-b + sqrt(discriminant)) / (2 * a)
		var t2 = (-b - sqrt(discriminant)) / (2 * a)
		
		if t1 > 0 and t2 > 0:
			return min(t1, t2)
		elif t1 > 0:
			return t1
		elif t2 > 0:
			return t2
		else:
			return 20.0
	
	# Sample trajectory to find terrain intersection
	var sample_interval = 0.1
	var max_time = 20.0
	
	for t in range(0, int(max_time / sample_interval)):
		var time = t * sample_interval
		var x = origin.x + velocity_x * time
		var y = origin.y + velocity_y * time + 0.5 * gravity * time * time
		var test_position = Vector2(x, y)
		
		var terrain_height = get_terrain_height_at_x_static(test_position.x, terrain)
		if test_position.y >= terrain_height:
			# Refine with binary search
			var prev_time = max(0, time - sample_interval)
			return binary_search_impact_time_static(prev_time, time, origin, velocity_x, velocity_y, gravity, terrain)
	
	return max_time

# Static binary search for precise impact time
static func binary_search_impact_time_static(start_time: float, end_time: float, origin: Vector2, velocity_x: float, velocity_y: float, gravity: float, terrain: Node) -> float:
	var precision = 0.001
	
	while end_time - start_time > precision:
		var mid_time = (start_time + end_time) * 0.5
		var x = origin.x + velocity_x * mid_time
		var y = origin.y + velocity_y * mid_time + 0.5 * gravity * mid_time * mid_time
		var mid_position = Vector2(x, y)
		var terrain_height = get_terrain_height_at_x_static(mid_position.x, terrain)
		
		if mid_position.y >= terrain_height:
			end_time = mid_time
		else:
			start_time = mid_time
	
	return (start_time + end_time) * 0.5

# Static method for terrain height lookup
static func get_terrain_height_at_x_static(x_pos: float, terrain: Node) -> float:
	if not terrain or not terrain.poly.has_method("get_polygon"):
		return 1200.0
	
	var polygon = terrain.poly.polygon
	if polygon.size() < 2:
		return 1200.0
	
	for i in range(polygon.size() - 1):
		var p1 = polygon[i]
		var p2 = polygon[i + 1]
		
		if x_pos >= p1.x and x_pos <= p2.x:
			var ratio = (x_pos - p1.x) / (p2.x - p1.x)
			return lerp(p1.y, p2.y, ratio)
	
	return 1200.0

func _init(_origin: Vector2, _angle: float, _power: float) -> void:
	origin = _origin
	launch_angle = _angle
	initial_velocity = _power
	
	# Calculate initial velocity components
	velocity_x = initial_velocity * cos(launch_angle)
	velocity_y = initial_velocity * sin(launch_angle)  # Up is negative Y in Godot
	
	# Set starting position
	global_position = origin
	
func _ready() -> void:
	calculate_impact()

func calculate_impact() -> void:
	var terrain = get_terrain_node()
	if not terrain:
		# Fallback: calculate impact with flat ground at y=1200
		impact_time = calculate_flat_ground_impact(1200.0)
		impact_position = get_position_at_time(impact_time)
		impact_angle = get_velocity_angle_at_time(impact_time)
		return
	
	# Sample trajectory points to find terrain intersection
	var sample_interval = 0.1  # Check every 0.1 seconds
	var max_time = 20.0  # Maximum flight time to check
	
	for t in range(0, int(max_time / sample_interval)):
		var time = t * sample_interval
		var test_position = get_position_at_time(time)
		
		# Check if we hit the terrain
		var terrain_height = get_terrain_height_at_x(test_position.x, terrain)
		if test_position.y >= terrain_height:
			# We hit! Refine the exact impact time with binary search
			var prev_time = max(0, time - sample_interval)
			impact_time = binary_search_impact_time(prev_time, time, terrain)
			impact_position = get_position_at_time(impact_time)
			impact_angle = get_velocity_angle_at_time(impact_time)
			return
	
	# No terrain hit found, use max time
	impact_time = max_time
	impact_position = get_position_at_time(impact_time)
	impact_angle = get_velocity_angle_at_time(impact_time)

func binary_search_impact_time(start_time: float, end_time: float, terrain: Node) -> float:
	var precision = 0.001  # 1ms precision
	
	while end_time - start_time > precision:
		var mid_time = (start_time + end_time) * 0.5
		var mid_position = get_position_at_time(mid_time)
		var terrain_height = get_terrain_height_at_x(mid_position.x, terrain)
		
		if mid_position.y >= terrain_height:
			end_time = mid_time  # Hit happened before mid_time
		else:
			start_time = mid_time  # Hit happened after mid_time
	
	return (start_time + end_time) * 0.5

func get_position_at_time(t: float) -> Vector2:
	var x = origin.x + velocity_x * t
	var y = origin.y + velocity_y * t + 0.5 * gravity * t * t
	return Vector2(x, y)

func get_velocity_angle_at_time(t: float) -> float:
	var vx = velocity_x
	var vy = velocity_y + gravity * t
	return atan2(vy, vx)

func calculate_flat_ground_impact(ground_y: float) -> float:
	var a = 0.5 * gravity
	var b = velocity_y
	var c = origin.y - ground_y
	
	var discriminant = b * b - 4 * a * c
	if discriminant < 0:
		return 0.0
	
	var t1 = (-b + sqrt(discriminant)) / (2 * a)
	var t2 = (-b - sqrt(discriminant)) / (2 * a)
	
	# Return the positive time that's greater than 0
	if t1 > 0 and t2 > 0:
		return min(t1, t2)
	elif t1 > 0:
		return t1
	elif t2 > 0:
		return t2
	else:
		return 0.0

func get_terrain_node() -> Node:
	# Find the terrain node in the scene
	var parent = get_parent()
	if parent:
		return parent.get_node_or_null("Terrain")
	return null

func get_terrain_height_at_x(x_pos: float, terrain: Node) -> float:
	if not terrain or not terrain.poly.has_method("get_polygon"):
		return 1200.0  # Fallback ground level
	
	var polygon = terrain.poly.polygon
	if polygon.size() < 2:
		return 1200.0
	
	# Find the two points that bracket our x position
	for i in range(polygon.size() - 1):
		var p1 = polygon[i]
		var p2 = polygon[i + 1]
		
		if x_pos >= p1.x and x_pos <= p2.x:
			# Interpolate height between these two points
			var ratio = (x_pos - p1.x) / (p2.x - p1.x)
			return lerp(p1.y, p2.y, ratio)
	
	# If outside terrain bounds, return a default
	return 1200.0

func _process(delta: float) -> void:
	if impact_time < 0:
		return  # Impact not calculated yet
	
	flight_time += delta
	
	if flight_time >= impact_time:
		# Impact!
		global_position = impact_position
		emit_impact_signal()
		queue_free()
	else:
		# Update position along trajectory
		global_position = get_position_at_time(flight_time)
		
		# Add to trail
		trail_points.append(global_position)
		if trail_points.size() > max_trail_length:
			trail_points.pop_front()
	
	queue_redraw()

func emit_impact_signal() -> void:
	# Check what we hit
	var target_type = "terrain"
	var target: Node = get_terrain_node()
	
	projectile_hit.emit(impact_position, impact_angle, target_type, target)

func _draw() -> void:
	# Draw projectile
	draw_circle(Vector2.ZERO, 5.0, Color.YELLOW)
	
	# Draw trail
	if trail_points.size() > 1:
		for i in range(trail_points.size() - 1):
			var alpha = float(i) / float(trail_points.size())
			var color = Color.ORANGE
			color.a = alpha * 0.5
			var local_start = to_local(trail_points[i])
			var local_end = to_local(trail_points[i + 1])
			draw_line(local_start, local_end, color, 2.0)
