extends Node

# Test script for the recruitment system
func _ready():
	# Wait a bit for the game to initialize
	await get_tree().create_timer(2.0).timeout
	_test_recruitment_system()

func _test_recruitment_system():
	print("=== Testing Recruitment System ===")
	
	# Test 1: Check if NPCs are being generated
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		print("ERROR: EntityManager not found")
		return
	
	var npcs = entity_manager.get_entities_with_component("NPCComponent")
	print("Found %d NPCs in the world" % npcs.size())
	
	# Test 2: Check if any NPCs can be recruited
	var current_day = int(Time.get_ticks_msec() / (24 * 60 * 60 * 1000))
	var recruitable_count = 0
	
	for npc_entity in npcs:
		var npc_comp = npc_entity.get_component("NPCComponent")
		if npc_comp and npc_comp.can_be_recruited(current_day):
			recruitable_count += 1
			print("Recruitable NPC: %s (spawned day: %d, current day: %d)" % [npc_comp.npc_name, npc_comp.spawn_day, current_day])
	
	print("Found %d recruitable NPCs" % recruitable_count)
	
	# Test 3: Check if factions exist and have commanders
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	print("Found %d factions" % factions.size())
	
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			print("Faction: %s, Members: %d, Funds: %.2f" % [faction_comp.faction_name, faction_comp.get_members().size(), faction_comp.funds])
			
			# Check if commander can give recruit orders
			var members = faction_comp.get_members()
			for member_entity in members:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.role == "Commander":
					print("Commander found: %s" % member_comp.member_name)
					break
	
	# Test 4: Simulate giving a recruit order
	if recruitable_count > 0 and factions.size() > 0:
		print("\n=== Simulating Recruit Order ===")
		_simulate_recruit_order()
	else:
		print("Cannot test recruitment - need recruitable NPCs and factions")

func _simulate_recruit_order():
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return
	
	# Find a recruitable NPC
	var npcs = entity_manager.get_entities_with_component("NPCComponent")
	var current_day = int(Time.get_ticks_msec() / (24 * 60 * 60 * 1000))
	var target_npc = null
	
	for npc_entity in npcs:
		var npc_comp = npc_entity.get_component("NPCComponent")
		if npc_comp and npc_comp.can_be_recruited(current_day):
			target_npc = npc_entity
			break
	
	if not target_npc:
		print("No recruitable NPC found")
		return
	
	# Find a faction with a commander
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	var target_faction = null
	var commander = null
	
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp and faction_comp.funds > 2000:  # Need funds for recruitment
			target_faction = faction_entity
			var members = faction_comp.get_members()
			for member_entity in members:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.role == "Commander":
					commander = member_entity
					break
			break
	
	if not target_faction or not commander:
		print("No suitable faction/commander found")
		return
	
	# Create a recruit specific NPC order
	var order_entity = entity_manager.create_entity("order")
	var order_comp = preload("res://scripts/components/order_component.gd").new()
	order_comp.target_id = target_npc.id
	order_comp.parameters = {"target_npc_id": target_npc.id}
	order_entity.add_component(order_comp)
	
	# Set the order type
	order_comp.order = preload("res://scripts/models/order.gd").new()
	order_comp.order.order_type = preload("res://scripts/models/order.gd").OrderType.RECRUIT_SPECIFIC_NPC
	order_comp.order.target_id = target_npc.id
	order_comp.order.data = {"target_npc_id": target_npc.id}
	order_comp.order.issued_tick = int(Time.get_ticks_msec() / 1000.0)
	
	# Assign to commander
	var commander_comp = commander.get_component("GangMemberComponent")
	if commander_comp:
		if commander_comp.assign_order(order_entity):
			print("Recruit order assigned to commander: %s" % commander_comp.member_name)
			print("Target NPC: %s" % target_npc.get_component("NPCComponent").npc_name)
		else:
			print("Failed to assign order to commander")
	else:
		print("Commander missing GangMemberComponent")
