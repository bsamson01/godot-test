extends BTAction

func _tick(_delta: float) -> Status:
	var shop_list = agent.get_tree().get_nodes_in_group("shop")
	
	var pos = Vector3.ZERO
	
	if shop_list.size() > 0:
		pos = shop_list[0].global_transform.origin
	
	blackboard.set_var("pos", pos)
	agent.updateLabel('Going to shop')
	return SUCCESS
