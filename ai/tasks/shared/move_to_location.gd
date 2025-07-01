extends BTAction

@export var location_var: String = "target_location"
@export var arrive_distance: float = 2.0

func _tick(_delta: float) -> Status:
	if not agent.has_method("updateTargetLocation"):
		push_error("Agent does not have updateTargetLocation method")
		return FAILURE
		
	var target_pos: Vector3 = blackboard.get_var(location_var)
	if target_pos == null:
		push_error("No target location found in blackboard")
		return FAILURE
	
	# Update navigation target
	target_pos.y = 0
	agent.updateTargetLocation(target_pos)
	
	# Check if we've arrived
	var current_pos: Vector3 = agent.global_transform.origin
	current_pos.y = 0
	
	var distance = current_pos.distance_to(target_pos)
	
	if agent.nav_agent.is_navigation_finished() or distance <= arrive_distance:
		return SUCCESS
	
	return RUNNING