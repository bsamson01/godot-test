# SaveManager.gd - Handles game save and load functionality
extends Node
class_name SaveManager

# Save file paths
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "gang_save_"
const SAVE_FILE_EXTENSION = ".json"

# Current save data
var current_save_data: Dictionary = {}
var current_save_name: String = ""

# Save version for compatibility
const SAVE_VERSION = "1.0.0"

func _ready():
	# Create save directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.open("user://").make_dir("saves")

func save_game(save_name: String) -> bool:
	if save_name.is_empty():
		Logger.error("Save name cannot be empty", "SaveManager")
		return false
	
	# Generate save data
	var save_data = _generate_save_data()
	
	# Save to file
	var file_path = SAVE_DIR + SAVE_FILE_PREFIX + save_name + SAVE_FILE_EXTENSION
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		Logger.error("Failed to create save file: " + file_path, "SaveManager")
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	# Update current save
	current_save_data = save_data
	current_save_name = save_name
	
	Logger.info("Game saved successfully", "SaveManager", {
		"save_name": save_name,
		"file_path": file_path
	})
	
	return true

func load_game(save_name: String) -> bool:
	if save_name.is_empty():
		Logger.error("Save name cannot be empty", "SaveManager")
		return false
	
	# Load from file
	var file_path = SAVE_DIR + SAVE_FILE_PREFIX + save_name + SAVE_FILE_EXTENSION
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		Logger.error("Save file not found: " + file_path, "SaveManager")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		Logger.error("Failed to parse save file JSON", "SaveManager")
		return false
	
	var save_data = json.data
	
	# Validate save data
	if not _validate_save_data(save_data):
		Logger.error("Invalid save data format", "SaveManager")
		return false
	
	# Load the data
	_load_save_data(save_data)
	
	# Update current save
	current_save_data = save_data
	current_save_name = save_name
	
	Logger.info("Game loaded successfully", "SaveManager", {
		"save_name": save_name,
		"file_path": file_path
	})
	
	return true

func _generate_save_data() -> Dictionary:
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"game_time": 0.0,
		"entities": [],
		"systems": {},
		"world_state": {}
	}
	
	# Get game manager
	var game_manager = Engine.get_singleton("GameManager")
	if game_manager:
		save_data.game_time = game_manager.game_time
	
	# Save entities
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		save_data.entities = _save_entities(entity_manager)
	
	# Save system states
	save_data.systems = _save_system_states()
	
	# Save world state
	save_data.world_state = _save_world_state()
	
	return save_data

func _save_entities(entity_manager: EntityManager) -> Array[Dictionary]:
	var entities_data = []
	
	for entity in entity_manager.get_all_entities():
		var entity_data = {
			"id": entity.id,
			"entity_type": entity.entity_type,
			"components": []
		}
		
		# Save each component
		for component in entity.get_all_components():
			var component_data = _save_component(component)
			if component_data:
				entity_data.components.append(component_data)
		
		entities_data.append(entity_data)
	
	return entities_data

func _save_component(component: Component) -> Dictionary:
	var component_data = {
		"type": component.get_component_name(),
		"data": {}
	}
	
	# Save component-specific data
	match component.get_component_name():
		"GangMemberComponent":
			var member_comp = component as GangMemberComponent
			component_data.data = {
				"member_name": member_comp.member_name,
				"member_role": member_comp.role,
				"loyalty": member_comp.loyalty,
				"current_state": member_comp.current_state,
				"faction_id": member_comp.faction_id,
				"time_in_faction": member_comp.time_in_faction,
				"personality": member_comp.personality,
				"current_order": member_comp.current_order.id if member_comp.current_order else "",
				"order_progress": member_comp.order_progress,
				"order_start_time": member_comp.order_start_time
			}
		
		"FactionComponent":
			var faction_comp = component as FactionComponent
			component_data.data = {
				"faction_name": faction_comp.faction_name,
				"faction_type": faction_comp.faction_type,
				"funds": faction_comp.funds,
				"supplies": faction_comp.supplies,
				"base_location": faction_comp.base_location,
				"member_ids": faction_comp.get_member_ids(),
				"relationships": faction_comp.relationships,
				"intel": faction_comp.intel
			}
		
		"OrderComponent":
			var order_comp = component as OrderComponent
			if order_comp.order:
				component_data.data = {
					"order_type": order_comp.order.order_type,
					"status": order_comp.order.status,
					"assigned_to": order_comp.order.assigned_to,
					"target_id": order_comp.order.target_id,
					"data": order_comp.order.data,
					"issued_tick": order_comp.order.issued_tick,
					"started_at": order_comp.order.started_at,
					"completed_at": order_comp.order.completed_at,
					"results": order_comp.order.results,
					"travel_time": order_comp.order.travel_time,
					"work_time": order_comp.order.work_time,
					"return_time": order_comp.order.return_time,
					"priority": order_comp.order.priority,
					"required_funds": order_comp.order.required_funds,
					"required_supplies": order_comp.order.required_supplies,
					"success_chance": order_comp.order.success_chance,
					"failure_reason": order_comp.order.failure_reason
				}
		
		"NPCComponent":
			var npc_comp = component as NPCComponent
			component_data.data = {
				"npc_name": npc_comp.npc_name,
				"npc_type": npc_comp.npc_type,
				"location": npc_comp.location,
				"recruitment_cost": npc_comp.recruitment_cost,
				"recruitment_chance": npc_comp.recruitment_chance,
				"loyalty_requirement": npc_comp.loyalty_requirement,
				"last_recruitment_attempt": npc_comp.last_recruitment_attempt,
				"recruitment_cooldown": npc_comp.recruitment_cooldown,
				"is_recruited": npc_comp.is_recruited,
				"recruited_by": npc_comp.recruited_by,
				"health": npc_comp.health,
				"morale": npc_comp.morale,
				"skills": npc_comp.skills
			}
		
		"TerritoryComponent":
			var territory_comp = component as TerritoryComponent
			component_data.data = {
				"territory_name": territory_comp.territory_name,
				"territory_type": territory_comp.territory_type,
				"center_location": territory_comp.center_location,
				"radius": territory_comp.radius,
				"value": territory_comp.value,
				"income_per_hour": territory_comp.income_per_hour,
				"controlled_by": territory_comp.controlled_by,
				"control_level": territory_comp.control_level,
				"last_income_time": territory_comp.last_income_time,
				"population": territory_comp.population,
				"safety_level": territory_comp.safety_level,
				"corruption_level": territory_comp.corruption_level,
				"development_level": territory_comp.development_level,
				"events": territory_comp.events
			}
		
		"BusinessComponent":
			var business_comp = component as BusinessComponent
			component_data.data = {
				"business_name": business_comp.business_name,
				"business_type": business_comp.business_type,
				"location": business_comp.location,
				"value": business_comp.value,
				"income_per_hour": business_comp.income_per_hour,
				"controlled_by": business_comp.controlled_by,
				"control_level": business_comp.control_level,
				"protection_paid": business_comp.protection_paid,
				"last_income_time": business_comp.last_income_time,
				"reputation": business_comp.reputation,
				"customer_satisfaction": business_comp.customer_satisfaction,
				"security_level": business_comp.security_level,
				"efficiency": business_comp.efficiency,
				"is_operational": business_comp.is_operational,
				"operational_hours": business_comp.operational_hours,
				"events": business_comp.events
			}
	
	return component_data

func _save_system_states() -> Dictionary:
	var systems_data = {}
	
	# Save OrderManager state
	if Engine.has_singleton("OrderManager"):
		var order_manager = Engine.get_singleton("OrderManager")
		systems_data["order_manager"] = order_manager.get_stats()
	
	# Save AIBehaviorManager state
	if Engine.has_singleton("AIBehaviorManager"):
		var ai_manager = Engine.get_singleton("AIBehaviorManager")
		systems_data["ai_behavior_manager"] = ai_manager.get_stats()
	
	return systems_data

func _save_world_state() -> Dictionary:
	var world_state = {
		"time_of_day": 0.0,
		"weather": "clear",
		"world_events": []
	}
	
	# Add more world state as needed
	
	return world_state

func _validate_save_data(save_data: Dictionary) -> bool:
	# Check required fields
	if not save_data.has("version"):
		return false
	
	if not save_data.has("entities"):
		return false
	
	if not save_data.has("systems"):
		return false
	
	# Check version compatibility
	var save_version = save_data["version"]
	if save_version != SAVE_VERSION:
		Logger.warning("Save version mismatch: " + save_version + " vs " + SAVE_VERSION, "SaveManager")
	
	return true

func _load_save_data(save_data: Dictionary) -> void:
	# Clear current game state
	_clear_current_game_state()
	
	# Load entities
	_load_entities(save_data.get("entities", []))
	
	# Load system states
	_load_system_states(save_data.get("systems", {}))
	
	# Load world state
	_load_world_state(save_data.get("world_state", {}))
	
	# Restore game time
	if Engine.has_singleton("GameManager"):
		var game_manager = Engine.get_singleton("GameManager")
		game_manager.game_time = save_data.get("game_time", 0.0)

func _clear_current_game_state() -> void:
	# Clear all entities
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		entity_manager.clear_all_entities()
	
	# Clear order queues
	if Engine.has_singleton("OrderManager"):
		# OrderManager will be cleared when entities are cleared
		pass

func _load_entities(entities_data: Array[Dictionary]) -> void:
	if not Engine.has_singleton("EntityManager"):
		Logger.error("EntityManager not available for loading", "SaveManager")
		return
	
	var entity_manager = Engine.get_singleton("EntityManager")
	
	# First pass: create all entities
	for entity_data in entities_data:
		var entity = entity_manager.create_entity(entity_data["entity_type"])
		entity.id = entity_data["id"]
	
	# Second pass: add components
	for entity_data in entities_data:
		var entity = entity_manager.get_entity(entity_data["id"])
		if not entity:
			continue
		
		for component_data in entity_data.get("components", []):
			_load_component(entity, component_data)

func _load_component(entity: Entity, component_data: Dictionary) -> void:
	var component_type = component_data["type"]
	var data = component_data.get("data", {})
	
	match component_type:
		"GangMemberComponent":
			var component = GangMemberComponent.new()
			component.member_name = data.get("member_name", "")
			component.role = data.get("member_role", GangMemberComponent.ROLE_MEMBER)
			component.loyalty = data.get("loyalty", 50.0)
			component.current_state = data.get("current_state", GangMemberComponent.MemberState.IDLE)
			component.faction_id = data.get("faction_id", "")
			component.time_in_faction = data.get("time_in_faction", 0.0)
			component.personality = data.get("personality", GangMemberComponent.PERSONALITY_LOYAL)
			component.order_progress = data.get("order_progress", 0.0)
			component.order_start_time = data.get("order_start_time", 0.0)
			entity.add_component(component)
		
		"FactionComponent":
			var component = FactionComponent.new()
			component.faction_name = data.get("faction_name", "")
			component.faction_type = data.get("faction_type", FactionComponent.FactionType.CRIMINAL)
			component.funds = data.get("funds", 1000.0)
			component.supplies = data.get("supplies", 100.0)
			component.base_location = data.get("base_location", Vector3.ZERO)
			component.relationships = data.get("relationships", {})
			component.intel = data.get("intel", {})
			entity.add_component(component)
		
		"OrderComponent":
			var component = OrderComponent.new()
			component.target_id = data.get("target_id", "")
			component.parameters = data.get("data", {})
			component.issued_by = data.get("issued_by", "")
			
			# Create order
			component.order = Order.new()
			component.order.order_type = data.get("order_type", Order.OrderType.PATROL_TERRITORY)
			component.order.status = data.get("status", Order.OrderStatus.PENDING)
			component.order.assigned_to = data.get("assigned_to", "")
			component.order.target_id = data.get("target_id", "")
			component.order.data = data.get("data", {})
			component.order.issued_tick = data.get("issued_tick", 0)
			component.order.started_at = data.get("started_at", 0.0)
			component.order.completed_at = data.get("completed_at", 0.0)
			component.order.results = data.get("results", {})
			component.order.travel_time = data.get("travel_time", 5.0)
			component.order.work_time = data.get("work_time", 10.0)
			component.order.return_time = data.get("return_time", 5.0)
			component.order.priority = data.get("priority", 50)
			component.order.required_funds = data.get("required_funds", 0.0)
			component.order.required_supplies = data.get("required_supplies", 0.0)
			component.order.success_chance = data.get("success_chance", 0.8)
			component.order.failure_reason = data.get("failure_reason", "")
			
			entity.add_component(component)
		
		"NPCComponent":
			var component = NPCComponent.new()
			component.npc_name = data.get("npc_name", "")
			component.npc_type = data.get("npc_type", "civilian")
			component.location = data.get("location", Vector3.ZERO)
			component.recruitment_cost = data.get("recruitment_cost", 1000.0)
			component.recruitment_chance = data.get("recruitment_chance", 0.6)
			component.loyalty_requirement = data.get("loyalty_requirement", 50.0)
			component.last_recruitment_attempt = data.get("last_recruitment_attempt", 0)
			component.recruitment_cooldown = data.get("recruitment_cooldown", 24)
			component.is_recruited = data.get("is_recruited", false)
			component.recruited_by = data.get("recruited_by", "")
			component.health = data.get("health", 100.0)
			component.morale = data.get("morale", 75.0)
			component.skills = data.get("skills", {})
			entity.add_component(component)
		
		"TerritoryComponent":
			var component = TerritoryComponent.new()
			component.territory_name = data.get("territory_name", "")
			component.territory_type = data.get("territory_type", "residential")
			component.center_location = data.get("center_location", Vector3.ZERO)
			component.radius = data.get("radius", 50.0)
			component.value = data.get("value", 1000.0)
			component.income_per_hour = data.get("income_per_hour", 100.0)
			component.controlled_by = data.get("controlled_by", "")
			component.control_level = data.get("control_level", 0.0)
			component.last_income_time = data.get("last_income_time", 0.0)
			component.population = data.get("population", 100)
			component.safety_level = data.get("safety_level", 50.0)
			component.corruption_level = data.get("corruption_level", 30.0)
			component.development_level = data.get("development_level", 40.0)
			component.events = data.get("events", [])
			entity.add_component(component)
		
		"BusinessComponent":
			var component = BusinessComponent.new()
			component.business_name = data.get("business_name", "")
			component.business_type = data.get("business_type", "shop")
			component.location = data.get("location", Vector3.ZERO)
			component.value = data.get("value", 5000.0)
			component.income_per_hour = data.get("income_per_hour", 200.0)
			component.controlled_by = data.get("controlled_by", "")
			component.control_level = data.get("control_level", 0.0)
			component.protection_paid = data.get("protection_paid", false)
			component.last_income_time = data.get("last_income_time", 0.0)
			component.reputation = data.get("reputation", 50.0)
			component.customer_satisfaction = data.get("customer_satisfaction", 75.0)
			component.security_level = data.get("security_level", 40.0)
			component.efficiency = data.get("efficiency", 60.0)
			component.is_operational = data.get("is_operational", true)
			component.operational_hours = data.get("operational_hours", {"start": 8, "end": 20})
			component.events = data.get("events", [])
			entity.add_component(component)

func _load_system_states(_systems_data: Dictionary) -> void:
	# System states are restored automatically when entities are loaded
	pass

func _load_world_state(_world_state: Dictionary) -> void:
	# World state is restored automatically
	pass

func get_save_files() -> Array[String]:
	var save_files = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(SAVE_FILE_EXTENSION):
				var save_name = file_name.substr(SAVE_FILE_PREFIX.length())
				save_name = save_name.substr(0, save_name.length() - SAVE_FILE_EXTENSION.length())
				save_files.append(save_name)
			
			file_name = dir.get_next()
	
	return save_files

func delete_save(save_name: String) -> bool:
	if save_name.is_empty():
		return false
	
	var file_path = SAVE_DIR + SAVE_FILE_PREFIX + save_name + SAVE_FILE_EXTENSION
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		Logger.info("Save file deleted", "SaveManager", {"save_name": save_name})
		return true
	
	return false

func get_current_save_name() -> String:
	return current_save_name

func has_current_save() -> bool:
	return not current_save_name.is_empty()
