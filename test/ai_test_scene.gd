extends Node3D

# AI Test Scene - Demonstrates the complete AI behavior tree system

@onready var faction_1_base = $Faction1Base
@onready var faction_2_base = $Faction2Base
@onready var shop_node = $Shop
@onready var business_node = $Business

var faction_1: Faction
var faction_2: Faction

func _ready():
	# Setup factions
	_setup_factions()
	
	# Setup world locations
	_setup_locations()
	
	# Spawn gang members
	_spawn_test_members()
	
	# Create some test orders
	_create_test_orders()
	
	print("AI Test Scene initialized. Press 1-8 to create different order types.")

func _setup_factions():
	# Create Faction 1
	faction_1 = Faction.new()
	faction_1.id = "faction_red"
	faction_1.name = "Red Gang"
	faction_1.base_location = faction_1_base.global_position
	faction_1.color = Color.RED
	faction_1.money = 10000
	WorldState.register_faction(faction_1)
	
	# Create Faction 2
	faction_2 = Faction.new()
	faction_2.id = "faction_blue"
	faction_2.name = "Blue Gang"
	faction_2.base_location = faction_2_base.global_position
	faction_2.color = Color.BLUE
	faction_2.money = 10000
	WorldState.register_faction(faction_2)

func _setup_locations():
	# Add shop to group
	if shop_node:
		shop_node.add_to_group("shop")
		
	# Add business to group
	if business_node:
		business_node.add_to_group("business")

func _spawn_test_members():
	# Spawn members for Faction 1
	for i in range(3):
		var member = spawn_gang_member(faction_1.id, faction_1_base.global_position)
		
	# Spawn members for Faction 2
	for i in range(3):
		var member = spawn_gang_member(faction_2.id, faction_2_base.global_position)

func spawn_gang_member(faction_id: String, spawn_pos: Vector3) -> GangMember:
	# Create member data
	var member = GangMember.create_random(faction_id)
	member.cash = 500
	WorldState.register_gang_member(member)
	
	# Create visual node
	var member_scene = preload("res://test/player.tscn")
	var member_node = member_scene.instantiate()
	member_node.position = spawn_pos + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	add_child(member_node)
	
	# Set member reference
	member_node.member_id = member.id
	
	# Add to gang members group
	member_node.add_to_group("gang_members")
	
	# Register node
	WorldState.register_gang_member_node(member_node)
	
	# Initialize AI with master behavior tree
	if member_node.has_node("BTPlayer"):
		var bt_player = member_node.get_node("BTPlayer")
		var behavior_tree = MasterAIBehavior.create_behavior_tree()
		bt_player.behavior_tree = behavior_tree
		bt_player.blackboard.set_var("member_id", member.id)
		
	return member

func _create_test_orders():
	# Create a patrol order for faction 1
	var members_1 = get_faction_members(faction_1.id)
	if members_1.size() > 0:
		var order = WorldState.create_order(
			Order.TYPE_PATROL_TERRITORY,
			members_1[0].id,
			{}
		)
		print("Created patrol order for ", members_1[0].name)

func get_faction_members(faction_id: String) -> Array[GangMember]:
	var members: Array[GangMember] = []
	for member in WorldState.gang_members.values():
		if member.faction_id == faction_id:
			members.append(member)
	return members

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				create_order_for_faction(faction_1.id, Order.TYPE_BUY_SUPPLIES)
			KEY_2:
				create_order_for_faction(faction_1.id, Order.TYPE_PATROL_TERRITORY)
			KEY_3:
				create_order_for_faction(faction_1.id, Order.TYPE_ATTACK_ENEMY, {"target_faction": faction_2.id})
			KEY_4:
				create_order_for_faction(faction_1.id, Order.TYPE_DEFEND_TERRITORY)
			KEY_5:
				create_order_for_faction(faction_2.id, Order.TYPE_BUY_SUPPLIES)
			KEY_6:
				create_order_for_faction(faction_2.id, Order.TYPE_PATROL_TERRITORY)
			KEY_7:
				create_order_for_faction(faction_2.id, Order.TYPE_ATTACK_ENEMY, {"target_faction": faction_1.id})
			KEY_8:
				create_order_for_faction(faction_2.id, Order.TYPE_DEFEND_TERRITORY)

func create_order_for_faction(faction_id: String, order_type: int, data: Dictionary = {}):
	var members = get_faction_members(faction_id)
	if members.is_empty():
		print("No members in faction ", faction_id)
		return
		
	# Find a member without a current order
	for member in members:
		var current_orders = WorldState.get_orders_for_member(member.id)
		var has_active_order = false
		for order in current_orders:
			if order.status == Order.STATUS_PENDING or order.status == Order.STATUS_IN_PROGRESS:
				has_active_order = true
				break
				
		if not has_active_order:
			var order = WorldState.create_order(order_type, member.id, data)
			print("Created ", order.name(), " order for ", member.name)
			return
			
	print("All members are busy!")
