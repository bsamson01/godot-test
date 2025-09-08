# check_for_order.gd - Check if gang member has an assigned order
extends BTCondition

func _tick(_delta: float) -> Status:
	var entity_id = blackboard.get_var("entity_id")
	if not entity_id:
		# Try to get entity_id from agent if available
		var agent_node = blackboard.get_var("agent")
		if agent_node and agent_node.has_method("get") and agent_node.member_id:
			entity_id = agent_node.member_id
			blackboard.set_var("entity_id", entity_id)
		else:
			# Entity ID not yet available, throttle checks to avoid spam
			var last_check_time = 0.0
			if blackboard.has_var("last_entity_id_check"):
				last_check_time = blackboard.get_var("last_entity_id_check")
			
			var current_time_check = Time.get_ticks_msec() / 1000.0
			if current_time_check - last_check_time > 1.0:  # Only check once per second
				blackboard.set_var("last_entity_id_check", current_time_check)
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
	
	# Debug: Log when checking for orders (throttled)
	var last_debug_time = 0.0
	if blackboard.has_var("last_order_debug"):
		last_debug_time = blackboard.get_var("last_order_debug")
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_debug_time > 5.0:  # Debug every 5 seconds
		blackboard.set_var("last_order_debug", current_time)
		var member_name = member_comp.member_name if member_comp else "Unknown"
		Logger.debug("Checking for order: %s has_order=%s" % [member_name, has_order], "CheckForOrder")

	
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
