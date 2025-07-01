extends Node

var factions: Dictionary[StringName, Faction] = {}      # faction_id -> Faction
var territories: Dictionary[StringName, Territory] = {}  # territory_id -> Territory
var businesses: Dictionary[StringName, Business] = {}    # business_id -> Business
var gang_members: Dictionary[StringName, GangMember] = {}  # member_id -> GangMember

var current_tick: int = 0

# For compatibility with existing main.gd
var gang_member_nodes: Array[GangMemberNode] = []

func get_faction(faction_id: String) -> Faction:
	return factions.get(faction_id) as Faction

func get_gang_member(member_id: String) -> GangMember:
	return gang_members.get(member_id) as GangMember
	
func get_gang_member_node(member_id: String) -> GangMemberNode:
	for mem_node in gang_member_nodes:
		if mem_node.member_id == member_id:
			return mem_node
	return null

func get_business(business_id: String) -> Business:
	return businesses.get(business_id) as Business
	
func get_territory(territory_id: String) -> Territory:
	return territories.get(territory_id) as Territory
	
func spawn_gang_member(faction_id: String) -> GangMember:
	var member = GangMember.create_random(faction_id)
	register_gang_member(member)
	return member

func register_faction(faction: Faction):
	factions[faction.id] = faction

func register_gang_member(member: GangMember):
	gang_members[member.id] = member

func register_gang_member_node(node: GangMemberNode):
	gang_member_nodes.append(node)

func register_business(business: Business):
	businesses[business.id] = business

func register_territory(territory: Territory):
	territories[territory.id] = territory

# Compatibility methods for main.gd
func get_all_factions() -> Array[Faction]:
	return factions.values()

func get_all_businesses() -> Array[Business]:
	return businesses.values()
	
func get_all_territories() -> Array[Territory]:
	return territories.values()

func update_tick(tick: int):
	current_tick = tick
