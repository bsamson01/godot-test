# patrol_territory.gd - Patrol territory task
extends BTAction

var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_radius: float = 15.0
var patrol_center: Vector3 = Vector3.ZERO

func _tick(_delta: float) -> Status:
	# Initialize patrol points if not done
	if patrol_points.is_empty():
		if not _initialize_patrol_points():
			return FAILURE
	
	# Get current patrol point
	var target_point = patrol_points[current_patrol_index]
	
	# Move to patrol point
	agent.set_movement_target(target_point)
	
	# Check if we've reached the patrol point
	var current_pos = agent.get_current_position()
	var distance_to_point = current_pos.distance_to(target_point)
	
	if distance_to_point < 2.0:  # Close enough to patrol point
		# Move to next patrol point
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		
		# Wait a bit at this point (simplified for now)
		# await get_tree().create_timer(2.0).timeout
		
		agent.updateLabel('Patrolling territory')
		return SUCCESS
	
	agent.updateLabel('Patrolling (%.1fm to point)' % distance_to_point)
	return RUNNING

func _initialize_patrol_points() -> bool:
	# Get the member's faction base location
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
							patrol_center = faction_comp.base_location
							_generate_patrol_points()
							return true
	
	# Fallback: use current position as center
	patrol_center = agent.get_current_position()
	_generate_patrol_points()
	return true

func _generate_patrol_points() -> void:
	patrol_points.clear()
	
	# Generate 4 patrol points around the center
	for i in range(4):
		var angle = i * PI / 2.0  # 90 degrees apart
		var offset = Vector3(
			cos(angle) * patrol_radius,
			0,
			sin(angle) * patrol_radius
		)
		patrol_points.append(patrol_center + offset)
	
	# Add center point as well
	patrol_points.append(patrol_center)
	
	# Shuffle the points for more natural patrol pattern
	patrol_points.shuffle()
