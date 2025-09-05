extends BTAction

func _tick(_delta: float) -> Status:
	var pos = Vector3.ZERO
	
	# Try to get the member's faction business location using ECS system
	if "member_id" in agent and agent.member_id != "":
		# Get the gang member entity from ECS
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.faction_id != "":
					# Get the faction entity
					var faction_entity = entity_manager.get_entity(member_comp.faction_id)
					if faction_entity:
						var faction_comp = faction_entity.get_component("FactionComponent")
						if faction_comp:
							# Find a business node owned by this faction
							var business_nodes = agent.get_tree().get_nodes_in_group("business")
							for node in business_nodes:
								if node.get_meta("owner", "") == member_comp.faction_id:
									pos = node.global_position
									break
	
	# Fallback: find any business if no faction business found
	if pos == Vector3.ZERO:
		var business_list = agent.get_tree().get_nodes_in_group("business")
		if business_list.size() > 0:
			pos = business_list[0].global_transform.origin
	
	# Add random offset for patrol variation
	pos += Vector3(
		randf_range(-3, 3),
		0,
		randf_range(-3, 3)
	)
	
	pos.y = 0
	blackboard.set_var("pos", pos)
	
	agent.updateLabel('Patroling')

	return SUCCESS
