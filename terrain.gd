extends Node2D
@onready var poly : Polygon2D = $Polygon2D
@onready var body : StaticBody2D = $Polygon2D/StaticBody2D
@onready var body_coll : CollisionPolygon2D = $Polygon2D/StaticBody2D/CollisionPolygon2D
@export var noise1 : FastNoiseLite = FastNoiseLite.new()
@export var noise2 : FastNoiseLite = FastNoiseLite.new()
var base_ground_level = 1200.0
var slope_range = 100.0

func _ready() -> void:
	var points : PackedVector2Array = []
	points.append(Vector2(-3000, base_ground_level * 4))
	for i in range(-3000, 3000, 10):
		points.append(Vector2(i, base_ground_level + (slope_range * (noise1.get_noise_1d(i)+noise2.get_noise_1d(i)))))
	points.append(Vector2(3000, base_ground_level * 4))
	poly.polygon = points
	body_coll.polygon = points
