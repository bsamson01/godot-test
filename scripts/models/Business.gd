extends Resource
class_name Business

@export var id: String
@export var name: String
@export var type: String
@export var base_income: float = 10.0
@export var territory_id: String
@export var faction_id: String

const BUSINESS_TYPES = ["Nightclub", "Barbershop", "Casino", "Garage", "Pawn Shop"]
const BUSINESS_NAMES = ["Velvet Edge", "Fade Street", "Goldmine", "Razor's Den", "Undergrounds", "Lucky Spot", "Rust & Chrome"]
var current_income: float = 0.0

func _init():
	id = _generate_id()

func _generate_id() -> String:
	return "business_" + str(randi())

static func random_business(territory_id: String, faction_id: String) -> Business:
	var business = Business.new()

	business.name = BUSINESS_NAMES[randi() % BUSINESS_NAMES.size()]
	business.type = BUSINESS_TYPES[randi() % BUSINESS_TYPES.size()]
	business.territory_id = territory_id
	business.faction_id = faction_id

	return business
	
func calculate_income(time_of_day: String, territory_safe: bool) -> float:
	var multiplier := 1.0

	if time_of_day == "Night" and type == "Nightclub":
		multiplier += 0.5  # more business at night

	if not territory_safe:
		multiplier -= 0.5  # scared customers

	return base_income * multiplier

func get_territory() -> Territory:
	return WorldState.get_territory(territory_id)
	
func get_owner_faction() -> Faction:
	return WorldState.get_faction(faction_id);
