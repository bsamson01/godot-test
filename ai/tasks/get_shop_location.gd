extends BTAction

func _tick(_delta: float) -> Status:
	var pos = Vector3.ZERO
	
	# Shops are typically neutral, so find the nearest shop to the member's faction base
	if "member_id" in agent and agent.member_id != "":
		# Get the gang member entity from ECS
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.faction_id != "":
					# Get the faction entity to find base location
					var faction_entity = entity_manager.get_entity(member_comp.faction_id)
					if faction_entity:
						var faction_comp = faction_entity.get_component("FactionComponent")
						if faction_comp:
							var base_location = faction_comp.base_location
							# Find nearest shop to faction base
							var shops = agent.get_tree().get_nodes_in_group("shop")
							var nearest_shop = null
							var nearest_distance = INF
							
							for shop in shops:
								var distance = base_location.distance_to(shop.global_position)
								if distance < nearest_distance:
									nearest_distance = distance
									nearest_shop = shop
							
							if nearest_shop:
								pos = nearest_shop.global_position
	
	# Fallback: find any shop if no faction found
	if pos == Vector3.ZERO:
		var shop_list = agent.get_tree().get_nodes_in_group("shop")
		if shop_list.size() > 0:
			pos = shop_list[0].global_transform.origin
	
	blackboard.set_var("pos", pos)
	agent.updateLabel('Going to shop')
	return SUCCESS
