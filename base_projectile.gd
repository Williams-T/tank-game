extends Area2D
class_name BaseProjectile

signal projectile_hit(impact_position: Vector2, impact_angle: float, target_type: String, targets: Array)

# Config and state
var config: ProjectileConfig
var fired: bool = false

# Movement parameters (config-driven)
var velocity: Vector2
var _gravity: float

# Visual trail (config-driven)
var trail_points: Array[Vector2] = []
var max_trail_length: int

# Technical parameters
var monitor_timer = 0.05
var delta_bank = 0.0
var lifetime = 5.0

# Collision areas
var explosion_area: Area2D
var collision_shape: CollisionShape2D
var explosion_shape: CollisionShape2D

var bounces_remaining: int
var bounce_cooldown: float = 0.0
var bounce_cooldown_time: float = 0.01  # 0.1 seconds immunity after bounce

func _init(projectile_config: ProjectileConfig = null) -> void:
	monitoring = false
	
	# Use provided config or create default
	if projectile_config:
		config = projectile_config
	else:
		config = create_default_config()
	
	# Extract config values
	_gravity = 980.0
	max_trail_length = 20  # Could add to visual component later
	bounces_remaining = config.movement.bounce_count
	
	# Start unfired
	fired = false

func create_default_config() -> ProjectileConfig:
	var default_config = ProjectileConfig.new()
	default_config.config_name = "Standard Shell"
	
	# Default movement (matches current behavior)
	default_config.movement = MovementComponent.new()
	default_config.movement.trajectory_type = MovementComponent.TrajectoryType.ARC
	default_config.movement.physics_mode = MovementComponent.PhysicsMode.NORMAL_GRAVITY
	default_config.movement.collision_response = MovementComponent.CollisionResponse.STOP
	
	# Default trigger
	default_config.trigger = TriggerComponent.new()
	default_config.trigger.activation_type = TriggerComponent.ActivationType.CONTACT
	
	# Default effect
	default_config.effect = EffectComponent.new()
	default_config.effect.effect_type = EffectComponent.EffectType.DAMAGE_CRATER
	default_config.effect.crater_size = 50.0
	
	# Default visual
	default_config.visual = VisualComponent.new()
	default_config.visual.trail_color = Color.ORANGE
	
	# Default lifetime
	default_config.lifetime = LifetimeComponent.new()
	default_config.lifetime.duration_type = LifetimeComponent.DurationType.INSTANT
	
	return default_config

func fire(origin: Vector2, angle: float, power: float) -> void:
	# Set starting position
	global_position = origin
	
	# Calculate initial velocity based on config
	match config.movement.trajectory_type:
		MovementComponent.TrajectoryType.ARC:
			velocity.x = power * cos(angle)
			velocity.y = power * sin(angle)
		MovementComponent.TrajectoryType.STRAIGHT:
			# Straight shots are faster and more direct
			var straight_power = power * 2.0  # Double speed for laser-like feel
			velocity = Vector2(cos(angle), sin(angle)) * straight_power
	
	# Activate projectile
	fired = true

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
	
	# Only declare to GameStateManager when fired
	if fired:
		GameStateManager.declare_projectile(self)

func _process(delta: float) -> void:
	if not fired:
		return
		
	if lifetime > delta_bank and position.y > -2000.0:
		delta_bank += delta
		if !monitoring and delta_bank > monitor_timer:
			monitoring = true
	else:
		GameStateManager.remove_projectile(self)
		projectile_hit.emit(global_position, 0.0, "", [])
		queue_free()
	if bounce_cooldown > 0:
		bounce_cooldown -= delta
		monitoring = false  # Disable collision detection during cooldown
	else:
		monitoring = true
	# Apply physics based on config
	match config.movement.physics_mode:
		MovementComponent.PhysicsMode.NORMAL_GRAVITY:
			velocity.y += _gravity * delta
		MovementComponent.PhysicsMode.REVERSE_GRAVITY:
			velocity.y -= _gravity * delta
		# NO_GRAVITY does nothing
	
	global_position += velocity * delta
	
	# Add to trail
	trail_points.append(global_position)
	if trail_points.size() > max_trail_length:
		trail_points.pop_front()
	
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	# Handle collision based on config
	match config.movement.collision_response:
		MovementComponent.CollisionResponse.STOP:
			_handle_impact(body)
		MovementComponent.CollisionResponse.BOUNCE:
			_handle_bounce(body)
		MovementComponent.CollisionResponse.PASS_THROUGH:
			_handle_pass_through(body)

func _handle_impact(body: Node) -> void:
	var bodies = explosion_area.get_overlapping_bodies()
	var impact_angle = atan2(velocity.y, velocity.x)
	
	var target_type = "terrain"
	if body.name.contains("Tank"):
		target_type = "tank"
	if bodies.size() > 1:
		target_type = "multiple"
	
	projectile_hit.emit(global_position, impact_angle, target_type, bodies)
	GameStateManager.remove_projectile(self)
	queue_free()

func _handle_bounce(body: Node) -> void:
	# Get collision normal for realistic bounce
	var collision_normal = Vector2.UP  # default upward
	
	# Try to get actual surface normal
	var world = get_world_2d()
	if world:
		var space_state = world.direct_space_state
		# Cast backwards along velocity to find collision point
		var ray_start = global_position - velocity.normalized() * 20
		var ray_end = global_position
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		if result:
			collision_normal = result.normal
	
	# Reflect velocity using Godot's built-in bounce
	velocity = velocity.bounce(collision_normal)
	
	# Add some energy loss for realism
	velocity *= 0.85  # Lose 15% speed per bounce
	
	# Decrement bounce count
	bounces_remaining -= 1
	bounce_cooldown = bounce_cooldown_time
	print("Bounced! Remaining bounces: ", bounces_remaining)
	
	# If no bounces left, explode normally
	if bounces_remaining <= 0:
		_handle_impact(body)
	else:
		# Move slightly away from collision to prevent immediate re-collision
		global_position += collision_normal * 5.0

func _handle_pass_through(body: Node) -> void:
	# Implement pass-through logic here
	pass

func _draw() -> void:
	if not fired:
		return
		
	# Draw projectile
	draw_circle(Vector2.ZERO, 5.0, Color.YELLOW)
	
	# Draw trail based on config
	if trail_points.size() > 1:
		for i in range(trail_points.size() - 1):
			var alpha = float(i) / float(trail_points.size())
			var color = config.visual.trail_color
			color.a = alpha * 0.5
			var local_start = to_local(trail_points[i])
			var local_end = to_local(trail_points[i + 1])
			draw_line(local_start, local_end, color, 2.0)

# Static method for trajectory preview (unchanged)
#static func get_trajectory_arc(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50) -> Array[Vector2]:
	#var trajectory_points: Array[Vector2] = []
	#
	#var velocity_x = power * cos(angle)
	#var velocity_y = power * sin(angle)
	#var _grav = 980.0
	#
	#var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, _grav, terrain)
	#
	#for i in range(points_count + 1):
		#var t = (float(i) / float(points_count)) * impact_time
		#var x = origin.x + velocity_x * t
		#var y = origin.y + velocity_y * t + 0.5 * _grav * t * t
		#var point = Vector2(x, y)
		#trajectory_points.append(point)
	#
	#return trajectory_points

#static func get_trajectory_arc(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50, projectile_config: ProjectileConfig = null) -> Array[Vector2]:
	#var trajectory_points: Array[Vector2] = []
	#
	## Handle different trajectory types
	#if projectile_config and projectile_config.movement.trajectory_type == MovementComponent.TrajectoryType.STRAIGHT:
		#return get_straight_trajectory(origin, angle, power * 2.0, terrain, points_count, projectile_config)
	#else:
		## Existing arc calculation
		#var velocity_x = power * cos(angle)
		#var velocity_y = power * sin(angle)
		#var _grav = 980.0
		#
		#var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, _grav, terrain)
		#
		#for i in range(points_count + 1):
			#var t = (float(i) / float(points_count)) * impact_time
			#var x = origin.x + velocity_x * t
			#var y = origin.y + velocity_y * t + 0.5 * _grav * t * t
			#trajectory_points.append(Vector2(x, y))
		#
		#return trajectory_points

static func get_trajectory_arc(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50, projectile_config: ProjectileConfig = null) -> Array[Vector2]:
	# Handle bouncing projectiles specially
	if projectile_config and projectile_config.movement.collision_response == MovementComponent.CollisionResponse.BOUNCE:
		return get_bouncing_trajectory(origin, angle, power, terrain, points_count, projectile_config)
	elif projectile_config and projectile_config.movement.trajectory_type == MovementComponent.TrajectoryType.STRAIGHT:
		return get_straight_trajectory(origin, angle, power, terrain, points_count, projectile_config)
	else:
		# Existing arc calculation (unchanged)
		var trajectory_points: Array[Vector2] = []
		var velocity_x = power * cos(angle)
		var velocity_y = power * sin(angle)
		var _grav = 980.0
		
		var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, _grav, terrain)
		
		for i in range(points_count + 1):
			var t = (float(i) / float(points_count)) * impact_time
			var x = origin.x + velocity_x * t
			var y = origin.y + velocity_y * t + 0.5 * _grav * t * t
			trajectory_points.append(Vector2(x, y))
		
		return trajectory_points

static func get_bouncing_trajectory(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50, projectile_config: ProjectileConfig = null) -> Array[Vector2]:
	var all_points: Array[Vector2] = []
	
	var velocity_x = power * cos(angle)
	var velocity_y = power * sin(angle)
	var _grav = 980.0
	
	# Apply trajectory type
	if projectile_config.movement.trajectory_type == MovementComponent.TrajectoryType.STRAIGHT:
		velocity_x *= 2.0
		velocity_y *= 2.0
	
	var impact_time = calculate_impact_time_static(origin, velocity_x, velocity_y, _grav, terrain)
	
	# Generate points for initial trajectory (use most of point budget)
	var main_points = int(points_count * 0.8)  # 80% of points for main arc
	for i in range(main_points):
		var t = (float(i) / float(main_points - 1)) * impact_time
		var x = origin.x + velocity_x * t
		var y = origin.y + velocity_y * t + 0.5 * _grav * t * t
		all_points.append(Vector2(x, y))
	
	var world = terrain.get_world_2d() if terrain else null
	var space_state = world.direct_space_state if world and terrain else null
	
	if space_state:
		# Walk backwards from calculated impact to find exact circle collision
		var collision_radius = 3.0
		var search_steps = 20
		var collision_pos = all_points[-1]
		var collision_normal = Vector2.UP
		
		# Find exact collision position
		for step in range(search_steps):
			var t = impact_time - (float(step) / float(search_steps)) * impact_time * 0.1
			var test_pos = Vector2(
				origin.x + velocity_x * t,
				origin.y + velocity_y * t + 0.5 * _grav * t * t
			)
			
			var query = PhysicsShapeQueryParameters2D.new()
			query.transform = Transform2D(0, test_pos)
			query.collision_mask = 1
			var shape = CircleShape2D.new()
			shape.radius = collision_radius
			query.shape = shape
			
			var result = space_state.intersect_shape(query)
			if result.size() > 0:
				collision_pos = test_pos
				
				# Get collision normal - cast FROM the collision point outward to find surface
				var impact_velocity = Vector2(velocity_x, velocity_y + _grav * t)
				
				# Cast multiple rays to find the best surface normal
				var best_normal = Vector2.UP
				var normal_found = false
				
				# Try rays in different directions to find surface
				for angle_offset in [-45, -30, -15, 0, 15, 30, 45]:
					var ray_angle = impact_velocity.angle() + deg_to_rad(180 + angle_offset)
					var ray_direction = Vector2(cos(ray_angle), sin(ray_angle))
					var ray_start = test_pos
					var ray_end = test_pos + ray_direction * 30
					
					var ray_query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
					ray_query.collision_mask = 1
					var ray_result = space_state.intersect_ray(ray_query)
					if ray_result:
						best_normal = ray_result.normal
						normal_found = true
						break
				
				collision_normal = best_normal
				break
		
		# Update last point to exact collision position
		all_points[-1] = collision_pos
		
		var t_collision = impact_time
		var impact_velocity = Vector2(velocity_x, velocity_y + _grav * t_collision)
		var bounce_velocity = impact_velocity.bounce(collision_normal) * 0.85
		var bounce_start = collision_pos + collision_normal * 5.0
		
		print("Impact velocity: ", impact_velocity)
		print("Collision normal: ", collision_normal) 
		print("Bounce velocity: ", bounce_velocity)
		
		var bounce_points = points_count - main_points
		var bounce_distance = 200.0
		
		for i in range(bounce_points):
			var t = float(i + 1) / float(bounce_points)
			var indicator_pos = bounce_start + bounce_velocity.normalized() * bounce_distance * t
			all_points.append(indicator_pos)
	return all_points

static func get_straight_trajectory(origin: Vector2, angle: float, power: float, terrain: Node = null, points_count: int = 50, projectile_config: ProjectileConfig = null) -> Array[Vector2]:
	var trajectory_points: Array[Vector2] = []
	var velocity = Vector2(cos(angle), sin(angle)) * power
	var _grav = 980.0
	
	# Check if gravity applies
	var applies_gravity = projectile_config == null or projectile_config.movement.physics_mode != MovementComponent.PhysicsMode.NO_GRAVITY
	
	if applies_gravity:
		# Still use physics for straight shots with gravity
		var impact_time = calculate_impact_time_static(origin, velocity.x, velocity.y, _grav, terrain)
		for i in range(points_count + 1):
			var t = (float(i) / float(points_count)) * impact_time
			var x = origin.x + velocity.x * t
			var y = origin.y + velocity.y * t + 0.5 * _grav * t * t
			trajectory_points.append(Vector2(x, y))
	else:
		# Pure straight line - no gravity
		var max_distance = 2000.0  # Max range for straight shots
		for i in range(points_count + 1):
			var t = float(i) / float(points_count)
			var point = origin + velocity.normalized() * (max_distance * t)
			trajectory_points.append(point)
			
			# Check for terrain collision
			if terrain and i > 0:
				var world = terrain.get_world_2d()
				if world:
					var space_state = world.direct_space_state
					var query = PhysicsRayQueryParameters2D.create(trajectory_points[i-1], point)
					query.collision_mask = 1
					var result = space_state.intersect_ray(query)
					if result:
						trajectory_points[i] = result.position
						break
	
	return trajectory_points

static func calculate_impact_time_static(origin: Vector2, velocity_x: float, velocity_y: float, _grav: float, terrain: Node = null) -> float:
	# [Keep existing implementation]
	if not terrain:
		var a = 0.5 * _grav
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
		var y = origin.y + velocity_y * time + 0.5 * _grav * time * time
		var current_pos = Vector2(x, y)
		
		var query = PhysicsRayQueryParameters2D.create(last_pos, current_pos)
		query.collision_mask = 1
		var result = space_state.intersect_ray(query)
		
		if result:
			var hit_distance = last_pos.distance_to(result.position)
			var segment_distance = last_pos.distance_to(current_pos)
			var time_offset = (hit_distance / segment_distance) * sample_interval
			return (t - 1) * sample_interval + time_offset
		
		last_pos = current_pos
	
	return max_time
