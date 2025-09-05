# execute_order.gd - Execute the current order
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
	if not member_comp or not member_comp.current_order:
		return FAILURE
	
	# Update blackboard with current state
	blackboard.set_var("member_state", member_comp.current_state)
	blackboard.set_var("order_progress", member_comp.order_progress)
	
	# The actual order execution is handled by the GangMemberComponent
	# This task just reports the status
	
	match member_comp.current_state:
		GangMemberComponent.MemberState.TRAVELING:
			blackboard.set_var("current_action", "traveling")
			return RUNNING
		
		GangMemberComponent.MemberState.WORKING:
			blackboard.set_var("current_action", "working")
			return RUNNING
		
		GangMemberComponent.MemberState.RETURNING:
			blackboard.set_var("current_action", "returning")
			return RUNNING
		
		GangMemberComponent.MemberState.IDLE:
			# Order completed
			blackboard.set_var("current_action", "idle")
			return SUCCESS
		
		_:
			return RUNNING
