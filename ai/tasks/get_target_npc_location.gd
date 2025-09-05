extends BTAction

func _tick(_delta: float) -> Status:
	# Get the target NPC ID from the order
	var target_npc_id = blackboard.get_var("target_npc_id", "")
	if target_npc_id == "":
		agent.updateLabel('No target NPC ID')
		return FAILURE
	
	# Find the NPC entity
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var npc_entity = entity_manager.get_entity(target_npc_id)
		
		if not npc_entity:
			agent.updateLabel('Target NPC not found')
			return FAILURE
		
		var npc_comp = npc_entity.get_component("NPCComponent")
		if not npc_comp:
			agent.updateLabel('Target has no NPC component')
			return FAILURE
		
		# Check if NPC can be recruited
		var current_day = int(Time.get_ticks_msec() / (24 * 60 * 60 * 1000))  # Rough day calculation
		if not npc_comp.can_be_recruited(current_day):
			agent.updateLabel('NPC cannot be recruited')
			return FAILURE
		
		# Set target position
		blackboard.set_var("pos", npc_comp.location)
		blackboard.set_var("target_npc_entity", npc_entity)
		agent.updateLabel('Found target NPC: ' + npc_comp.npc_name)
		return SUCCESS
	
	agent.updateLabel('EntityManager not found')
	return FAILURE
