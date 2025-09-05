extends Node2D
@onready var poly : Polygon2D = $Polygon2D
@onready var body : StaticBody2D = $Polygon2D/StaticBody2D
@onready var body_coll : CollisionPolygon2D = $Polygon2D/StaticBody2D/CollisionPolygon2D
@export var noise1 : FastNoiseLite = FastNoiseLite.new()
@export var noise2 : FastNoiseLite = FastNoiseLite.new()
var base_ground_level = 1200.0
var slope_range = 100.0

func _ready() -> void:
	
	noise1.seed = randi()
	noise2.seed = randi()
	
	var points : PackedVector2Array = []
	points.append(Vector2(-3000, base_ground_level * 4))
	for i in range(-3000, 3000, 10): # generate base terrain
		points.append(Vector2(i, int(base_ground_level + (slope_range * (noise1.get_noise_1d(i)+noise2.get_noise_1d(i))))))
	var neighbors = []
	for ii in points.size(): # make terrain less jaggy
		if ii != 0 and ii != points.size() - 1:
			neighbors = [int(points[ii-1].y), int(points[ii+1].y)]
			points[ii] = Vector2(points[ii].x, neighbors[0]).lerp(Vector2(points[ii].x, neighbors[1]), 0.5)
	points.append(Vector2(3000, base_ground_level * 4))
	poly.polygon = points
	body_coll.polygon = points
