extends Area2D
class_name Projectile

signal projectile_hit(impact_position: Vector2, impact_angle: float, target_type: String, targets: Array)

# Movement parameters
var velocity: Vector2
var _gravity: float = 980.0

# Visual trail
var trail_points: Array[Vector2] = []
var max_trail_length: int = 20

var monitor_timer = 0.05
var delta_bank = 0.0

var explosion_area : Area2D
var collision_shape : CollisionShape2D
var explosion_shape : CollisionShape2D

# Static method for getting trajectory arc (for preview)
static func get_trajectory_arc(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50) -> Array[Vector2]:
	var trajectory_points: Array[Vector2] = []
	
	# Calculate velocity components
	var velocity_x = power * cos(angle)
	var velocity_y = power * sin(angle)
	var _gravity = 980.0
	
	# Calculate impact time using raycast method
	var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, _gravity, terrain)
	
	# Generate points along the arc
	for i in range(points_count + 1):
		var t = (float(i) / float(points_count)) * impact_time
		var x = origin.x + velocity_x * t
		var y = origin.y + velocity_y * t + 0.5 * _gravity * t * t
		var point = Vector2(x, y)
		trajectory_points.append(point)
	
	return trajectory_points

# Static method for calculating impact time using raycasts
static func calculate_impact_time_static(origin: Vector2, velocity_x: float, velocity_y: float, _gravity: float, terrain: Node = null) -> float:
	if not terrain:
		# Fallback: flat ground at y=1200
		var a = 0.5 * _gravity
		var b = velocity_y
		var c = origin.y - 1200.0
		var discriminant = b * b - 4 * a * c
		if discriminant < 0:
			return 20.0
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
	
	# Use physics raycast for accurate collision detection
	var world = terrain.get_world_2d()
	if not world:
		return 20.0
	
	var space_state = world.direct_space_state
	var sample_interval = 0.1
	var max_time = 20.0
	var last_pos = origin
	
	for t in range(1, int(max_time / sample_interval)):
		var time = t * sample_interval
		var x = origin.x + velocity_x * time
		var y = origin.y + velocity_y * time + 0.5 * _gravity * time * time
		var current_pos = Vector2(x, y)
		
		# Cast ray from last position to current position
		var query = PhysicsRayQueryParameters2D.create(last_pos, current_pos)
		query.collision_mask = 1  # Adjust if terrain is on different layer
		var result = space_state.intersect_ray(query)
		
		if result:
			# Hit terrain! Calculate precise time
			var hit_distance = last_pos.distance_to(result.position)
			var segment_distance = last_pos.distance_to(current_pos)
			var time_offset = (hit_distance / segment_distance) * sample_interval
			return (t - 1) * sample_interval + time_offset
		
		last_pos = current_pos
	
	return max_time

func _init(_origin: Vector2, _angle: float, _power: float) -> void:
	monitoring = false
	# Set starting position
	global_position = _origin
	
	# Calculate initial velocity components
	velocity.x = _power * cos(_angle)
	velocity.y = _power * sin(_angle)

func _ready() -> void:
	# Set up collision shape
	collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 3.0
	collision_shape.shape = circle_shape.duplicate()
	add_child(collision_shape)
	
	explosion_area = Area2D.new()
	add_child(explosion_area)
	explosion_shape = CollisionShape2D.new()
	circle_shape.radius = 30.0
	explosion_shape.shape = circle_shape.duplicate()
	explosion_area.add_child(explosion_shape)
	
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if !monitoring:
		delta_bank += delta
		if delta_bank > monitor_timer:
			monitoring = true
	# Simple ballistic physics
	velocity.y += _gravity * delta
	global_position += velocity * delta
	
	# Add to trail
	trail_points.append(global_position)
	if trail_points.size() > max_trail_length:
		trail_points.pop_front()
	
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	var bodies = explosion_area.get_overlapping_bodies()
	# Calculate impact angle from current velocity
	var impact_angle = atan2(velocity.y, velocity.x)
	
	# Determine what we hit
	var target_type = "terrain"
	if body.name.contains("Tank"):
		target_type = "tank"
	
	# Emit hit signal
	if bodies.size() > 1:
		target_type = "multiple"
	projectile_hit.emit(global_position, impact_angle, target_type, bodies)
	
	# Clean up
	queue_free()

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
