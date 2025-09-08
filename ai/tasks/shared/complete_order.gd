extends BTAction

# Safe blackboard variable access with automatic default setting
func _safe_get_blackboard_var(key: String, default_value):
	if blackboard.has_var(key):
		return blackboard.get_var(key)
	else:
		# Set the default value for future use
		blackboard.set_var(key, default_value)
		return default_value

func _tick(_delta: float) -> Status:
	var current_order = _safe_get_blackboard_var("current_order", null)
	if not current_order:
		return FAILURE
	
	# Get the OrderComponent from the order entity
	var order_comp = current_order.get_component("OrderComponent")
	if not order_comp or not order_comp.order:
		return FAILURE
		
	# Mark order as complete
	order_comp.order.status = Order.OrderStatus.COMPLETED
	order_comp.order.completed_at = Time.get_ticks_msec()
	
	# Report results if any
	var results = {}
	
	# Gather results based on order type
	match order_comp.order.order_type:
		Order.OrderType.BUY_SUPPLIES:
			results["supplies_bought"] = _safe_get_blackboard_var("supplies_bought", 0)
			results["cost"] = _safe_get_blackboard_var("supplies_cost", 0.0)
			
		Order.OrderType.SELL_GOODS:
			results["goods_sold"] = _safe_get_blackboard_var("goods_sold", 0)
			results["revenue"] = _safe_get_blackboard_var("sale_revenue", 0.0)
			
		Order.OrderType.PATROL_TERRITORY:
			var threats_detected = _safe_get_blackboard_var("threats_detected", [])
			results["threats_found"] = threats_detected.size()
			results["area_covered"] = true
			
		Order.OrderType.ATTACK_ENEMY:
			results["combat_result"] = _safe_get_blackboard_var("combat_result", "unknown")
			results["enemies_defeated"] = _safe_get_blackboard_var("enemies_defeated", 0)
			
		Order.OrderType.COLLECT_PROTECTION:
			results["money_collected"] = _safe_get_blackboard_var("protection_money", 0.0)
			results["businesses_visited"] = _safe_get_blackboard_var("businesses_visited", 0)
	
	order_comp.order.results = results
	
	# Generate completion message based on order type and results
	var completion_message = _generate_completion_message(order_comp.order.order_type, results)
	
	# Display completion message
	if agent.has_method("set_status"):
		agent.set_status(completion_message)
	
	# Print to console for debugging/logging
	print("ORDER COMPLETED: ", completion_message)
	
	# Log the completion
	Logger.info("Order completed", "OrderExecution", {
		"order_type": Order.OrderType.keys()[order_comp.order.order_type],
		"results": results,
		"message": completion_message
	})
	
	# Clear order from blackboard
	blackboard.erase_var("current_order")
	blackboard.erase_var("order_type")
	blackboard.erase_var("order_data")
	
	# Notify faction of completion
	if Engine.has_singleton("EventBus"):
		# Get the faction_id and member_id from the agent's entity
		var faction_id = ""
		var member_id = ""
		
		# The agent is a CharacterBody3D node, we need to get its associated Entity
		# The member_id is stored directly on the agent node
		print("COMPLETE_ORDER: Agent type: ", agent.get_class() if agent else "null")
		print("COMPLETE_ORDER: Agent has member_id property: ", agent.has_method("get") and agent.get("member_id") != null if agent else false)
		
		if agent and agent.has_method("get") and agent.get("member_id"):
			member_id = agent.member_id
			print("COMPLETE_ORDER: Found member_id: ", member_id)
		elif agent and agent.has_node("BTPlayer"):
			# Fallback: try to get member_id from blackboard
			var bt_player = agent.get_node("BTPlayer")
			if bt_player and bt_player.blackboard and bt_player.blackboard.has_var("entity_id"):
				member_id = bt_player.blackboard.get_var("entity_id")
				print("COMPLETE_ORDER: Found member_id from blackboard: ", member_id)
		
		if member_id != "":
			if Engine.has_singleton("EntityManager"):
				var entity_manager = Engine.get_singleton("EntityManager")
				var entity = entity_manager.get_entity(member_id)
				if entity:
					var member_comp = entity.get_component("GangMemberComponent")
					if member_comp:
						faction_id = member_comp.faction_id
						print("COMPLETE_ORDER: Found faction_id: ", faction_id)
					else:
						print("COMPLETE_ORDER: No GangMemberComponent found")
				else:
					print("COMPLETE_ORDER: Entity not found for member_id: ", member_id)
			else:
				print("COMPLETE_ORDER: EntityManager not available")
		else:
			print("COMPLETE_ORDER: No member_id found on agent or blackboard")
		
		print("COMPLETE_ORDER: Emitting ORDER_COMPLETED event with member_id=", member_id, " faction_id=", faction_id)
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_COMPLETED,
			{
				"order_id": current_order.id,
				"order": current_order,
				"member_id": member_id,
				"faction_id": faction_id,
				"success": true,
				"message": completion_message
			}
		)
		print("COMPLETE_ORDER: Event emitted successfully")
	
	return SUCCESS

# Generate a detailed completion message based on order type and results
func _generate_completion_message(order_type: Order.OrderType, results: Dictionary) -> String:
	match order_type:
		Order.OrderType.BUY_SUPPLIES:
			var supplies = results.get("supplies_bought", 0)
			var cost = results.get("cost", 0.0)
			if supplies > 0:
				return "✅ Supplies purchased! Bought %d units for $%.0f" % [supplies, cost]
			else:
				return "✅ Supply mission completed (no purchases made)"
		
		Order.OrderType.SELL_GOODS:
			var goods = results.get("goods_sold", 0)
			var revenue = results.get("revenue", 0.0)
			if goods > 0:
				return "✅ Sales completed! Sold %d items for $%.0f revenue" % [goods, revenue]
			else:
				return "✅ Sales mission completed (no sales made)"
		
		Order.OrderType.PATROL_TERRITORY:
			var threats = results.get("threats_found", 0)
			var area_covered = results.get("area_covered", false)
			if threats > 0:
				return "✅ Patrol completed! Found %d threats, area secured" % threats
			elif area_covered:
				return "✅ Patrol completed! Area clear, no threats detected"
			else:
				return "✅ Patrol mission completed"
		
		Order.OrderType.ATTACK_ENEMY:
			var combat_result = results.get("combat_result", "unknown")
			var enemies_defeated = results.get("enemies_defeated", 0)
			if enemies_defeated > 0:
				return "⚔️ Attack completed! Defeated %d enemies (%s)" % [enemies_defeated, combat_result]
			else:
				return "⚔️ Attack mission completed (%s)" % combat_result
		
		Order.OrderType.COLLECT_PROTECTION:
			var money = results.get("money_collected", 0.0)
			var businesses = results.get("businesses_visited", 0)
			if money > 0:
				return "💰 Protection collected! $%.0f from %d businesses" % [money, businesses]
			else:
				return "💰 Protection rounds completed (%d businesses visited)" % businesses
		
		Order.OrderType.DEFEND_TERRITORY:
			return "🛡️ Territory defense completed! Area secured"
		
		Order.OrderType.RECRUIT_MEMBERS:
			return "👥 Recruitment mission completed!"
		
		Order.OrderType.RECRUIT_SPECIFIC_NPC:
			return "🎯 Specific recruitment completed!"
		
		Order.OrderType.SCOUT_ENEMY:
			return "🔍 Scouting mission completed! Intel gathered"
		
		Order.OrderType.SPY:
			return "🕵️ Espionage mission completed! Information acquired"
		
		Order.OrderType.NEGOTIATE:
			return "🤝 Negotiation completed! Terms discussed"
		
		Order.OrderType.SABOTAGE:
			return "💥 Sabotage mission completed! Target disrupted"
		
		_:
			return "✅ Mission completed successfully!"
