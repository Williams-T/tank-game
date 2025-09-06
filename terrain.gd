extends Node2D
@onready var poly : Polygon2D = $Polygon2D
@onready var body : StaticBody2D = $Polygon2D/StaticBody2D
@onready var body_coll : CollisionPolygon2D = $Polygon2D/StaticBody2D/CollisionPolygon2D
@export var noise1 : FastNoiseLite = FastNoiseLite.new()
@export var noise2 : FastNoiseLite = FastNoiseLite.new()

@export var crater_base_radius: float = 80.0
@export var crater_randomness: float = 0.3
@export var crater_points: int = 24

var base_ground_level = 1200.0
var slope_range = 100.0
var vertex_gap = 10.0

func _ready() -> void:
	
	noise1.seed = randi()
	noise2.seed = randi()
	
	var points : PackedVector2Array = []
	points.append(Vector2(-3000, base_ground_level * 4))
	for i in range(-3000, 3000, vertex_gap): # generate base terrain
		points.append(Vector2(i, int(base_ground_level + (slope_range * (noise1.get_noise_1d(i)+noise2.get_noise_1d(i))))))
	var neighbors = []
	for ii in points.size(): # make terrain less jaggy
		if ii != 0 and ii != points.size() - 1:
			neighbors = [int(points[ii-1].y), int(points[ii+1].y)]
			points[ii] = Vector2(points[ii].x, neighbors[0]).lerp(Vector2(points[ii].x, neighbors[1]), 0.5)
	points.append(Vector2(3000, base_ground_level * 4))
	poly.polygon = points
	body_coll.polygon = points

func create_crater(center: Vector2, radius: float, shape: String = "circle"):
	var current_polygon = poly.polygon.duplicate()
	var crater_shape
	match shape:
		"circle":
			# Create crater as a circle polygon
			crater_shape = create_circle_polygon(center, radius, 32)
		#"capsule": #TODO: Implement other shapes
			#crater_shape = create_capsule_polygon(center, radius, 32)
	
	# Subtract crater from terrain using Godot's geometry functions
	var result_polygons = Geometry2D.clip_polygons(current_polygon, crater_shape)
	
	if result_polygons.size() > 0:
		# Use the largest resulting polygon (in case crater splits terrain)
		var largest_polygon = result_polygons[0]
		for polygon in result_polygons:
			if polygon.size() > largest_polygon.size():
				largest_polygon = polygon
		
		poly.polygon = largest_polygon
		body_coll.polygon = largest_polygon
	
	if randf() > 0.6:
		vertex_fill(center, radius)

func create_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var circle_points: PackedVector2Array = []
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		var point = (center + Vector2(cos(angle), sin(angle)) * radius) + Vector2(randf_range(-3, 3),randf_range(-3,3))
		circle_points.append(point)
	return circle_points

func vertex_fill(crater_center: Vector2, crater_radius: float):
	var current_polygon = poly.polygon.duplicate()
	var new_polygon: PackedVector2Array = []
	var fill_radius = crater_radius * 3.0  # Only process 3x crater radius
	
	new_polygon.append(current_polygon[0])
	for i in current_polygon.size() - 2:
		if i != 0:
			var current_vec : Vector2 = current_polygon[i]
			var next_vec : Vector2 = current_polygon[i+1]
			
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
