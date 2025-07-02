extends BTAction

@export var flee_distance: float = 20.0
@export var safety_check_radius: float = 10.0

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
	
	var current_pos = agent.global_transform.origin
	
	# Get or calculate safe location
	var safe_location = blackboard.get_var("safe_location")
	if safe_location == null:
		safe_location = _find_safe_location(current_pos, member.faction_id)
		blackboard.set_var("safe_location", safe_location)
	
	if safe_location == null:
		# No safe location found, try to move away from threats
		var threats = blackboard.get_var("threats") or []
		if not threats.is_empty():
			var away_direction = Vector3.ZERO
			for threat in threats:
				var threat_pos = threat.node.global_transform.origin
				var direction = (current_pos - threat_pos).normalized()
				away_direction += direction * threat.threat_level
			
			if away_direction.length() > 0:
				away_direction = away_direction.normalized()
				safe_location = current_pos + (away_direction * flee_distance)
				blackboard.set_var("safe_location", safe_location)
		else:
			# No threats, just move to base
			var faction = WorldState.get_faction(member.faction_id)
			if faction and faction.base_location:
				safe_location = faction.base_location
				blackboard.set_var("safe_location", safe_location)
	
	if safe_location == null:
		return FAILURE
	
	# Update status
	if agent.has_method("set_status"):
		agent.set_status("Fleeing to safety")
	
	# Move towards safe location
	if agent.has_method("updateTargetLocation"):
		agent.updateTargetLocation(safe_location)
	
	# Check if we've reached safety
	var distance_to_safety = current_pos.distance_to(safe_location)
	if distance_to_safety <= safety_check_radius:
		# Check if location is actually safe
		if _is_location_safe(safe_location, member.faction_id):
			blackboard.erase_var("safe_location")
			blackboard.erase_var("health_status")
			blackboard.erase_var("under_attack")
			return SUCCESS
	
	return RUNNING

func _find_safe_location(current_pos: Vector3, faction_id: String) -> Vector3:
	var faction = WorldState.get_faction(faction_id)
	if not faction:
		return Vector3.ZERO
	
	# Priority 1: Try to reach base
	if faction.base_location:
		var base_distance = current_pos.distance_to(faction.base_location)
		if base_distance <= flee_distance * 1.5:  # Allow some extra distance
			return faction.base_location
	
	# Priority 2: Find nearby friendly territory
	var friendly_territories = []
	for territory in WorldState.get_territories():
		if territory.faction_id == faction_id:
			var territory_distance = current_pos.distance_to(territory.center_location)
			if territory_distance <= flee_distance:
				friendly_territories.append({
					"territory": territory,
					"distance": territory_distance
				})
	
	# Sort by distance and pick closest
	friendly_territories.sort_custom(func(a, b): return a.distance < b.distance)
	if not friendly_territories.is_empty():
		return friendly_territories[0].territory.center_location
	
	# Priority 3: Find any location away from enemies
	var best_location = null
	var best_safety_score = 0.0
	
	# Sample points around current position
	for i in range(8):
		var angle = i * PI / 4
		var test_location = current_pos + Vector3(cos(angle), 0, sin(angle)) * flee_distance
		
		var safety_score = _calculate_safety_score(test_location, faction_id)
		if safety_score > best_safety_score:
			best_safety_score = safety_score
			best_location = test_location
	
	return best_location

func _is_location_safe(location: Vector3, faction_id: String) -> bool:
	var safety_score = _calculate_safety_score(location, faction_id)
	return safety_score > 0.7  # 70% safety threshold

func _calculate_safety_score(location: Vector3, faction_id: String) -> float:
	var safety_score = 1.0
	
	# Check for nearby enemies
	for member_node in agent.get_tree().get_nodes_in_group("gang_members"):
		var member = member_node.get_member() if member_node.has_method("get_member") else null
		if member and member.faction_id != faction_id:
			var distance = location.distance_to(member_node.global_transform.origin)
			if distance < 15.0:
				safety_score -= (15.0 - distance) / 15.0 * 0.5  # Reduce safety by up to 50%
	
	# Check if in friendly territory
	var in_friendly_territory = false
	for territory in WorldState.get_territories():
		if territory.faction_id == faction_id:
			var distance = location.distance_to(territory.center_location)
			if distance <= territory.radius:
				in_friendly_territory = true
				safety_score += 0.3  # Bonus for being in friendly territory
				break
	
	return clamp(safety_score, 0.0, 1.0) 
