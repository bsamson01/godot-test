extends Resource
class_name Territory

@export var id:String
@export var name: String
@export var faction_id: String
@export var business_ids: Array[String] = []
@export var center_location: Vector3 = Vector3.ZERO
@export var radius: float = 20.0

func _init():
	id = _generate_id()

func _generate_id() -> String:
	return "territory_" + str(randi())

static func random_territory(owner_faction: String) -> Territory:
	var territory = Territory.new()

	var names = [
		"Downtown", "East Ridge", "Southpoint", "Old Town", "Ash Market",
		"Pier Zone", "The Quarters", "Brickfield", "Rustbelt", "Shadow Alley"
	]

	territory.name = names[randi() % names.size()]
	territory.faction_id = owner_faction
	territory.center_location = Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
	territory.radius = randf_range(15, 30)

	return territory
	
func get_businesses() -> Array[Business]:
	var businesses: Array[Business] = []
	for business_id in business_ids:
		var business = WorldState.get_business(business_id)
		if business:
			businesses.append(business)
	return businesses
	
func add_business(business_id: String):
	if not business_ids.has(business_id):
		business_ids.append(business_id)
