extends BTAction

func _tick(_delta: float) -> Status:
	var business_list = agent.get_tree().get_nodes_in_group("base")
	
	var pos = Vector3.ZERO
	
	if business_list.size() > 0:
		pos = business_list[0].global_transform.origin
	
	blackboard.set_var("pos", pos)
	agent.updateLabel('Going to Base')
	return SUCCESS
