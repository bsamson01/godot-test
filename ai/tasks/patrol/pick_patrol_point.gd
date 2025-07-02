extends BTAction

func _tick(_delta: float) -> Status:
	var center = blackboard.get_var("patrol_center", Vector3.ZERO)
	var radius = blackboard.get_var("patrol_radius", 10.0)
	
	# Generate random point within patrol radius
	var angle = randf() * TAU
	var distance = randf() * radius
	
	var patrol_point = center + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	
	blackboard.set_var("target_location", patrol_point)
	blackboard.set_var("patrol_point", patrol_point)
	
	return SUCCESS
