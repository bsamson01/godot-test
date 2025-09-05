# defend_action.gd - Defend when under attack
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
		member_comp.cancel_order("Defending against attack")
	
	# Set state to defending (we'll use WORKING for now)
	member_comp.change_state(GangMemberComponent.MemberState.WORKING)
	
	# Update blackboard
	blackboard.set_var("current_action", "defending")
	
	# For now, just return RUNNING to indicate we're defending
	# In a real implementation, this would handle combat logic
	return RUNNING
