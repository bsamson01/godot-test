# check_emergency.gd - Check for emergency situations
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
	
	# Check for emergency conditions
	var is_emergency = false
	var emergency_type = ""
	
	# Check if member is injured
	if member_comp.current_state == GangMemberComponent.MemberState.INJURED:
		is_emergency = true
		emergency_type = "injured"
	
	# Check if member is dead
	if member_comp.current_state == GangMemberComponent.MemberState.DEAD:
		is_emergency = true
		emergency_type = "dead"
	
	# Check if loyalty is critically low
	if member_comp.loyalty < 20.0:
		is_emergency = true
		emergency_type = "low_loyalty"
	
	# Update blackboard
	blackboard.set_var("is_emergency", is_emergency)
	blackboard.set_var("emergency_type", emergency_type)
	
	return SUCCESS if is_emergency else FAILURE
