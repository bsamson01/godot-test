# recruit_npc.gd - Recruit a specific NPC task
extends BTAction

var recruit_state: String = "find_npc"
var target_npc_entity: Entity = null
var chat_timer: float = 0.0
var base_location: Vector3 = Vector3.ZERO

func _tick(delta: float) -> Status:
	# Get the target NPC ID from the order
	var target_npc_id = _get_target_npc_id()
	if target_npc_id == "":
		agent.updateLabel('No target NPC ID')
		return FAILURE
	
	# Execute recruitment based on current state
	match recruit_state:
		"find_npc":
			return _find_target_npc()
		"approach_npc":
			return _approach_npc(delta)
		"chat_with_npc":
			return _chat_with_npc(delta)
		"return_to_base":
			return _return_to_base(delta)
		_:
			return FAILURE

func _get_target_npc_id() -> String:
	# Try to get from blackboard first
	var target_id = blackboard.get_var("target_npc_id", "")
	if target_id != "":
		return target_id
	
	# Get from current order
	var current_order = blackboard.get_var("current_order", null)
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			return order_comp.get_target_id()
	
	return ""

func _find_target_npc() -> Status:
	var target_npc_id = _get_target_npc_id()
	
	# Find the NPC entity
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		target_npc_entity = entity_manager.get_entity(target_npc_id)
		
		if not target_npc_entity:
			agent.updateLabel('Target NPC not found')
			return FAILURE
		
		var npc_comp = target_npc_entity.get_component("NPCComponent")
		if not npc_comp:
			agent.updateLabel('Target has no NPC component')
			return FAILURE
		
		# Check if NPC can be recruited
		var current_day = int(Time.get_ticks_msec() / (24 * 60 * 60 * 1000))
		if not npc_comp.can_be_recruited(current_day):
			agent.updateLabel('NPC cannot be recruited')
			return FAILURE
		
		# Set target position and move to approach phase
		blackboard.set_var("pos", npc_comp.location)
		recruit_state = "approach_npc"
		agent.updateLabel('Found target NPC: ' + npc_comp.npc_name)
		return SUCCESS
	
	agent.updateLabel('EntityManager not found')
	return FAILURE

func _approach_npc(_delta: float) -> Status:
	if not target_npc_entity:
		return FAILURE
	
	var npc_comp = target_npc_entity.get_component("NPCComponent")
	if not npc_comp:
		return FAILURE
	
	# Update target position (NPC might be moving)
	blackboard.set_var("pos", npc_comp.location)
	
	# Use the movement system
	agent.set_movement_target(npc_comp.location)
	
	# Check if we're close enough to start chatting
	var current_pos = agent.get_current_position()
	var distance_to_npc = current_pos.distance_to(npc_comp.location)
	
	if distance_to_npc < 3.0:  # Close enough to chat
		recruit_state = "chat_with_npc"
		chat_timer = 0.0
		agent.updateLabel('Chatting with NPC')
		return SUCCESS
	
	agent.updateLabel('Approaching NPC (%.1fm)' % distance_to_npc)
	return RUNNING

func _chat_with_npc(delta: float) -> Status:
	if not target_npc_entity:
		return FAILURE
	
	chat_timer += delta
	
	# Update NPC position while chatting (they might still be moving)
	var npc_comp = target_npc_entity.get_component("NPCComponent")
	if npc_comp:
		blackboard.set_var("pos", npc_comp.location)
	
	# Check if chat is complete (6 seconds)
	if chat_timer >= 6.0:
		# Attempt recruitment
		var current_day = int(Time.get_ticks_msec() / (24 * 60 * 60 * 1000))
		var success = npc_comp.attempt_recruitment(agent.member_id, current_day)
		
		if success:
			# NPC is now following us
			recruit_state = "return_to_base"
			agent.updateLabel('NPC recruited, returning to base')
			
			# Set NPC to follow the gang member
			npc_comp.is_recruited = true
			npc_comp.recruited_by = agent.member_id
			npc_comp.is_wandering = false
			npc_comp.current_target = Vector3.ZERO
			
			# Get base location
			_get_base_location()
			return SUCCESS
		else:
			agent.updateLabel('Recruitment failed')
			return FAILURE
	
	# Show progress
	var progress = int((chat_timer / 6.0) * 100)
	agent.updateLabel('Chatting with NPC (%d%%)' % progress)
	return RUNNING

func _return_to_base(_delta: float) -> Status:
	if base_location == Vector3.ZERO:
		_get_base_location()
	
	# Use the movement system
	agent.set_movement_target(base_location)
	
	# Check if we've reached the base
	var current_pos = agent.get_current_position()
	var distance_to_base = current_pos.distance_to(base_location)
	
	if distance_to_base < 2.0:  # Close enough to base
		# Complete the recruitment
		_complete_recruitment()
		agent.updateLabel('Recruitment completed')
		return SUCCESS
	
	# Update NPC position to follow us
	if target_npc_entity:
		var npc_comp = target_npc_entity.get_component("NPCComponent")
		if npc_comp:
			# Make NPC follow the gang member
			npc_comp.location = current_pos + Vector3(1, 0, 1)  # Follow behind and to the side
	
	agent.updateLabel('Returning to base with NPC (%.1fm)' % distance_to_base)
	return RUNNING

func _get_base_location() -> void:
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
							base_location = faction_comp.base_location
							blackboard.set_var("pos", base_location)

func _complete_recruitment() -> void:
	if not target_npc_entity:
		return
	
	# Get the gang member's faction
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
							# Convert NPC to gang member
							_convert_npc_to_gang_member(target_npc_entity, faction_entity.id, faction_comp.color)
							
							# Add to faction
							faction_comp.add_member(target_npc_entity)
							
							# Emit recruitment success event
							if Engine.has_singleton("EventBus"):
								Engine.get_singleton("EventBus").emit_event(
									Engine.get_singleton("EventBus").EventType.FACTION_MEMBER_ADDED,
									{
										"faction_id": faction_entity.id,
										"member_entity": target_npc_entity,
										"recruiter_id": agent.member_id
									}
								)

func _convert_npc_to_gang_member(npc_entity: Entity, faction_id: String, faction_color: Color) -> void:
	# Get NPC component
	var npc_comp = npc_entity.get_component("NPCComponent")
	if not npc_comp:
		return
	
	# Create gang member component
	var gang_member_comp = preload("res://scripts/components/gang_member_component.gd").new()
	gang_member_comp.member_name = npc_comp.npc_name
	gang_member_comp.role = "Member"  # Default role
	gang_member_comp.loyalty = 70.0  # Start with decent loyalty
	gang_member_comp.personality = "Loyal"  # Default personality
	gang_member_comp.faction_id = faction_id
	gang_member_comp.location = npc_comp.location
	
	# Remove old component and add new one
	npc_entity.remove_component(npc_comp)
	npc_entity.add_component(gang_member_comp)
	
	# Add AI component
	var ai_comp = preload("res://scripts/components/ai_component.gd").new()
	ai_comp.ai_type = "member"
	npc_entity.add_component(ai_comp)
	
	# Update visual node
	_update_npc_visual_to_gang_member(npc_entity, faction_color)
	
	Logger.info("NPC converted to gang member", "Recruitment", {
		"npc_name": gang_member_comp.member_name,
		"faction_id": faction_id
	})

func _update_npc_visual_to_gang_member(npc_entity: Entity, faction_color: Color) -> void:
	# Find the visual node
	var world_scene = agent.get_tree().get_root().get_node("World")
	if not world_scene:
		return
	
	var npc_node_name = "NPC_" + npc_entity.id
	var npc_node = world_scene.get_node_or_null(npc_node_name)
	if not npc_node:
		return
	
	# Change the node name to gang member
	npc_node.name = "GangMember_" + npc_entity.id
	
	# Change color to faction color
	if npc_node.has_method("set_color"):
		npc_node.set_color(faction_color)
	elif npc_node.has_method("modulate"):
		npc_node.modulate = faction_color
	
	# Update label if it exists
	if npc_node.has_method("updateLabel"):
		var gang_member_comp = npc_entity.get_component("GangMemberComponent")
		if gang_member_comp:
			npc_node.updateLabel(gang_member_comp.member_name)
