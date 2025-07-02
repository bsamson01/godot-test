extends BTCondition

@export var health_threshold: float = 30.0

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
	
	# Check if health is below threshold
	if member.health <= health_threshold:
		blackboard.set_var("health_status", "low")
		blackboard.set_var("current_health", member.health)
		blackboard.set_var("health_percentage", member.get_health_percentage())
		return SUCCESS
	
	# Health is fine
	blackboard.erase_var("health_status")
	blackboard.erase_var("current_health")
	blackboard.erase_var("health_percentage")
	return FAILURE 
