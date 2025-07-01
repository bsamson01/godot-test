extends BTCondition

@export var health_threshold: float = 30.0
@export var threat_detection_radius: float = 10.0

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
		
	# Check low health
	if member.health <= health_threshold:
		blackboard.set_var("emergency_type", "low_health")
		blackboard.set_var("emergency_health", member.health)
		return SUCCESS
		
	# Check for nearby threats
	var agent_pos = agent.global_transform.origin
	var threats = []
	
	for potential_threat in get_tree().get_nodes_in_group("gang_members"):
		if potential_threat == agent:
			continue
			
		var threat_member = potential_threat.get_member() if potential_threat.has_method("get_member") else null
		if threat_member and threat_member.faction_id != member.faction_id:
			var distance = agent_pos.distance_to(potential_threat.global_transform.origin)
			if distance <= threat_detection_radius:
				# Check if threat is aggressive (has attack order targeting us)
				var threat_orders = WorldState.get_orders_for_member(threat_member.id)
				for order in threat_orders:
					if order.type == Order.TYPE_ATTACK_ENEMY and order.status == Order.STATUS_IN_PROGRESS:
						threats.append(potential_threat)
						break
	
	if not threats.is_empty():
		blackboard.set_var("emergency_type", "under_attack")
		blackboard.set_var("emergency_threats", threats)
		return SUCCESS
		
	# No emergency
	blackboard.erase_var("emergency_type")
	return FAILURE