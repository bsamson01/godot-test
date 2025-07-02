extends BTCondition

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
		
	# Check if member has a current order
	var current_order = blackboard.get_var("current_order")
	if current_order and current_order.status == Order.STATUS_IN_PROGRESS:
		return SUCCESS
		
	# Check for new orders from the faction
	var faction = WorldState.get_faction(member.faction_id)
	if not faction:
		return FAILURE
		
	# Get pending orders assigned to this member
	var orders = WorldState.get_orders_for_member(member.id)
	for order in orders:
		if order.status == Order.STATUS_PENDING:
			# Claim the order
			order.status = Order.STATUS_IN_PROGRESS
			blackboard.set_var("current_order", order)
			blackboard.set_var("order_type", order.type)
			blackboard.set_var("order_data", order.data)
			return SUCCESS
	
	# No orders available
	blackboard.erase_var("current_order")
	return FAILURE
