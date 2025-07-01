extends BTAction

func _tick(_delta: float) -> Status:
	var current_order = blackboard.get_var("current_order")
	if not current_order:
		return FAILURE
		
	# Mark order as complete
	current_order.status = Order.STATUS_COMPLETED
	current_order.completed_at = Time.get_ticks_msec()
	
	# Report results if any
	var results = {}
	
	# Gather results based on order type
	match current_order.type:
		Order.TYPE_BUY_SUPPLIES:
			results["supplies_bought"] = blackboard.get_var("supplies_bought", 0)
			results["cost"] = blackboard.get_var("supplies_cost", 0)
			
		Order.TYPE_SELL_GOODS:
			results["goods_sold"] = blackboard.get_var("goods_sold", 0)
			results["revenue"] = blackboard.get_var("sale_revenue", 0)
			
		Order.TYPE_PATROL_TERRITORY:
			results["threats_found"] = blackboard.get_var("threats_detected", []).size()
			results["area_covered"] = true
			
		Order.TYPE_ATTACK_ENEMY:
			results["combat_result"] = blackboard.get_var("combat_result", "unknown")
			results["enemies_defeated"] = blackboard.get_var("enemies_defeated", 0)
			
		Order.TYPE_COLLECT_PROTECTION:
			results["money_collected"] = blackboard.get_var("protection_money", 0)
			results["businesses_visited"] = blackboard.get_var("businesses_visited", 0)
	
	current_order.results = results
	
	# Clear order from blackboard
	blackboard.erase_var("current_order")
	blackboard.erase_var("order_type")
	blackboard.erase_var("order_data")
	
	# Notify faction of completion
	EventBus.emit_signal("order_completed", current_order)
	
	if agent.has_method("set_status"):
		agent.set_status("Order completed!")
	
	return SUCCESS