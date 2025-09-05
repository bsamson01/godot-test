# check_for_order.gd - Check if gang member has an assigned order
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
	
	# Check if member has an order
	var has_order = member_comp.current_order != null
	blackboard.set_var("has_order", has_order)
	
	if has_order:
		# Update order information in blackboard
		var order_comp = member_comp.current_order.get_component("OrderComponent")
		if order_comp:
			blackboard.set_var("current_order", member_comp.current_order)
			blackboard.set_var("order_type", order_comp.get_order_type())
			blackboard.set_var("order_status", order_comp.get_status())
			blackboard.set_var("order_progress", member_comp.order_progress)
		
		return SUCCESS
	else:
		# Clear order information
		blackboard.set_var("current_order", null)
		blackboard.set_var("order_type", -1)
		blackboard.set_var("order_status", -1)
		blackboard.set_var("order_progress", 0.0)
		
		return FAILURE
