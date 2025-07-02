extends BTAction

@export var defense_range: float = 8.0
@export var counter_attack_threshold: float = 0.7  # Health percentage to consider counter-attacking

var defense_start_time: float = 0.0
var last_action_time: float = 0.0

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Initialize defense start time
	if defense_start_time == 0.0:
		defense_start_time = current_time
		last_action_time = current_time
	
	var threats = blackboard.get_var("threats") or []
	if threats.is_empty():
		# No threats, defense successful
		_reset_defense_state()
		return SUCCESS
	
	# Update status
	if agent.has_method("set_status"):
		agent.set_status("Defending")
	
	# Get nearest threat
	var nearest_threat = threats[0]
	var threat_distance = nearest_threat.distance
	
	# Strategy based on health and threat level
	var health_percentage = member.get_health_percentage()
	var threat_level = blackboard.get_var("threat_level") or 0.0
	
	if health_percentage < 0.3:
		# Very low health - focus on evasion and cover
		_evasive_defense(nearest_threat)
	elif health_percentage < counter_attack_threshold:
		# Low health - defensive positioning
		_defensive_positioning(nearest_threat)
	else:
		# Good health - can be more aggressive
		_aggressive_defense(nearest_threat)
	
	# Check if we should continue defending
	var time_defending = current_time - defense_start_time
	if time_defending > 30.0:  # Max 30 seconds of continuous defense
		_reset_defense_state()
		return SUCCESS
	
	# Check if threats are gone
	var current_threats = _check_current_threats()
	if current_threats.is_empty():
		_reset_defense_state()
		return SUCCESS
	
	return RUNNING

func _evasive_defense(nearest_threat: Dictionary):
	# Move away from threat while looking for cover
	var current_pos = agent.global_transform.origin
	var threat_pos = nearest_threat.node.global_transform.origin
	var away_direction = (current_pos - threat_pos).normalized()
	
	# Find cover position
	var cover_position = _find_cover_position(current_pos, threat_pos)
	if cover_position:
		if agent.has_method("updateTargetLocation"):
			agent.updateTargetLocation(cover_position)
	else:
		# No cover, just move away
		var flee_target = current_pos + (away_direction * 10.0)
		if agent.has_method("updateTargetLocation"):
			agent.updateTargetLocation(flee_target)

func _defensive_positioning(nearest_threat: Dictionary):
	# Maintain distance while preparing for counter-attack
	var current_pos = agent.global_transform.origin
	var threat_pos = nearest_threat.node.global_transform.origin
	var distance_to_threat = current_pos.distance_to(threat_pos)
	
	if distance_to_threat < defense_range * 0.5:
		# Too close, back away
		var away_direction = (current_pos - threat_pos).normalized()
		var target_pos = current_pos + (away_direction * defense_range)
		if agent.has_method("updateTargetLocation"):
			agent.updateTargetLocation(target_pos)
	elif distance_to_threat > defense_range * 1.5:
		# Too far, move closer for potential counter-attack
		var toward_direction = (threat_pos - current_pos).normalized()
		var target_pos = current_pos + (toward_direction * defense_range * 0.5)
		if agent.has_method("updateTargetLocation"):
			agent.updateTargetLocation(target_pos)
	else:
		# Good distance, hold position and prepare
		# Could add strafing or other defensive movements here
		pass

func _aggressive_defense(nearest_threat: Dictionary):
	# More aggressive stance - can counter-attack
	var current_pos = agent.global_transform.origin
	var threat_pos = nearest_threat.node.global_transform.origin
	var distance_to_threat = current_pos.distance_to(threat_pos)
	
	if distance_to_threat <= defense_range:
		# In range for counter-attack
		_counter_attack(nearest_threat)
	else:
		# Move into range
		var toward_direction = (threat_pos - current_pos).normalized()
		var target_pos = current_pos + (toward_direction * defense_range * 0.8)
		if agent.has_method("updateTargetLocation"):
			agent.updateTargetLocation(target_pos)

func _counter_attack(threat: Dictionary):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Only attack every few seconds to avoid spam
	if current_time - last_action_time < 2.0:
		return
	
	last_action_time = current_time
	
	# Simulate counter-attack
	var threat_member = threat.member
	var damage = randf_range(10, 25)  # Random damage
	
	# Apply damage to threat
	if threat_member.has_method("take_damage"):
		threat_member.take_damage(damage)
	
	# Log the attack
	print("%s counter-attacks %s for %.1f damage" % [
		agent.get_member().name if agent.has_method("get_member") else "Unknown",
		threat_member.name,
		damage
	])

func _find_cover_position(current_pos: Vector3, threat_pos: Vector3) -> Vector3:
	# Simple cover system - look for positions that block line of sight
	var best_cover = null
	var best_cover_score = 0.0
	
	# Sample positions around current location
	for i in range(12):
		var angle = i * PI / 6
		var test_pos = current_pos + Vector3(cos(angle), 0, sin(angle)) * 5.0
		
		var cover_score = _calculate_cover_score(test_pos, threat_pos)
		if cover_score > best_cover_score:
			best_cover_score = cover_score
			best_cover = test_pos
	
	# Only return cover if it's significantly better than current position
	var current_cover_score = _calculate_cover_score(current_pos, threat_pos)
	if best_cover_score > current_cover_score + 0.2:
		return best_cover
	
	return Vector3.ZERO

func _calculate_cover_score(position: Vector3, threat_pos: Vector3) -> float:
	var cover_score = 0.0
	
	# Distance from threat (farther is better for cover)
	var distance = position.distance_to(threat_pos)
	if distance > 15.0:
		cover_score += 0.3
	
	# Check for obstacles between position and threat (simplified)
	# In a real game, you'd do proper raycasting
	var direction = (threat_pos - position).normalized()
	var obstacle_check = position + (direction * 10.0)
	
	# Simulate some cover based on position
	if position.y > threat_pos.y:
		cover_score += 0.2  # Higher ground
	
	# Add some randomness to simulate different cover types
	cover_score += randf() * 0.1
	
	return clamp(cover_score, 0.0, 1.0)

func _check_current_threats() -> Array:
	var current_threats = []
	var current_pos = agent.global_transform.origin
	var member = agent.get_member() if agent.has_method("get_member") else null
	
	if not member:
		return current_threats
	
	for potential_threat in agent.get_tree().get_nodes_in_group("gang_members"):
		if potential_threat == agent:
			continue
			
		var threat_member = potential_threat.get_member() if potential_threat.has_method("get_member") else null
		if threat_member and threat_member.faction_id != member.faction_id:
			var distance = current_pos.distance_to(potential_threat.global_transform.origin)
			if distance <= defense_range * 2.0:  # Extended range for threat checking
				current_threats.append({
					"member": threat_member,
					"node": potential_threat,
					"distance": distance
				})
	
	return current_threats

func _reset_defense_state():
	defense_start_time = 0.0
	last_action_time = 0.0
	blackboard.erase_var("under_attack")
	blackboard.erase_var("threats")
	blackboard.erase_var("threat_level") 
