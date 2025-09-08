extends BTAction

# Safe blackboard variable access with automatic default setting
func _safe_get_blackboard_var(key: String, default_value):
	if blackboard.has_var(key):
		return blackboard.get_var(key)
	else:
		# Set the default value for future use
		blackboard.set_var(key, default_value)
		return default_value

func _tick(_delta: float) -> Status:
	# Get patrol center with fallback to agent's current position
	var default_center = Vector3.ZERO
	if agent and agent.has_method("get_global_position"):
		default_center = agent.get_global_position()
	elif agent:
		default_center = agent.global_transform.origin
	
	var center = _safe_get_blackboard_var("patrol_center", default_center)
	var radius = _safe_get_blackboard_var("patrol_radius", 20.0)
	
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
