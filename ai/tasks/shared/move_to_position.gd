# move_to_position.gd - Move to a target position
extends BTAction

func _tick(_delta: float) -> Status:
	var target_position = blackboard.get_var("pos", Vector3.ZERO)
	if target_position == Vector3.ZERO:
		return FAILURE
	
	# Set movement target
	agent.set_movement_target(target_position)
	
	# Check if movement is complete
	if agent.is_movement_complete():
		agent.updateLabel('Reached target')
		return SUCCESS
	
	# Show movement progress
	var current_pos = agent.get_current_position()
	var distance = current_pos.distance_to(target_position)
	agent.updateLabel('Moving to target (%.1fm)' % distance)
	
	return RUNNING
