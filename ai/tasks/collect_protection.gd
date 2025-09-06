# collect_protection.gd - Collect protection money task
extends BTAction

var target_business: Node = null
var business_location: Vector3 = Vector3.ZERO
var collection_timer: float = 0.0
var collection_duration: float = 3.0

func _tick(_delta: float) -> Status:
	# Find business if not already found
	if not target_business:
		if not _find_business():
			return FAILURE
	
	# Move to business
	agent.set_movement_target(business_location)
	
	# Check if we've reached the business
	var current_pos = agent.get_current_position()
	var distance_to_business = current_pos.distance_to(business_location)
	
	if distance_to_business < 2.0:  # Close enough to business
		return _collect_protection(_delta)
	
	agent.updateLabel('Going to business (%.1fm)' % distance_to_business)
	return RUNNING

func _find_business() -> bool:
	# Find the nearest business owned by our faction
	var businesses = agent.get_tree().get_nodes_in_group("business")
	if businesses.is_empty():
		agent.updateLabel('No businesses found')
		return false
	
	var nearest_business = null
	var nearest_distance = INF
	var current_pos = agent.get_current_position()
	
	# Get our faction ID
	var our_faction_id = _get_our_faction_id()
	if our_faction_id == "":
		agent.updateLabel('No faction ID')
		return false
	
	for business in businesses:
		# Check if this business belongs to our faction
		var business_faction_id = _get_business_faction_id(business)
		if business_faction_id == our_faction_id:
			var distance = current_pos.distance_to(business.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_business = business
	
	if not nearest_business:
		agent.updateLabel('No faction businesses found')
		return false
	
	target_business = nearest_business
	business_location = nearest_business.global_position
	return true

func _collect_protection(_delta: float) -> Status:
	collection_timer += _delta
	
	# Check if collection is complete
	if collection_timer >= collection_duration:
		# Collection completed
		_apply_protection_collection()
		agent.updateLabel('Protection collected')
		return SUCCESS
	
	# Show collection progress
	var progress = int((collection_timer / collection_duration) * 100)
	agent.updateLabel('Collecting protection (%d%%)' % progress)
	return RUNNING

func _apply_protection_collection() -> void:
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
							# Collect protection money
							var protection_amount = 150  # Amount collected
							faction_comp.funds += protection_amount
							
							Logger.info("Protection collected", "CollectProtection", {
								"faction": faction_comp.faction_name,
								"amount_collected": protection_amount,
								"new_funds": faction_comp.funds
							})

func _get_our_faction_id() -> String:
	if "member_id" in agent and agent.member_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					return member_comp.faction_id
	return ""

func _get_business_faction_id(_business: Node) -> String:
	# This would need to be implemented based on how businesses store faction ownership
	# For now, return empty string (all businesses are neutral)
	return ""
