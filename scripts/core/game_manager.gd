# GameManager.gd - Central game management with the new architecture
extends Node
class_name GameManager

# Subsystems
var entity_manager: EntityManager
var event_bus: EventBus
var logger: Logger

# Game state
var is_running: bool = false
var game_time: float = 0.0
var tick_rate: float = 1.0  # Seconds per game tick
var tick_accumulator: float = 0.0
var current_tick: int = 0

# Configuration
var config: Dictionary = {
	"max_factions": 5,
	"starting_funds": 5000.0,
	"starting_supplies": 1000.0,
	"members_per_faction": 3,
	"territories_per_faction": 1,
	"businesses_per_territory": 2
}

# Performance monitoring
var frame_time_budget: float = 0.016  # 60 FPS target
var updates_this_frame: int = 0
var max_updates_per_frame: int = 100

func _ready():
	# Initialize subsystems
	_initialize_subsystems()
	
	# Start game
	_initialize_game_world()
	start_game()

func _initialize_subsystems() -> void:
	# Create entity manager
	entity_manager = EntityManager.new()
	entity_manager.name = "EntityManager"
	add_child(entity_manager)
	Engine.register_singleton("EntityManager", entity_manager)
	
	# Create event bus
	event_bus = EventBus.new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	Engine.register_singleton("EventBus", event_bus)
	
	# Create logger
	logger = Logger.new()
	logger.name = "Logger"
	add_child(logger)
	
	# Subscribe to critical events
	event_bus.subscribe(EventBus.EventType.ENTITY_KILLED, _on_entity_killed)
	event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)
	event_bus.subscribe(EventBus.EventType.DAY_STARTED, _on_day_started)
	
	Logger.info("Game subsystems initialized", "GameManager")

func _initialize_game_world() -> void:
	Logger.info("Initializing game world", "GameManager")
	
	# Create factions
	var faction_names = ["Red Vipers", "Blue Shadows", "Green Dragons", "Black Ravens", "White Wolves"]
	var faction_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.BLACK, Color.WHITE]
	
	for i in range(min(config.max_factions, faction_names.size())):
		_create_faction(faction_names[i], faction_colors[i])
	
	# Set initial relationships
	_initialize_faction_relationships()
	
	Logger.info("Game world initialized", "GameManager", {
		"factions": entity_manager.get_entities_by_type("faction").size(),
		"total_entities": entity_manager.entity_count
	})

func _create_faction(faction_name: String, color: Color) -> Entity:
	# Create faction entity
	var faction_entity = entity_manager.create_entity("faction")
	
	# Add faction component
	var faction_comp = FactionComponent.new()
	faction_comp.faction_name = faction_name
	faction_comp.color = color
	faction_comp.funds = config.starting_funds
	faction_comp.supplies = config.starting_supplies
	faction_entity.add_component(faction_comp)
	
	# Create commander
	var commander = _create_gang_member(faction_entity.id, GangMemberComponent.ROLE_COMMANDER)
	faction_comp.add_member(commander)
	
	# Add commander AI
	var commander_ai = CommanderAIComponent.new()
	commander.add_component(commander_ai)
	
	# Create initial members
	for i in range(config.members_per_faction - 1):
		var member = _create_gang_member(faction_entity.id)
		faction_comp.add_member(member)
	
	# Create territories
	for i in range(config.territories_per_faction):
		var territory = _create_territory(faction_entity.id, faction_name + " Territory " + str(i + 1))
		faction_comp.add_territory(territory)
		
		# Create businesses in territory
		for j in range(config.businesses_per_territory):
			var business = _create_business(territory.id, faction_entity.id)
			faction_comp.add_business(business)
	
	Logger.info("Faction created", "GameManager", {
		"name": faction_name,
		"members": faction_comp.get_members().size(),
		"territories": faction_comp.get_territories().size()
	})
	
	return faction_entity

func _create_gang_member(faction_id: String, role: String = "") -> Entity:
	var member_entity = entity_manager.create_entity("gang_member")
	
	# Generate random member data
	var member_data = GangMemberComponent.create_random()
	
	# Add gang member component
	var member_comp = GangMemberComponent.new()
	member_comp.member_name = member_data.name
	member_comp.role = role if role else member_data.role
	member_comp.loyalty = member_data.loyalty
	member_comp.personality = member_data.personality
	member_comp.faction_id = faction_id
	member_entity.add_component(member_comp)
	
	return member_entity

func _create_territory(faction_id: String, territory_name: String) -> Entity:
	var territory_entity = entity_manager.create_entity("territory")
	
	# Add territory component
	var territory_comp = TerritoryComponent.new()
	territory_comp.territory_name = territory_name
	territory_comp.owner_faction_id = faction_id
	territory_entity.add_component(territory_comp)
	
	return territory_entity

func _create_business(territory_id: String, faction_id: String) -> Entity:
	var business_entity = entity_manager.create_entity("business")
	
	# Add business component
	var business_comp = BusinessComponent.new()
	business_comp.generate_random()
	business_comp.territory_id = territory_id
	business_comp.owner_faction_id = faction_id
	business_entity.add_component(business_comp)
	
	return business_entity

func _initialize_faction_relationships() -> void:
	var factions = entity_manager.get_entities_by_type("faction")
	
	# Set some initial hostile relationships for conflict
	if factions.size() >= 2:
		var faction1_comp = factions[0].get_component("FactionComponent")
		var faction2_comp = factions[1].get_component("FactionComponent")
		
		if faction1_comp and faction2_comp:
			faction1_comp.set_relationship(factions[1].id, FactionComponent.RelationType.HOSTILE)
			faction2_comp.set_relationship(factions[0].id, FactionComponent.RelationType.HOSTILE)

func _process(delta: float) -> void:
	if not is_running:
		return
	
	game_time += delta
	tick_accumulator += delta
	
	# Process ticks
	while tick_accumulator >= tick_rate:
		_process_game_tick()
		tick_accumulator -= tick_rate
	
	# Update components
	_update_components(delta)

func _process_game_tick() -> void:
	current_tick += 1
	
	var time_of_day = "Day" if (current_tick % 24) < 12 else "Night"
	var is_new_day = current_tick % 24 == 0
	
	# Emit tick event
	event_bus.emit_event(EventBus.EventType.TICK_PROCESSED, {
		"tick": current_tick,
		"time_of_day": time_of_day,
		"is_new_day": is_new_day
	})
	
	# Process time-based systems
	_process_businesses(time_of_day)
	_process_faction_supplies()
	
	if is_new_day:
		event_bus.emit_event(EventBus.EventType.DAY_STARTED, {"day": current_tick / 24})

func _update_components(delta: float) -> void:
	var start_time = Time.get_ticks_usec()
	updates_this_frame = 0
	
	# Update all entities with update-able components
	var entities_to_update = entity_manager.get_entities_with_components(["AIComponent", "GangMemberComponent"])
	
	for entity in entities_to_update:
		if updates_this_frame >= max_updates_per_frame:
			break
		
		# Update each component
		for component_name in entity.components:
			var component = entity.components[component_name]
			if component.has_method("update") and component.is_enabled:
				component.update(delta)
				updates_this_frame += 1
		
		# Check frame time budget
		var elapsed = (Time.get_ticks_usec() - start_time) / 1000000.0
		if elapsed > frame_time_budget:
			break

func _process_businesses(time_of_day: String) -> void:
	var businesses = entity_manager.get_entities_with_component("BusinessComponent")
	
	for business_entity in businesses:
		var business_comp = business_entity.get_component("BusinessComponent")
		if not business_comp:
			continue
		
		# Calculate and generate income
		var income = business_comp.calculate_income(time_of_day)
		if income > 0:
			event_bus.emit_event(EventBus.EventType.BUSINESS_INCOME_GENERATED, {
				"business_id": business_entity.id,
				"faction_id": business_comp.owner_faction_id,
				"amount": income,
				"source": business_comp.business_name
			})

func _process_faction_supplies() -> void:
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if not faction_comp:
			continue
		
		# Calculate and consume supplies
		var consumption = faction_comp.calculate_supply_consumption()
		faction_comp.consume_supplies(consumption)

func start_game() -> void:
	is_running = true
	Logger.info("Game started", "GameManager")

func pause_game() -> void:
	is_running = false
	Logger.info("Game paused", "GameManager")

func stop_game() -> void:
	is_running = false
	
	# Clean up all entities
	var all_entities = entity_manager.entities.values()
	for entity in all_entities:
		entity_manager.mark_for_destruction(entity)
	
	Logger.info("Game stopped", "GameManager")

# Event handlers
func _on_entity_killed(event: EventBus.Event) -> void:
	var entity_id = event.data.get("entity_id")
	var entity_type = event.data.get("entity_type")
	
	if entity_type == "gang_member":
		# Handle member death
		var member_entity = entity_manager.get_entity(entity_id)
		if member_entity:
			entity_manager.mark_for_destruction(member_entity)

func _on_order_completed(event: EventBus.Event) -> void:
	var order_id = event.data.get("order_id")
	var order_entity = entity_manager.get_entity(order_id)
	
	if order_entity:
		var order_comp = order_entity.get_component("OrderComponent")
		if order_comp and order_comp.order_type == OrderComponent.OrderType.RECRUIT:
			# Create new member for the faction
			var faction_id = event.data.get("faction_id")
			var new_member = _create_gang_member(faction_id)
			
			var faction_entity = entity_manager.get_entity(faction_id)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					faction_comp.add_member(new_member)
					
					Logger.info("New member recruited", "GameManager", {
						"faction": faction_comp.faction_name,
						"member": new_member.get_component("GangMemberComponent").member_name
					})

func _on_day_started(event: EventBus.Event) -> void:
	# Reset daily counters
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			faction_comp.reset_period_stats()
	
	# Reset commander daily order counts
	var commanders = entity_manager.get_entities_with_component("CommanderAIComponent")
	for commander_entity in commanders:
		var ai_comp = commander_entity.get_component("CommanderAIComponent")
		if ai_comp:
			ai_comp.orders_issued_today = 0
	
	_print_daily_report(event.data.get("day", 0))

func _print_daily_report(day: int) -> void:
	Logger.info("=== DAILY REPORT - Day %d ===" % day, "GameManager")
	
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if not faction_comp:
			continue
		
		var summary = faction_comp.get_financial_summary()
		Logger.info("Faction: %s" % faction_comp.faction_name, "GameManager", summary)
		
		# Print member status
		var member_stats = []
		for member_entity in faction_comp.get_members():
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp:
				member_stats.append(member_comp.get_stats())
		
		Logger.info("Members: %d" % member_stats.size(), "GameManager", {"members": member_stats})

func get_game_stats() -> Dictionary:
	return {
		"game_time": game_time,
		"current_tick": current_tick,
		"is_running": is_running,
		"entity_count": entity_manager.entity_count,
		"entity_stats": entity_manager.get_stats(),
		"event_stats": event_bus.get_stats(),
		"performance": {
			"updates_per_frame": updates_this_frame,
			"max_updates": max_updates_per_frame
		}
	}
