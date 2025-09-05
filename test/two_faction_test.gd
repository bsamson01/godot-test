extends Node3D

# Test script to verify 2 factions are working correctly
# This creates a simple test scene to demonstrate the 2 faction system

func _ready():
	# Wait a moment for the game to initialize
	await get_tree().create_timer(2.0).timeout
	
	# Check if we have 2 factions
	_check_faction_setup()
	
	# Print faction information
	_print_faction_info()

func _check_faction_setup():
	print("=== TWO FACTION TEST ===")
	
	# Get all faction entities
	var game_manager = get_node("../GameManager") as GameManager
	if not game_manager or not game_manager.entity_manager:
		print("ERROR: GameManager not found!")
		return
	
	var factions = game_manager.entity_manager.get_entities_by_type("faction")
	print("Found %d factions" % factions.size())
	
	if factions.size() >= 2:
		print("✅ SUCCESS: 2 factions detected!")
		
		# Check faction details
		for i in range(factions.size()):
			var faction = factions[i]
			var faction_comp = faction.get_component("FactionComponent")
			if faction_comp:
				print("Faction %d: %s (Color: %s)" % [i+1, faction_comp.faction_name, faction_comp.color])
				print("  - Base Location: %s" % faction_comp.base_location)
				print("  - Members: %d" % faction_comp.get_members().size())
				print("  - Funds: %s" % faction_comp.funds)
	else:
		print("❌ ERROR: Expected 2 factions, found %d" % factions.size())

func _print_faction_info():
	# Get all gang members in the scene
	var gang_members = get_tree().get_nodes_in_group("gang_members")
	print("\n=== GANG MEMBERS ===")
	print("Found %d gang members in scene" % gang_members.size())
	
	# Group members by faction
	var faction_groups = {}
	for member in gang_members:
		if member.has_method("get") and member.get("member_id"):
			var member_id = member.get("member_id")
			# Try to find which faction this member belongs to
			var game_manager = get_node("../GameManager") as GameManager
			if game_manager and game_manager.entity_manager:
				var member_entity = game_manager.entity_manager.get_entity(member_id)
				if member_entity:
					var member_comp = member_entity.get_component("GangMemberComponent")
					if member_comp:
						var faction_id = member_comp.faction_id
						if not faction_groups.has(faction_id):
							faction_groups[faction_id] = []
						faction_groups[faction_id].append(member)
	
	# Print faction groups
	for faction_id in faction_groups.keys():
		var members = faction_groups[faction_id]
		print("Faction %s: %d members" % [faction_id, members.size()])
		for member in members:
			print("  - %s at position %s" % [member.name, member.global_position])

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		print("\n=== REFRESHING FACTION INFO ===")
		_check_faction_setup()
		_print_faction_info()
