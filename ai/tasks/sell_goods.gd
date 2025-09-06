# sell_goods.gd - Sell goods task
extends BTAction

var target_shop: Node = null
var shop_location: Vector3 = Vector3.ZERO

func _tick(_delta: float) -> Status:
	# Find shop if not already found
	if not target_shop:
		if not _find_shop():
			return FAILURE
	
	# Move to shop
	agent.set_movement_target(shop_location)
	
	# Check if we've reached the shop
	var current_pos = agent.get_current_position()
	var distance_to_shop = current_pos.distance_to(shop_location)
	
	if distance_to_shop < 2.0:  # Close enough to shop
		# Sell goods
		_sell_goods()
		agent.updateLabel('Goods sold')
		return SUCCESS
	
	agent.updateLabel('Going to shop (%.1fm)' % distance_to_shop)
	return RUNNING

func _find_shop() -> bool:
	# Find the nearest shop
	var shops = agent.get_tree().get_nodes_in_group("shop")
	if shops.is_empty():
		agent.updateLabel('No shops found')
		return false
	
	var nearest_shop = null
	var nearest_distance = INF
	var current_pos = agent.get_current_position()
	
	for shop in shops:
		if not shop.has_method("is_open") or shop.is_open():
			var distance = current_pos.distance_to(shop.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_shop = shop
	
	if not nearest_shop:
		agent.updateLabel('No open shops found')
		return false
	
	target_shop = nearest_shop
	shop_location = nearest_shop.global_position
	return true

func _sell_goods() -> void:
	# Get the current order to access parameters
	var current_order = blackboard.get_var("current_order", null)
	var goods_value = 75  # Default value
	var supplies_used = 25  # Default amount
	
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			# Use order parameters
			goods_value = order_comp.parameters.get("value", 75.0)
			supplies_used = order_comp.parameters.get("amount", 25.0)
	
	# Get the member's faction
	if "member_id" in agent and agent.member_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.faction_id != "":
					var faction_entity = entity_manager.get_entity(member_comp.faction_id)
					if faction_entity:
						var faction_comp = faction_entity.get_component("FactionComponent")
						if faction_comp:
							# Sell goods for funds
							faction_comp.funds += goods_value
							faction_comp.supplies = max(0, faction_comp.supplies - supplies_used)
							
							Logger.info("Goods sold", "SellGoods", {
								"faction": faction_comp.faction_name,
								"funds_gained": goods_value,
								"supplies_used": supplies_used,
								"new_funds": faction_comp.funds
							})
