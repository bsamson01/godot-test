# check_low_health.gd - Check if gang member has low health
extends BTCondition

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
	
	# Check if member is injured or dead
	var is_low_health = (member_comp.current_state == GangMemberComponent.MemberState.INJURED or 
						member_comp.current_state == GangMemberComponent.MemberState.DEAD)
	
	blackboard.set_var("is_low_health", is_low_health)
	
	return SUCCESS if is_low_health else FAILURE
