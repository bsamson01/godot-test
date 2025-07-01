extends Resource
class_name Faction

@export var id: String
@export var name: String
@export var color: Color
@export var funds: float = 1000.0
@export var supplies: float = 1000.0
@export var member_ids: Array[String] = []  # References by ID
@export var commander_id: String = ""
@export var income_log: Array[Dictionary] = []
@export var business_ids: Array[String] = []
@export var territory_ids: Array[String] = []

# Relationships by faction ID
@export var relationships: Dictionary = {}  # faction_id -> "Hostile"/"Ally"/"Neutral"

# Runtime state
var negotiations_active: bool = false
var intel: Dictionary = {}

func _init():
	id = _generate_id()

func get_members() -> Array[GangMember]:
	var members: Array[GangMember] = []
	for member_id in member_ids:
		var member = WorldState.get_gang_member(member_id)
		if member:
			members.append(member)
	return members

func get_businesses() -> Array[Business]:
	var businesses: Array[Business] = []
	for business_id in business_ids:
		var business = WorldState.get_business(business_id)
		if business:
			businesses.append(business)
	return businesses
	
func get_territories() -> Array[Territory]:
	var territories: Array[Territory] = []
	for territory_id in territory_ids:
		var territory = WorldState.get_territory(territory_id)
		if territory:
			territories.append(territory)
	return territories

func get_commander() -> GangMemberNode:
	return WorldState.get_gang_member_node(commander_id)

func add_member(member: GangMember):
	if not member_ids.has(member.id):
		member_ids.append(member.id)
		member.faction_id = id
		
		if member.role == GangMember.ROLE_COMMANDER:
			commander_id = member.id

func remove_member(member: GangMember):
	member_ids.erase(member.id)
	if commander_id == member.id:
		commander_id = ""
		
func add_territory(territory: Territory):
	if not territory_ids.has(territory.id):
		territory_ids.append(territory.id)

func remove_territory(territory: Territory):
	territory_ids.erase(territory.id)
	
func add_business(business: Business):
	if not business_ids.has(business.id):
		business_ids.append(business.id)

func remove_business(business: Business):
	business_ids.erase(business.id)
	
func add_income(income: float, business_id: String):
	var incomeEntry = {
		'amount': income,
		'source_business': business_id
	}
	income_log.append(incomeEntry)
	funds += income

func use_supplies():
	var member_count = member_ids.size()
	var territory_count = territory_ids.size()

	# Base consumption rates per member and per territory
	var member_supply_use = 4.0
	var territory_supply_use = 10.0

	# Optional: Add small random variation for realism
	var randomness = randf_range(0.9, 1.1)

	var total_use = (member_count * member_supply_use + territory_count * territory_supply_use) * randomness
	supplies -= total_use
	supplies = max(supplies, 0)  # Prevent negative supplies

func _generate_id() -> String:
	return "faction_" + str(randi())
