extends BTAction

func _tick(_delta: float) -> Status:
	var pos: Vector3 = agent.global_transform.origin
	pos = Vector3(
		randf_range(-7.0, 7.0),
		0,
		randf_range(-7.0, 7.0)
	)
	
	blackboard.set_var("pos", pos)
	return SUCCESS
