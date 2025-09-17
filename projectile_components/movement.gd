extends Resource
class_name MovementComponent

enum TrajectoryType { ARC, STRAIGHT }
enum PhysicsMode { NORMAL_GRAVITY, REVERSE_GRAVITY, NO_GRAVITY, }
enum CollisionResponse { STOP, BOUNCE, PASS_THROUGH }

@export var trajectory_type: TrajectoryType = TrajectoryType.ARC
@export var physics_mode: PhysicsMode = PhysicsMode.NORMAL_GRAVITY
@export var collision_response: CollisionResponse = CollisionResponse.STOP
@export var bounce_count: int = 1
