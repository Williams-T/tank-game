extends Resource
class_name EffectComponent

enum EffectType { DAMAGE_CRATER, ADD_TERRAIN, SPAWN_PROJECTILES, ROPE_BRIDGE }

@export var effect_type: EffectType = EffectType.DAMAGE_CRATER
@export var crater_size: float = 50.0
@export var spawn_count: int = 5
