# sabotage.gd - Sabotage enemy operations task
extends BTAction

var target_location: Vector3 = Vector3.ZERO
var sabotage_timer: float = 0.0
var sabotage_duration: float = 5.0
var sabotage_result: Dictionary = {}

func _tick(_delta: float) -> Status:
	# Initialize target location if not done
	if target_location == Vector3.ZERO:
		if not _initialize_sabotage_target():
			return FAILURE
	
	# Perform sabotage
	return _perform_sabotage(_delta)

func _initialize_sabotage_target() -> bool:
	# Find enemy business or territory to sabotage
	var enemy_target = _find_enemy_target()
	if enemy_target == Vector3.ZERO:
		# Fallback: sabotage a random area
		target_location = agent.get_current_position() + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
	else:
		target_location = enemy_target
	
	return true

func _find_enemy_target() -> Vector3:
	# Find enemy business or territory to sabotage
	var businesses = agent.get_tree().get_nodes_in_group("business")
	if businesses.is_empty():
		return Vector3.ZERO
	
	var nearest_enemy_business = null
	var nearest_distance = INF
	var current_pos = agent.get_current_position()
	
	# Get our faction ID
	var our_faction_id = _get_our_faction_id()
	if our_faction_id == "":
		return Vector3.ZERO
	
	for business in businesses:
		# Check if this business belongs to an enemy faction
		var business_faction_id = _get_business_faction_id(business)
		if business_faction_id != "" and business_faction_id != our_faction_id:
			var distance = current_pos.distance_to(business.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy_business = business
	
	if nearest_enemy_business:
		return nearest_enemy_business.global_position
	
	return Vector3.ZERO

func _perform_sabotage(_delta: float) -> Status:
	sabotage_timer += _delta
	
	# Move to target location
	agent.set_movement_target(target_location)
	
	# Check if we're close enough to sabotage
	var current_pos = agent.get_current_position()
	var distance_to_target = current_pos.distance_to(target_location)
	
	if distance_to_target < 3.0:  # Close enough to sabotage
		# Perform sabotage
		_execute_sabotage()
	
	# Check if sabotage is complete
	if sabotage_timer >= sabotage_duration:
		# Sabotage completed
		_complete_sabotage()
		agent.updateLabel('Sabotage completed')
		return SUCCESS
	
	# Show sabotage progress
	var progress = int((sabotage_timer / sabotage_duration) * 100)
	agent.updateLabel('Sabotaging enemy (%d%%)' % progress)
	return RUNNING

func _execute_sabotage() -> void:
	# Simulate sabotage process
	sabotage_result["target_location"] = target_location
	sabotage_result["time"] = Time.get_ticks_msec()
	sabotage_result["success"] = randf() > 0.35  # 65% chance of success
	sabotage_result["damage_caused"] = randf_range(50, 150)
	sabotage_result["stealth_level"] = randf_range(0.3, 0.9)

func _complete_sabotage() -> void:
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
							# Apply sabotage results
							if sabotage_result.get("success", false):
								# Gain some funds from successful sabotage
								var reward = 100
								faction_comp.funds += reward
								
								# Cost some supplies for the operation
								faction_comp.supplies = max(0, faction_comp.supplies - 25)
								
								Logger.info("Sabotage successful", "Sabotage", {
									"faction": faction_comp.faction_name,
									"reward": reward,
									"supplies_used": 25
								})
							else:
								# Failed sabotage costs more supplies
								faction_comp.supplies = max(0, faction_comp.supplies - 50)
								
								Logger.info("Sabotage failed", "Sabotage", {
									"faction": faction_comp.faction_name,
									"supplies_lost": 50
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
