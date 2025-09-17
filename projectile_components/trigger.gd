extends Resource
class_name TriggerComponent

enum ActivationType { CONTACT, TIMER, ALTITUDE, BURROW_EMERGE }

@export var activation_type: ActivationType = ActivationType.CONTACT
@export var timer_delay: float = 2.0
