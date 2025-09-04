extends CharacterBody2D
class_name Tank

# Movement settings
@export var move_speed : float = 300.0
@export var gravity : float = 980.0
@export var rotation_speed : float = 2.0  # How fast tank aligns to terrain

@onready var right_ray  : RayCast2D = $RayCastRight
@onready var center_ray : RayCast2D =  $RayCastCenter
@onready var left_ray  : RayCast2D = $RayCastLeft

@onready var collision_shape : CollisionShape2D = $CollisionShape2D

@export var body_sprite : Sprite2D
@export var left_wheel : Sprite2D
@export var right_wheel : Sprite2D

var rotation_divisor = 300.0
var aim_angle = -90.0
var aim_mod = 0.0

func _ready() -> void:
	if body_sprite:
		adjust_collision_bounds(body_sprite.texture)

func adjust_collision_bounds(body_texture : Texture2D):
	(collision_shape.shape as RectangleShape2D).size = body_texture.get_size()

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor() or !center_ray.is_colliding():
		velocity.y += gravity * delta
	
	# Handle input
	var direction = 0
	if Input.is_key_pressed(KEY_CTRL):
		if Input.is_action_pressed("move_left"):
			direction = -1
		elif Input.is_action_pressed("move_right"):
			direction = 1
	else:
		if Input.is_action_pressed("aim_left"):
			aim_mod = clamp(aim_mod - 1.0, -66.0, 66.0)
		elif Input.is_action_pressed("aim_right"):
			aim_mod = clamp(aim_mod + 1.0, -66.0, 66.0)
	
	# Move along the tank's forward direction (accounting for slope)
	if direction != 0:
		if !center_ray.is_colliding():
			if !right_ray.is_colliding() and direction > 0:
				rotate(TAU/rotation_divisor)
			if !left_ray.is_colliding() and direction < 0:
				rotate(-TAU/rotation_divisor)
			rotation_divisor = clamp(rotation_divisor - 10.0, 100.0, 300.0)
		else:
			rotation_divisor = 500.0
		var forward = Vector2(direction, 0).rotated(rotation)
		velocity.x = forward.x * move_speed
		velocity.y = forward.y * move_speed
		
		# Rotate wheels visually
		if left_wheel:
			left_wheel.rotation -= direction * delta * 5
		if right_wheel:
			right_wheel.rotation -= direction * delta * 5
	else:
		if !center_ray.is_colliding():
			if !right_ray.is_colliding() and left_ray.is_colliding():
				rotate(TAU/rotation_divisor)
			if !left_ray.is_colliding() and right_ray.is_colliding():
				rotate(-TAU/rotation_divisor)
			rotation_divisor = clamp(rotation_divisor - 10.0, 100.0, 300.0)
		else:
			rotation_divisor = 500.0
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
	
	# Align to terrain
	align_to_terrain(delta)
	
	# Move and slide
	move_and_slide()
	queue_redraw()

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

func get_aim_angle() -> float:
	# For aiming your weapon later
	return rotation

func _draw() -> void:
	draw_circle(Vector2(0, -10), 10.0, Color.AQUA)
	draw_line(Vector2(0, -10), Vector2(50, 0).rotated(deg_to_rad(aim_angle + aim_mod)), Color.AQUAMARINE, 10.0)
