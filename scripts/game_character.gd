extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var childLabel = $childStatus
@export var targ: Vector3

var speed: float = 6.0

func _ready():
	# Initialize speed from game configuration if available
	if Engine.has_singleton("GameConfig"):
		var game_config = Engine.get_singleton("GameConfig")
		if game_config and game_config.has_method("get") and game_config.get("character_movement_speed"):
			speed = game_config.get("character_movement_speed")

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	rotation.x = 0
	rotation.z = 0
	
	if !nav_agent.is_navigation_finished():
		var curLoc = global_transform.origin
		var nextLoc = nav_agent.get_next_path_position()
		var newVel = (nextLoc - curLoc).normalized() * speed
		velocity = newVel
		look_at(targ)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	
func updateTargetLocation(target: Vector3):
	if nav_agent.is_navigation_finished():
		target.y = 0
		targ = target
		nav_agent.set_target_position(target)

func updateLabel(updateCopy: String):
	childLabel.text = updateCopy
	
