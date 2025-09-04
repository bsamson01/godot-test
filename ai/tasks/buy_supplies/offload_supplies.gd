extends BTAction

@export var offload_duration: float = 1.5

var _offload_timer: float = 0.0

func _enter():
	_offload_timer = 0.0
	if agent.has_method("set_status"):
		agent.set_status("Offloading supplies...")

func _tick(delta: float) -> Status:
	var base_location = blackboard.get_var("target_location")
	if not base_location:
		return FAILURE
		
	# Simulate offloading process
	_offload_timer += delta
	
	if _offload_timer >= offload_duration:
		var supplies_bought = blackboard.get_var("supplies_bought", 0)
		var member = agent.get_member() if agent.has_method("get_member") else null
		
		if member and member.faction:
			# Use ECS system to add supplies to faction
			var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
			if entity_manager:
				var faction_entity = entity_manager.get_entity(member.faction_id)
				if faction_entity:
					var faction_comp = faction_entity.get_component("FactionComponent")
					if faction_comp:
						faction_comp.add_supplies(supplies_bought)
						
						# Report success
						blackboard.set_var("supplies_delivered", true)
						
						if agent.has_method("set_status"):
							agent.set_status("Supplies delivered!")
						
						return SUCCESS
		
		return FAILURE
		
	return RUNNING
