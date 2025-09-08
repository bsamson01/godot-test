extends BTAction

func _tick(_delta: float) -> Status:
	# Safe get with fallback to agent's current position
	var target_pos: Vector3
	if blackboard.has_var("pos"):
		target_pos = blackboard.get_var("pos")
	else:
		# Use agent's current position as fallback and set it
		target_pos = agent.global_transform.origin
		blackboard.set_var("pos", target_pos)
	
	var _current_pos: Vector3 = agent.global_transform.origin
	
	target_pos.y = 0
	agent.updateTargetLocation(target_pos)
	
	if agent.nav_agent.is_navigation_finished():
		return SUCCESS
	
	return RUNNING
