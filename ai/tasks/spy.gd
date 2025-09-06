# spy.gd - Spy on enemy faction task
extends BTAction

var target_location: Vector3 = Vector3.ZERO
var spy_timer: float = 0.0
var spy_duration: float = 5.0
var intel_gathered: Dictionary = {}

func _tick(_delta: float) -> Status:
	# Initialize target location if not done
	if target_location == Vector3.ZERO:
		if not _initialize_spy_location():
			return FAILURE
	
	# Spy on the target
	return _perform_spying(_delta)

func _initialize_spy_location() -> bool:
	# Get target faction from order parameters
	var current_order = blackboard.get_var("current_order", null)
	var target_faction_id = ""
	
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			target_faction_id = order_comp.parameters.get("target_faction", "")
	
	# Find enemy base or territory to spy on
	var enemy_location = _find_enemy_base(target_faction_id)
	if enemy_location == Vector3.ZERO:
		# Fallback: spy on a random area
		target_location = agent.get_current_position() + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
	else:
		target_location = enemy_location
	
	return true

func _find_enemy_base(target_faction_id: String = "") -> Vector3:
	# If specific target faction is provided, spy on that faction
	if target_faction_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var faction_entity = entity_manager.get_entity(target_faction_id)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					return faction_comp.base_location
		return Vector3.ZERO
	
	# Find enemy faction base to spy on (fallback)
	var enemies = agent.get_tree().get_nodes_in_group("gang_members")
	if enemies.is_empty():
		return Vector3.ZERO
	
	var enemy_factions = {}
	var current_pos = agent.get_current_position()
	
	# Get our faction ID
	var our_faction_id = _get_our_faction_id()
	if our_faction_id == "":
		return Vector3.ZERO
	
	# Group enemies by faction
	for enemy in enemies:
		if enemy == agent:  # Skip self
			continue
		
		var enemy_faction_id = _get_enemy_faction_id(enemy)
		if enemy_faction_id != "" and enemy_faction_id != our_faction_id:
			if not enemy_factions.has(enemy_faction_id):
				enemy_factions[enemy_faction_id] = []
			enemy_factions[enemy_faction_id].append(enemy)
	
	# Find the closest enemy faction base
	var nearest_base = Vector3.ZERO
	var nearest_distance = INF
	
	for faction_id in enemy_factions.keys():
		# Get faction base location
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var faction_entity = entity_manager.get_entity(faction_id)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					var distance = current_pos.distance_to(faction_comp.base_location)
					if distance < nearest_distance:
						nearest_distance = distance
						nearest_base = faction_comp.base_location
	
	return nearest_base

func _perform_spying(_delta: float) -> Status:
	spy_timer += _delta
	
	# Move to spy location
	agent.set_movement_target(target_location)
	
	# Check if we're close enough to spy
	var current_pos = agent.get_current_position()
	var distance_to_target = current_pos.distance_to(target_location)
	
	if distance_to_target < 8.0:  # Close enough to spy
		# Gather intelligence
		_gather_intelligence()
	
	# Check if spying is complete
	if spy_timer >= spy_duration:
		# Spying completed
		_complete_spying()
		agent.updateLabel('Spying completed')
		return SUCCESS
	
	# Show spying progress
	var progress = int((spy_timer / spy_duration) * 100)
	agent.updateLabel('Spying on enemy (%d%%)' % progress)
	return RUNNING

func _gather_intelligence() -> void:
	# Gather intelligence about enemy faction
	intel_gathered["location"] = target_location
	intel_gathered["time"] = Time.get_ticks_msec()
	intel_gathered["enemy_strength"] = randf_range(0.3, 1.0)
	intel_gathered["enemy_activity"] = randf_range(0.0, 1.0)
	intel_gathered["security_level"] = randf_range(0.1, 0.8)
	intel_gathered["valuable_targets"] = randf_range(0.0, 1.0)

func _complete_spying() -> void:
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
							# Add intel to faction
							faction_comp.intel["spy_" + str(Time.get_ticks_msec())] = intel_gathered
							
							Logger.info("Enemy spied on", "Spy", {
								"faction": faction_comp.faction_name,
								"intel_gathered": intel_gathered
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

func _get_enemy_faction_id(enemy: Node) -> String:
	if enemy.has_method("get") and enemy.get("member_id"):
		var member_id = enemy.get("member_id")
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					return member_comp.faction_id
	return ""
