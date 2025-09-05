extends BTAction

func _tick(_delta: float) -> Status:
	# Try to get the member's faction using ECS system
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
							# Use faction base location as patrol center
							var base_location = faction_comp.base_location
							blackboard.set_var("patrol_center", base_location)
							blackboard.set_var("patrol_radius", 15.0)  # 15 unit radius around base
							return SUCCESS
	
	# Fallback: use agent's current position
	var current_pos = agent.global_transform.origin
	blackboard.set_var("patrol_center", current_pos)
	blackboard.set_var("patrol_radius", 10.0)
	
	return SUCCESS
