# particle_manager.gd
extends Node2D

var particle_pool: Array[CPUParticles2D] = []
var pool_size: int = 10
var emission_duration = 0.1

var last_points = []

func _ready():
	z_index = 1000
	# Create a simple white circle texture
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	# Draw a circle
	for x in range(8):
		for y in range(8):
			var dist = Vector2(x - 4, y - 4).length()
			if dist > 3:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	# Create particle pool
	for i in range(pool_size):
		var particles = CPUParticles2D.new()
		add_child(particles)
		particles.emitting = false
		particle_pool.append(particles)
		
		# Basic setup that stays the same
		particles.texture = texture
		particles.one_shot = true
		particles.amount = 50
		particles.lifetime = 2.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 5.0
		particles.direction = Vector2(0, -1)
		particles.spread = 15.0
		particles.initial_velocity_min = 50.0
		particles.initial_velocity_max = 150.0
		particles.gravity = Vector2(0, 500)
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 1.5
		particles.color = Color.REBECCA_PURPLE
		particles.angular_velocity_min = -360.0
		particles.angular_velocity_max = 360.0
		particles.z_index = 100
func _process(delta: float) -> void:
	queue_redraw()
func launch_debris(position: Vector2, angle: float, radius: float, amount = 100.0) -> void:
	#print("Launching debris at: ", position, " angle: ", angle, " radius: ", radius)
	
	# Find available particle emitter
	var particles: CPUParticles2D = null
	for emitter in particle_pool:
		if not emitter.emitting:
			particles = emitter
			break
	if not particles:
		#print("No available particle emitter!")
		return
	
	# Set position and direction
	particles.global_position = position
	
	# Set emission direction based on impact angle (opposite direction)
	var emission_direction = Vector2(cos(angle + PI), sin(angle + PI))
	particles.direction = emission_direction
	
	# Scale particle count and spread based on radius
	particles.amount = int(amount/5.0)  # More radius = more particles
	particles.emission_sphere_radius = radius
	particles.initial_velocity_max = radius * 10
	
	# One-shot burst
	particles.emitting = false  # Reset
	particles.restart()
	particles.emitting = true
	
	#print("Particles started at: ", particles.global_position)
	
	# Auto-stop after lifetime
	var timer = Timer.new()
	timer.wait_time = emission_duration
	timer.one_shot = true
	timer.timeout.connect(func(): particles.emitting = false; timer.queue_free())
	add_child(timer)
	timer.start()

func _draw() -> void:
	if last_points.size() > 0:
		for i in last_points.size():
			var _color
			if i == 0:
				_color =  Color.BLACK
			elif i == last_points.size()/2:
				_color =  Color.RED
			elif i == last_points.size() -1:
				_color =  Color.WHITE
			else:
				_color =  Color.DIM_GRAY
			draw_circle(last_points[i], 3.0, _color)
		
