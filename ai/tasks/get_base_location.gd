extends BTAction

func _tick(_delta: float) -> Status:
	var pos = Vector3.ZERO
	
	# Try to get the member's faction base location using ECS system
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
							pos = faction_comp.base_location
	
	# Fallback: find any base if no faction base found
	if pos == Vector3.ZERO:
		var base_list = agent.get_tree().get_nodes_in_group("base")
		if base_list.size() > 0:
			pos = base_list[0].global_transform.origin
	
	blackboard.set_var("pos", pos)
	agent.updateLabel('Going to Base')
	return SUCCESS
