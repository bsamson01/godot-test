extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var childLabel = $childStatus
@export var targ: Vector3

var speed: float = 2.0  # NPCs move slower than gang members
var avoidance_component: CollisionAvoidanceComponent
var base_velocity: Vector3 = Vector3.ZERO
var avoidance_velocity: Vector3 = Vector3.ZERO

func _ready():
	# Add to npcs group for collision avoidance
	add_to_group("npcs")
	
	# Create collision avoidance component
	avoidance_component = CollisionAvoidanceComponent.new()
	add_child(avoidance_component)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	rotation.x = 0
	rotation.z = 0
	
	# Calculate base movement velocity
	if !nav_agent.is_navigation_finished():
		var curLoc = global_transform.origin
		var nextLoc = nav_agent.get_next_path_position()
		base_velocity = (nextLoc - curLoc).normalized() * speed
		look_at(targ)
	else:
		base_velocity = Vector3.ZERO
	
	# Calculate collision avoidance
	if avoidance_component:
		avoidance_velocity = avoidance_component.update_avoidance_force(global_position, base_velocity)
	
	# Combine base movement with avoidance
	velocity = base_velocity + avoidance_velocity
	
	# Ensure we don't exceed maximum speed
	if velocity.length() > speed * 1.5:  # Allow some speed boost for avoidance
		velocity = velocity.normalized() * speed * 1.5

	move_and_slide()
	
func updateTargetLocation(target: Vector3):
	if nav_agent.is_navigation_finished():
		target.y = 0
		targ = target
		nav_agent.set_target_position(target)

func updateLabel(updateCopy: String):
	childLabel.text = updateCopy
