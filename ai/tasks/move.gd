extends BTAction

func _tick(_delta: float) -> Status:
	var target_pos: Vector3 = blackboard.get_var("pos")
	var current_pos: Vector3 = agent.global_transform.origin
	
	target_pos.y = 0
	agent.updateTargetLocation(target_pos)
	
	if agent.nav_agent.is_navigation_finished():
		return SUCCESS
	
	return RUNNING
