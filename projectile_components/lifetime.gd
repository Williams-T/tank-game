extends Resource
class_name LifetimeComponent

enum DurationType { INSTANT, TURN_BASED }

@export var duration_type: DurationType = DurationType.INSTANT
@export var turn_count: int = 3
