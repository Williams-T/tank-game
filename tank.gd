extends CharacterBody2D
class_name Tank

# Movement settings
@export var move_speed : float = 300.0
@export var gravity : float = 980.0
@export var rotation_speed : float = 3.0  # How fast tank aligns to terrain

@onready var right_ray  : RayCast2D = $RayCastRight
@onready var center_ray : RayCast2D =  $RayCastCenter
@onready var left_ray  : RayCast2D = $RayCastLeft

@onready var collision_shape : CollisionShape2D = $CollisionShape2D
@onready var turret_shape : CollisionShape2D = $turret_shape
@export var body_sprite : Sprite2D
@export var left_wheel : Sprite2D
@export var right_wheel : Sprite2D

#var rotation_divisor = 300.0
var aim_angle = -90.0
var aim_mod = 0.0

var power = 500.0

#var projectile_counter = 0
var turret_origin_offset = Vector2(0, -10)
var turret_length = Vector2(50,0)

var cached_trajectory: Array[Vector2] = []
var last_aim_angle: float = -999.0
var last_position: Vector2 = Vector2(-999, -999)
var last_power_level : float = -999.0
var show_trajectory: bool = false
var perma_show_trajectory : bool = true

var is_grounded: bool = false
var ground_check_distance: float = 30.0  # Will be set in _ready
var stick_angle_threshold: float = 190.0  # Degrees from upright
var ground_normal: Vector2 = Vector2.UP  # Track the current ground normal

# Game State Variables:
var is_active = false
var fired_projectile = false

func _ready() -> void:
	if body_sprite:
		adjust_collision_bounds(body_sprite.texture)
		
		# Set ground check distance to 1/4 of tank height
		ground_check_distance = body_sprite.texture.get_height() * 0.25
	else:
		# Fallback if no sprite
		var rect_shape = collision_shape.shape as RectangleShape2D
		if rect_shape:
			ground_check_distance = rect_shape.size.y * 0.25
	
	# Configure center ray for local "down" checking
	center_ray.target_position = Vector2(0, ground_check_distance)
	center_ray.enabled = true
	left_ray.target_position = Vector2(0, ground_check_distance).rotated(0.5)
	left_ray.enabled = true
	right_ray.target_position = Vector2(0, ground_check_distance).rotated(-0.5)
	right_ray.enabled = true
	GameStateManager.declare_player(self)

func check_grounded_state(move_dir: int = 0, extend_rays: bool = false) -> void:
	if extend_rays:
		adjust_rays(300.0)
	var center_hit = center_ray.is_colliding()
	var left_hit = left_ray.is_colliding()
	var right_hit = right_ray.is_colliding()
	
	# We're grounded if ANY ray hits
	if center_hit or left_hit or right_hit:
		# Check if we're not too upside down
		var world_up = Vector2.UP
		var tank_up = Vector2.UP.rotated(rotation)
		var angle_from_upright = rad_to_deg(world_up.angle_to(tank_up))
		
		if abs(angle_from_upright) < stick_angle_threshold:
			is_grounded = true
			
			# Smart normal selection based on movement and ray hits
			if move_dir < 0 and left_hit:
				# Moving left, prioritize left ray
				ground_normal = left_ray.get_collision_normal()
			elif move_dir > 0 and right_hit:
				# Moving right, prioritize right ray
				ground_normal = right_ray.get_collision_normal()
			elif center_hit:
				# Not moving or preferred ray not hitting, use center
				ground_normal = center_ray.get_collision_normal()
			elif left_hit and right_hit:
				# No center, both sides hitting (valley) - average them
				ground_normal = (left_ray.get_collision_normal() + right_ray.get_collision_normal()).normalized()
			elif left_hit:
				ground_normal = left_ray.get_collision_normal()
			else:  # right_hit
				ground_normal = right_ray.get_collision_normal()
		else:
			is_grounded = false
			ground_normal = Vector2.UP
	else:
		if is_on_floor():
			is_grounded = true
			ground_normal = Vector2.UP
		else:
			is_grounded = false
			ground_normal = Vector2.UP
	if extend_rays:
		adjust_rays()

func adjust_rays(multiplier : float = 1.0):
	center_ray.target_position = Vector2(0, ground_check_distance*multiplier)
	left_ray.target_position = Vector2(0, ground_check_distance*multiplier).rotated(0.5)
	right_ray.target_position = Vector2(0, ground_check_distance*multiplier).rotated(-0.5)

func adjust_collision_bounds(body_texture : Texture2D):
	(collision_shape.shape as RectangleShape2D).size = body_texture.get_size()

func _physics_process(delta: float):
	# Get movement input first
	var direction = 0
	if Input.is_key_pressed(KEY_CTRL) and is_active:
		if Input.is_action_pressed("move_left"):
			direction = -1
		elif Input.is_action_pressed("move_right"):
			direction = 1
	var nearly_stopped = velocity.length() < 20.0
	check_grounded_state(direction, nearly_stopped)
	
	# Handle aiming/power controls (works whether grounded or airborne)
	if not Input.is_key_pressed(KEY_CTRL) and is_active:
		if Input.is_action_pressed("aim_left"):
			if aim_mod != -66.0:
				aim_mod = clamp(aim_mod - 1.0, -66.0, 66.0)
				update_trajectory_cache()
			else:
				rotation -= delta * PI / 1.5
		elif Input.is_action_pressed("aim_right"):
			if aim_mod != 66.0:
				aim_mod = clamp(aim_mod + 1.0, -66.0, 66.0)
				update_trajectory_cache()
			else:
				rotation += delta * PI / 1.5
	if is_active:
		if Input.is_action_pressed("power_up"):
			power = clamp(power + 500.0*delta, 100.0, 1000.0)
			update_trajectory_cache()
		elif Input.is_action_pressed("power_down"):
			power = clamp(power - 500.0*delta, 100.0, 1000.0)
			update_trajectory_cache()
		
		# Show trajectory while aiming
		show_trajectory = Input.is_action_pressed("aim_left") or Input.is_action_pressed("aim_right") or Input.is_action_pressed("power_up") or Input.is_action_pressed("power_down")
		
		# Update trajectory if position changed significantly
		if global_position.distance_to(last_position) > 10.0:
			update_trajectory_cache()
		
		# Handle firing
		if Input.is_action_just_pressed("fire") and is_active and !fired_projectile:
			var turret_tip = global_position + turret_origin_offset.rotated(global_rotation) + Vector2(50, 0).rotated(global_rotation + deg_to_rad(aim_angle + aim_mod))
			var firing_angle = global_rotation + deg_to_rad(aim_angle + aim_mod)
			var p = Projectile.new(turret_tip, firing_angle, power)
			p.projectile_hit.connect(_on_projectile_hit)
			get_parent().add_child(p)
			await get_tree().process_frame
			fired_projectile = true
	
	# Movement and physics based on grounded state
	if is_grounded:
		# GROUNDED: Can move and align to terrain
		if direction != 0:
			# Move along the terrain surface (perpendicular to normal)
			var move_direction = ground_normal.rotated(PI/2 * direction)
			velocity = move_direction * move_speed
			
			# Rotate wheels visually
			if left_wheel:
				left_wheel.rotation -= direction * delta * 5
			if right_wheel:
				right_wheel.rotation -= direction * delta * 5
		else:
			# Slow to a stop when not moving
			velocity = velocity.move_toward(Vector2.ZERO, move_speed * delta * 3)
		
		# Align tank to terrain normal
		var target_rotation = ground_normal.angle() + PI/2
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta * 2)
		
		# Snap to ground to prevent floating
		if center_ray.is_colliding():
			var hit_point = center_ray.get_collision_point()
			var desired_pos = hit_point + ground_normal * (ground_check_distance * 0.5)
			global_position = global_position.lerp(desired_pos, delta * 30)
		
	else:
		# AIRBORNE: Only gravity affects the tank
		velocity.y += gravity * delta
		# Maintain some X velocity decay for more natural arcs
		if direction != 0:
			velocity.x += 1000.0 * delta * direction
		velocity.x *= 0.99
	# Apply movement
	move_and_slide()
	turret_shape.rotation = turret_origin_offset.angle_to(turret_origin_offset + turret_length.rotated(deg_to_rad(aim_angle + aim_mod)))
	turret_shape.position = turret_origin_offset.lerp(turret_origin_offset + turret_length.rotated(deg_to_rad(aim_angle + aim_mod)), 0.5)
	queue_redraw()

func update_trajectory_cache():
	if !show_trajectory or !perma_show_trajectory:
		return
	var current_aim = aim_angle + aim_mod
	
	# Only recalculate if aim or position changed significantly
	if abs(current_aim - last_aim_angle) > 0.5 or global_position.distance_to(last_position) > 5.0 \
	or abs(power - last_power_level) > 0.5:
		# Calculate turret tip in local space (exactly like drawing)
		var local_turret_tip = turret_origin_offset + turret_length.rotated(deg_to_rad(current_aim))
		# Transform to world space
		var world_turret_tip = global_position + local_turret_tip.rotated(global_rotation)
		# Firing angle is tank rotation + aim
		var firing_angle = global_rotation + deg_to_rad(current_aim)
		
		var terrain = get_parent().get_node_or_null("Terrain")
		cached_trajectory = Projectile.get_trajectory_arc(world_turret_tip, firing_angle, power, terrain, 15)
		
		last_aim_angle = current_aim
		last_position = global_position
		last_power_level = power

func align_to_terrain(delta: float):
	var left_hit = left_ray.is_colliding()
	var center_hit = center_ray.is_colliding()
	var right_hit = right_ray.is_colliding()
	
	# Get hit points for grounded rays
	var left_point = left_ray.get_collision_point() if left_hit else Vector2.ZERO
	var right_point = right_ray.get_collision_point() if right_hit else Vector2.ZERO
	
	# Case 1: Both wheels on ground - align to slope
	if left_hit and right_hit:
		var angle = (right_point - left_point).angle()
		rotation = lerp_angle(rotation, angle, rotation_speed * delta)
	
	# Case 2: Only left wheel grounded - rotate clockwise
	elif left_hit and not right_hit and not center_hit:
		rotation += rotation_speed * delta
	
	# Case 3: Only right wheel grounded - rotate counter-clockwise
	elif right_hit and not left_hit and not center_hit:
		rotation -= rotation_speed * delta
	
	# Case 4: Center and one wheel (on hill peak) - stay put
	elif center_hit and (left_hit or right_hit):
		# Tank is balanced on peak, don't rotate
		pass
	
	# Optional: Adjust vertical position to stay on ground
	if left_hit or right_hit or center_hit:
		var lowest_point = INF
		if left_hit:
			lowest_point = min(lowest_point, left_ray.get_collision_point().y - global_position.y)
		if right_hit:
			lowest_point = min(lowest_point, right_ray.get_collision_point().y - global_position.y)
		if center_hit:
			lowest_point = min(lowest_point, center_ray.get_collision_point().y - global_position.y)
		
		# Snap to ground if very close
		if lowest_point < 5 and lowest_point > -5:
			position.y += lowest_point

func _on_projectile_hit(impact_pos: Vector2, impact_angle: float, target_type: String, targets: Array):
	print("Hit %s at %s with angle %s" % [target_type, impact_pos, rad_to_deg(impact_angle)])
	if targets.size() > 0:
		if target_type == "terrain":
			targets[0].get_parent().get_parent().call_deferred('create_crater', impact_pos, 50.0 + randf_range(-10, 10))
		elif target_type == "tank":
			targets[0].get_hit(impact_pos.angle_to_point(targets[0].position))
		else:
			for target in targets:
				if target is StaticBody2D: # Terrain
					if target.get_parent().get_parent().has_method("create_crater"):
						target.get_parent().get_parent().call_deferred('create_crater', impact_pos, 50.0 + randf_range(-10, 10))
				elif target is CharacterBody2D: # Tank
					target.get_hit(impact_pos.angle_to_point(target.position))
	GameStateManager.end_turn(self)

#func get_hit(impact_angle: float, strength_multiplier: float = 1.0) -> void:
	#var base_knockback_force = 800.0  # Base knockback strength
	#var knockback_force = base_knockback_force * strength_multiplier
	#
	#var launch_angle: float
	#
	#if is_grounded:
		## Grounded: reflect the impact angle horizontally (bounce off ground)
		## This simulates the tank bouncing off the terrain
		#launch_angle = -impact_angle
		#
		## Ensure we're launching upward for dramatic effect
		#if sin(launch_angle) > 0:  # If reflected angle still points downward
			#launch_angle = PI - launch_angle  # Flip to point upward
			#
	#else:
		## Airborne: continue in the direction of impact
		#launch_angle = impact_angle
	#
	## Apply knockback velocity
	#var knockback_velocity = Vector2(cos(launch_angle), sin(launch_angle)) * knockback_force
	#velocity += knockback_velocity
	#
	## Force tank to become airborne for dramatic knockback effect
	#is_grounded = false
	#
	#print("Tank hit! Launch angle: %s degrees, Force: %s" % [rad_to_deg(launch_angle), knockback_force])

func get_hit(impact_angle: float, strength_multiplier: float = 1.0) -> void:
	var base_knockback_force = 800.0
	var knockback_force = base_knockback_force * strength_multiplier
	
	# Get the impact direction as a velocity vector
	var impact_direction = Vector2(cos(impact_angle), sin(impact_angle))
	#var distance = abs()
	
	var knockback_velocity: Vector2
	
	if is_grounded:
		# Grounded: horizontal reflection (flip Y component, keep X)
		# This simulates bouncing off the ground
		knockback_velocity = Vector2(impact_direction.x, -abs(impact_direction.y)) * knockback_force
	else:
		# Airborne: continue in the impact direction
		knockback_velocity = impact_direction * knockback_force
	
	# Apply the knockback
	velocity += knockback_velocity
	is_grounded = false
	
	print("Tank hit! Knockback: %s, Force: %s" % [knockback_velocity, knockback_force])

func _draw() -> void:
	if !body_sprite:
		draw_rect(collision_shape.shape.get_rect(), Color.CADET_BLUE)
	draw_circle(turret_origin_offset, 10.0, Color.AQUA)
	draw_line(turret_origin_offset, turret_origin_offset + turret_length.rotated(deg_to_rad(aim_angle + aim_mod)), Color.AQUAMARINE, 10.0)
	# draw power gauge over turret barrel
	var power_offset = power / 1000.0
	draw_line(turret_origin_offset, turret_origin_offset + Vector2((turret_length.x * 0.9) * power_offset, 0).rotated(deg_to_rad(aim_angle + aim_mod)), Color.CORAL, 2.0)
	
	# Draw cached trajectory (only while aiming)
	# turned off for now, uncomment the following if statement and comment the other one to switch.
	if (show_trajectory and cached_trajectory.size() > 1 and is_active): 
	#if perma_show_trajectory:
		for i in range(cached_trajectory.size() - 1):
			if i % 2 == 0:  # Every other point for performance
				var local_start = to_local(cached_trajectory[i])
				var local_end = to_local(cached_trajectory[i + 1])
				draw_line(local_start, local_end, Color.WHITE, 2.0)
