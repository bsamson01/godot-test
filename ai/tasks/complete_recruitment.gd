extends BTAction

func _tick(_delta: float) -> Status:
	var target_npc_entity = blackboard.get_var("target_npc_entity", null)
	if not target_npc_entity:
		agent.updateLabel('No target NPC entity')
		return FAILURE
	
	# Get the gang member's faction
	if "member_id" in agent and agent.member_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.faction_id != "":
					var faction_entity = entity_manager.get_entity(member_comp.faction_id)
					if faction_entity:
						var faction_comp = faction_entity.get_component("FactionComponent")
						if faction_comp:
							# Convert NPC to gang member
							_convert_npc_to_gang_member(target_npc_entity, faction_entity.id, faction_comp.color)
							
							# Add to faction
							faction_comp.add_member(target_npc_entity)
							
							# Emit recruitment success event
							if Engine.has_singleton("EventBus"):
								Engine.get_singleton("EventBus").emit_event(
									Engine.get_singleton("EventBus").EventType.FACTION_MEMBER_ADDED,
									{
										"faction_id": faction_entity.id,
										"member_entity": target_npc_entity,
										"recruiter_id": agent.member_id
									}
								)
							
							agent.updateLabel('Recruitment completed successfully')
							return SUCCESS
	
	agent.updateLabel('Failed to complete recruitment')
	return FAILURE

func _convert_npc_to_gang_member(npc_entity: Entity, faction_id: String, faction_color: Color) -> void:
	# Get NPC component
	var npc_comp = npc_entity.get_component("NPCComponent")
	if not npc_comp:
		return
	
	# Create gang member component
	var gang_member_comp = preload("res://scripts/components/gang_member_component.gd").new()
	gang_member_comp.member_name = npc_comp.npc_name
	gang_member_comp.role = "Member"  # Default role
	gang_member_comp.loyalty = 70.0  # Start with decent loyalty
	gang_member_comp.personality = "Loyal"  # Default personality
	gang_member_comp.faction_id = faction_id
	gang_member_comp.location = npc_comp.location
	
	# Remove old component and add new one
	npc_entity.remove_component(npc_comp)
	npc_entity.add_component(gang_member_comp)
	
	# Add AI component
	var ai_comp = preload("res://scripts/components/ai_component.gd").new()
	ai_comp.ai_type = "member"
	npc_entity.add_component(ai_comp)
	
	# Update visual node
	_update_npc_visual_to_gang_member(npc_entity, faction_color)
	
	Logger.info("NPC converted to gang member", "Recruitment", {
		"npc_name": gang_member_comp.member_name,
		"faction_id": faction_id
	})

func _update_npc_visual_to_gang_member(npc_entity: Entity, faction_color: Color) -> void:
	# Find the visual node
	var world_scene = agent.get_tree().get_root().get_node("World")
	if not world_scene:
		return
	
	var npc_node_name = "NPC_" + npc_entity.id
	var npc_node = world_scene.get_node_or_null(npc_node_name)
	if not npc_node:
		return
	
	# Change the node name to gang member
	npc_node.name = "GangMember_" + npc_entity.id
	
	# Change color to faction color
	if npc_node.has_method("set_color"):
		npc_node.set_color(faction_color)
	elif npc_node.has_method("modulate"):
		npc_node.modulate = faction_color
	
	# Update label if it exists
	if npc_node.has_method("updateLabel"):
		var gang_member_comp = npc_entity.get_component("GangMemberComponent")
		if gang_member_comp:
			npc_node.updateLabel(gang_member_comp.member_name)
