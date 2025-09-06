# negotiate.gd - Negotiate with other faction task
extends BTAction

var target_faction: String = ""
var negotiation_location: Vector3 = Vector3.ZERO
var negotiation_timer: float = 0.0
var negotiation_duration: float = 10.0
var negotiation_result: Dictionary = {}

func _tick(_delta: float) -> Status:
	# Initialize negotiation if not done
	if target_faction == "":
		if not _initialize_negotiation():
			return FAILURE
	
	# Perform negotiation
	return _perform_negotiation(_delta)

func _initialize_negotiation() -> bool:
	# Get target faction from order parameters
	var current_order = blackboard.get_var("current_order", null)
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			target_faction = order_comp.parameters.get("target_faction", "")
	
	# If no specific target, find a random faction
	if target_faction == "":
		target_faction = _find_target_faction()
		if target_faction == "":
			agent.updateLabel('No factions to negotiate with')
			return false
	
	# Set negotiation location (neutral ground)
	negotiation_location = agent.get_current_position() + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
	
	return true

func _find_target_faction() -> String:
	# Find another faction to negotiate with
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var factions = entity_manager.get_entities_with_component("FactionComponent")
		
		# Get our faction ID
		var our_faction_id = _get_our_faction_id()
		if our_faction_id == "":
			return ""
		
		# Find a different faction
		for faction_entity in factions:
			if faction_entity.id != our_faction_id:
				return faction_entity.id
	
	return ""

func _perform_negotiation(_delta: float) -> Status:
	negotiation_timer += _delta
	
	# Move to negotiation location
	agent.set_movement_target(negotiation_location)
	
	# Check if we're at the negotiation location
	var current_pos = agent.get_current_position()
	var distance_to_location = current_pos.distance_to(negotiation_location)
	
	if distance_to_location < 3.0:  # Close enough to negotiate
		# Perform negotiation
		_conduct_negotiation()
	
	# Check if negotiation is complete
	if negotiation_timer >= negotiation_duration:
		# Negotiation completed
		_complete_negotiation()
		agent.updateLabel('Negotiation completed')
		return SUCCESS
	
	# Show negotiation progress
	var progress = int((negotiation_timer / negotiation_duration) * 100)
	agent.updateLabel('Negotiating (%d%%)' % progress)
	return RUNNING

func _conduct_negotiation() -> void:
	# Simulate negotiation process
	negotiation_result["target_faction"] = target_faction
	negotiation_result["time"] = Time.get_ticks_msec()
	negotiation_result["success"] = randf() > 0.5  # 50% chance of success
	negotiation_result["agreement_type"] = ["trade", "alliance", "truce", "territory"][randi() % 4]
	negotiation_result["terms"] = {
		"funds_exchanged": randf_range(-200, 200),
		"supplies_exchanged": randf_range(-50, 50),
		"territory_changes": randf_range(-1, 1)
	}

func _complete_negotiation() -> void:
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
							# Apply negotiation results
							if negotiation_result.get("success", false):
								var terms = negotiation_result.get("terms", {})
								faction_comp.funds += terms.get("funds_exchanged", 0)
								faction_comp.supplies += terms.get("supplies_exchanged", 0)
								
								# Update relationships
								if not faction_comp.relationships.has(target_faction):
									faction_comp.relationships[target_faction] = 0.0
								faction_comp.relationships[target_faction] += 10.0
								
								Logger.info("Negotiation successful", "Negotiate", {
									"faction": faction_comp.faction_name,
									"target_faction": target_faction,
									"terms": terms
								})
							else:
								Logger.info("Negotiation failed", "Negotiate", {
									"faction": faction_comp.faction_name,
									"target_faction": target_faction
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
