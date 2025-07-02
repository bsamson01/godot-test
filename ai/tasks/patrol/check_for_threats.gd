extends BTAction

@export var detection_radius: float = 15.0
@export var check_duration: float = 2.0

var _check_timer: float = 0.0

func _enter():
	_check_timer = 0.0
	if agent.has_method("set_status"):
		agent.set_status("Scanning for threats...")

func _tick(delta: float) -> Status:
	_check_timer += delta
	
	if _check_timer < check_duration:
		return RUNNING
		
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return SUCCESS
		
	var threats_found = []
	var agent_pos = agent.global_transform.origin
	
	# Check for enemy gang members
	for potential_threat in agent.get_tree().get_nodes_in_group("gang_members"):
		if potential_threat == agent:
			continue
			
		var threat_member = potential_threat.get_member() if potential_threat.has_method("get_member") else null
		if threat_member and threat_member.faction_id != member.faction_id:
			var distance = agent_pos.distance_to(potential_threat.global_transform.origin)
			if distance <= detection_radius:
				threats_found.append({
					"target": potential_threat,
					"member": threat_member,
					"distance": distance
				})
	
	if not threats_found.is_empty():
		# Sort by distance
		threats_found.sort_custom(func(a, b): return a.distance < b.distance)
		
		blackboard.set_var("threats_detected", threats_found)
		blackboard.set_var("nearest_threat", threats_found[0])
		
		if agent.has_method("set_status"):
			agent.set_status("Threat detected!")
		
		return FAILURE  # Return FAILURE to trigger threat response
	
	if agent.has_method("set_status"):
		agent.set_status("Area clear")
		
	return SUCCESS
