extends BTAction

func _tick(_delta: float) -> Status:
	var shop_list = agent.get_tree().get_nodes_in_group("business")
	
	var pos = Vector3.ZERO
	
	if shop_list.size() > 0:
		pos = shop_list[0].global_transform.origin
		
	pos += Vector3(
		randf_range(-3, 3),
		0,
		randf_range(-3, 3)
	)
	
	pos.y = 0
	blackboard.set_var("pos", pos)
	
	agent.updateLabel('Patroling')

	return SUCCESS
