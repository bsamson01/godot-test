extends CharacterBody3D

const SPEED = 3
@onready var nav_agent = $NavigationAgent3D
@onready var childLabel = $childStatus
@export var targ: Vector3

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	rotation.x = 0
	rotation.z = 0
	
	if !nav_agent.is_navigation_finished():
		var curLoc = global_transform.origin
		var nextLoc = nav_agent.get_next_path_position()
		var newVel = (nextLoc - curLoc).normalized() * SPEED
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
	
