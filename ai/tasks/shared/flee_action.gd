# flee_action.gd - Flee to safety when in danger
extends BTAction

func _tick(_delta: float) -> Status:
	var entity_id = blackboard.get_var("entity_id")
	if not entity_id:
		return FAILURE
	
	# Get entity from EntityManager
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return FAILURE
	
	var entity = entity_manager.get_entity(entity_id)
	if not entity:
		return FAILURE
	
	# Get gang member component
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		return FAILURE
	
	# Cancel current order if any
	if member_comp.current_order:
		member_comp.cancel_order("Fleeing for safety")
	
	# Set state to fleeing (we'll use TRAVELING for now)
	member_comp.change_state(GangMemberComponent.MemberState.TRAVELING)
	
	# Update blackboard
	blackboard.set_var("current_action", "fleeing")
	blackboard.set_var("target_location", _get_safe_location(member_comp))
	
	# For now, just return RUNNING to indicate we're fleeing
	# In a real implementation, this would handle pathfinding to safety
	return RUNNING

func _get_safe_location(member_comp: GangMemberComponent) -> Vector3:
	# Get faction base location as safe location
	var faction_entity = Engine.get_singleton("EntityManager").get_entity(member_comp.faction_id)
	if faction_entity:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			return faction_comp.base_location
	
	# Fallback to origin
	return Vector3.ZERO
