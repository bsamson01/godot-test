extends BTAction

func _tick(_delta: float) -> Status:
	var shops = agent.get_tree().get_nodes_in_group("shop")
	if shops.is_empty():
		push_error("No shops found in scene")
		return FAILURE
	
	var agent_pos = agent.global_transform.origin
	var nearest_shop = null
	var nearest_distance = INF
	
	for shop in shops:
		if not shop.has_method("is_open") or shop.is_open():
			var distance = agent_pos.distance_to(shop.global_transform.origin)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_shop = shop
	
	if nearest_shop == null:
		return FAILURE
		
	# Store shop location and reference in blackboard
	blackboard.set_var("target_shop", nearest_shop)
	blackboard.set_var("target_location", nearest_shop.global_transform.origin)
	blackboard.set_var("shop_distance", nearest_distance)
	
	return SUCCESS
