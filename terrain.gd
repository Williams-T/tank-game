extends Node2D
class_name Terrain

var terrain_scene = preload("res://terrain.tscn")

var initial_poly = null
var initial_type = null
@onready var poly : Polygon2D = $Polygon2D
@onready var body : StaticBody2D = $Polygon2D/StaticBody2D
@onready var body_coll : CollisionPolygon2D = $Polygon2D/StaticBody2D/CollisionPolygon2D
@export var noise1 : FastNoiseLite = FastNoiseLite.new()
@export var noise2 : FastNoiseLite = FastNoiseLite.new()

@export var crater_base_radius: float = 80.0 #
@export var crater_randomness: float = 0.3   # I haven't plugged these in yet
@export var crater_points: int = 24          #

var angle_limit = 270.0

var base_ground_level = 1200.0
var slope_range = 100.0
var vertex_gap = 30.0
var max_vertices = 1000.0

var child_terrains : Array[Terrain] = []
var parent_terrain : Terrain

var particle_emitters = [
	CPUParticles2D.new(), 
	CPUParticles2D.new(), 
	CPUParticles2D.new(), 
	CPUParticles2D.new(), 
	CPUParticles2D.new(), 
]
func _init(_polygon : PackedVector2Array = [], _type = -1) -> void:
	if _polygon.size()> 0:
		initial_poly = _polygon.duplicate()
	if _type != -1:
		initial_type = _type
	
func _ready() -> void:
	if !poly:
		await get_tree().process_frame
	if !initial_poly:
		noise1.seed = randi()
		noise2.seed = randi()
		
		var points : PackedVector2Array = []
		points.append(Vector2(vertex_gap * -300, base_ground_level * 4))
		for i in range(vertex_gap * -300, vertex_gap * 300, vertex_gap): # generate base terrain
			points.append(Vector2(i, int(base_ground_level + (slope_range * (noise1.get_noise_1d(i)+noise2.get_noise_1d(i))))))
		var neighbors = []
		for ii in points.size(): # make terrain less jaggy
			if ii != 0 and ii != points.size() - 1:
				neighbors = [int(points[ii-1].y), int(points[ii+1].y)]
				points[ii] = Vector2(points[ii].x, neighbors[0]).lerp(Vector2(points[ii].x, neighbors[1]), 0.5)
		points.append(Vector2(vertex_gap * 300, base_ground_level * 4))
		poly.polygon = points
		body_coll.polygon = points
	else:
		poly.polygon = initial_poly
		body_coll.polygon = initial_poly


func create_crater(center: Vector2, angle : float, radius: float, shape: String = "circle"):
	var crater_shape
	match shape:
		"circle":
			# Create crater as a circle polygon
			crater_shape = create_circle_polygon(center, radius, 32)
		#"capsule": #TODO: Implement other shapes
			#crater_shape = create_capsule_polygon(center, radius, 32)
	if !poly:
		for child in child_terrains:
			var child_terrain : Terrain = child
			child_terrain.create_crater(center, angle, radius, shape)
	var current_polygon = poly.polygon.duplicate()
	# Subtract crater from terrain using Godot's geometry functions
	var result_polygons = Geometry2D.clip_polygons(current_polygon, crater_shape)
	var hole_polygons = Geometry2D.intersect_polygons(current_polygon, crater_shape)
	var orphan_polygons = []
	for result in result_polygons:
		if Geometry2D.is_polygon_clockwise(result):
			hole_polygons.append(result)
			result_polygons.erase(result)
		elif get_polygon_area(result) < 10.0:
			orphan_polygons.append(result)
			result_polygons.erase(result)
	if result_polygons.size() > 0:
		if result_polygons.size() == 1:
			poly.set_deferred("polygon", result_polygons[0])
			body_coll.set_deferred("polygon", result_polygons[0])
		else:
			poly.queue_free()
			body_coll.queue_free()
			for polygon in result_polygons:
				var new_terrain : Terrain = terrain_scene.instantiate()
				new_terrain.parent_terrain = self
				new_terrain.initial_poly = polygon
				add_child(new_terrain)
				child_terrains.append(new_terrain)
	if hole_polygons.size() > 0:
		# launch debris
		var total_area = 0.0
		var new_poly = []
		for result in hole_polygons:
			total_area += get_polygon_area(result)
		for i in hole_polygons[0]:
			if result_polygons[0].has(i):
				new_poly.append(i)
		var last = new_poly[-1]
		if new_poly[-2].distance_to(new_poly[-1]) > vertex_gap:
			new_poly.erase(last)
			new_poly.insert(0, last)
		print(new_poly)
		ParticleManager.last_points = new_poly
		angle = new_poly[0].angle_to(new_poly[-1])+(PI/2)
		launch_debris(center, angle, radius, total_area * 3.0)
	if orphan_polygons.size() > 0:
		# drop chunks
		pass
		# Use the largest resulting polygon (in case crater splits terrain)
		#var largest_polygon = result_polygons[0]
		#for polygon in result_polygons:
			#if polygon.size() > largest_polygon.size():
				#largest_polygon = polygon
		#
		#poly.polygon = largest_polygon
		#body_coll.polygon = largest_polygon
	
	if randf() > 0.6:
		vertex_fill(center, radius)

func get_polygon_area(polygon: PackedVector2Array) -> float:
	var area = 0.0
	var n = polygon.size()
	
	if n < 3:
		return 0.0 # Not a polygon
		
	for i in range(n):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % n] # Wraps around to the first point
		area += (p1.x * p2.y) - (p2.x * p1.y)
	
	return abs(area) / 2.0

func create_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var circle_points: PackedVector2Array = []
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		var point = (center + Vector2(cos(angle), sin(angle)) * radius) + Vector2(randf_range(-2, 2),randf_range(-2,2))
		circle_points.append(point)
	return circle_points

func launch_debris(origin: Vector2, angle: float, radius: float, amount: float) -> void:
	print("Terrain launching debris...")
	ParticleManager.launch_debris(origin, angle, radius, amount)

func vertex_fill(crater_center: Vector2, crater_radius: float):
	var current_polygon = poly.polygon.duplicate()
	var new_polygon: PackedVector2Array = []
	var fill_radius = crater_radius * 3.0  # Only process 3x crater radius
	
	new_polygon.append(current_polygon[0])
	for i in current_polygon.size() - 2:
		if i != 0:
			var previous_vec : Vector2 = current_polygon[i-1]
			var current_vec : Vector2 = current_polygon[i]
			var next_vec : Vector2 = current_polygon[i+1]
			#if i > 1 or i < current_polygon.size()-2:
				#var local_angle = get_angle_between_three_points(previous_vec, current_vec, next_vec)
				#var difference = local_angle / angle_limit
				#if difference < 1.0:
					#current_vec = current_vec.lerp((previous_vec + next_vec) * 0.5, difference)
				#print("angle: %s, difference: %s, new_angle %s" % [local_angle, difference, get_angle_between_three_points(previous_vec, current_vec, next_vec) ])
			# Only process edges near the crater
			var midpoint = (current_vec + next_vec) * 0.5
			if midpoint.distance_to(crater_center) <= fill_radius:
				var distance : float = current_vec.distance_to(next_vec)
				new_polygon.append(current_vec)
				if distance > vertex_gap:
					var num_divisions : int = min(5, int(distance / vertex_gap))  # Limit subdivisions
					for ii in range(1, num_divisions + 1):
						var t : float = float(ii) / float(num_divisions + 1)
						var inbetween : Vector2 = current_vec.lerp(next_vec, t)
						new_polygon.append(inbetween)
			else:
				# Just add the vertex as-is for distant areas
				new_polygon.append(current_vec)
				
	
	new_polygon.append(current_polygon[-1])
	poly.polygon = new_polygon
	body_coll.polygon = new_polygon

func get_angle_between_three_points(point1: Vector2, point2: Vector2, point3: Vector2) -> float:
	# Create vectors from the vertex (p_b) to the other two points
	var first = rad_to_deg(point1.angle_to(point2))
	var second = rad_to_deg(point3.angle_to(point2))
	return abs(first) + abs(second)
