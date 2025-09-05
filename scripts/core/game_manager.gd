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
var tick_rate: float = 0.1  # Seconds per game tick (10x faster)
var tick_accumulator: float = 0.0
var current_tick: int = 0

# Configuration
var config: Dictionary = {
	"max_factions": 1,
	"starting_funds": 5000.0,
	"starting_supplies": 1000.0,
	"members_per_faction": 4,
	"territories_per_faction": 1,
	"businesses_per_territory": 1,
	"spawn_radius_min": 5.0,
	"spawn_radius_max": 15.0,
	"min_distance_between_members": 2.0,
	"max_spawn_attempts": 20
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
	
	# Faction creation is now handled by Init.gd
	# This allows for more flexible initialization with visual nodes
	
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
	# Temporarily commented out due to parser error
	# var commander_ai = CommanderAIComponent.new()
	# commander.add_component(commander_ai)
	
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
	
	# Get existing member names in this faction to avoid duplicates
	var existing_names = _get_faction_member_names(faction_id)
	
	# Generate random member data
	var member_data = GangMemberComponent.create_random(existing_names)
	
	# Add gang member component
	var member_comp = GangMemberComponent.new()
	member_comp.member_name = member_data.name
	member_comp.role = role if role else member_data.role
	member_comp.loyalty = member_data.loyalty
	member_comp.personality = member_data.personality
	member_comp.faction_id = faction_id
	member_entity.add_component(member_comp)
	
	return member_entity

func _get_faction_member_names(faction_id: String) -> Array:
	var existing_names = []
	var faction_entity = entity_manager.get_entity(faction_id)
	if faction_entity:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			for member_entity in faction_comp.get_members():
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					existing_names.append(member_comp.member_name)
	return existing_names

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
	_process_npcs()
	
	if is_new_day:
		# Reset period stats for all factions
		var factions = entity_manager.get_entities_with_component("FactionComponent")
		for faction_entity in factions:
			var faction_comp = faction_entity.get_component("FactionComponent")
			if faction_comp:
				faction_comp.reset_period_stats()
		
		# Generate new NPCs every 10 days
		var current_day = int(current_tick / 24.0)
		if current_day > 0 and current_day % 10 == 0:
			_generate_npc()
		
		event_bus.emit_event(EventBus.EventType.DAY_STARTED, {"day": current_tick / 24.0})

func _update_components(delta: float) -> void:
	var start_time = Time.get_ticks_usec()
	updates_this_frame = 0
	
	# Update all entities with AI components (both base AIComponent and CommanderAIComponent)
	var entities_to_update = entity_manager.get_entities_with_component("AIComponent")
	var commander_entities = entity_manager.get_entities_with_component("CommanderAIComponent")
	var gang_member_entities = entity_manager.get_entities_with_component("GangMemberComponent")
	
	# Combine all lists and remove duplicates
	for entity in commander_entities:
		if not entities_to_update.has(entity):
			entities_to_update.append(entity)
	
	for entity in gang_member_entities:
		if not entities_to_update.has(entity):
			entities_to_update.append(entity)
	
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
	
	# Debug: Log business count
	if businesses.size() == 0:
		Logger.warning("No businesses found for income generation", "GameManager")
		return
	
	Logger.debug("Processing %d businesses for income generation" % businesses.size(), "GameManager")
	
	for business_entity in businesses:
		var business_comp = business_entity.get_component("BusinessComponent")
		if not business_comp:
			continue
		
		# Calculate and generate income
		var income = business_comp.calculate_income(time_of_day)
		
		# Debug: Log business income calculation
		Logger.debug("Business income calculation", "GameManager", {
			"business_name": business_comp.business_name,
			"business_type": business_comp.business_type,
			"base_income": business_comp.base_income,
			"operational": business_comp.operational,
			"damage_level": business_comp.damage_level,
			"time_of_day": time_of_day,
			"calculated_income": income
		})
		
		if income > 0:
			# Add income to faction funds
			var faction_entity = entity_manager.get_entity(business_comp.owner_faction_id)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					faction_comp.add_funds(income, "Business income: " + business_comp.business_name)
					Logger.info("Business income added to faction", "GameManager", {
						"business": business_comp.business_name,
						"faction": faction_comp.faction_name,
						"amount": income,
						"new_funds": faction_comp.funds
					})
			else:
				Logger.warning("Faction not found for business income", "GameManager", {
					"business": business_comp.business_name,
					"faction_id": business_comp.owner_faction_id
				})
			
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
					
					# Create visual node for the new member
					_create_gang_member_visual_node(new_member, faction_comp.base_location, faction_comp.color)
					
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

func _create_gang_member_visual_node(member_entity: Entity, base_location: Vector3, faction_color: Color):
	# Get the gang member component
	var member_comp = member_entity.get_component("GangMemberComponent")
	if not member_comp:
		Logger.error("Gang member entity missing GangMemberComponent", "GameManager")
		return
	
	# Create visual node using the existing player scene
	var member_scene = preload("res://test/player.tscn")
	var member_node = member_scene.instantiate()
	
	# Find a good spawn position using improved algorithm
	var spawn_pos = _find_optimal_spawn_position(base_location, member_entity.id)
	member_node.position = spawn_pos
	
	# Character scale is now properly set in the scene files
	# No need for additional scaling
	
	# Debug: Print spawn position
	Logger.info("Spawning gang member at position: %s" % spawn_pos, "GameManager")
	
	# Add to the World Node3D - GameManager is a child of World
	var world_scene = get_parent()  # This should be the World Node3D
	if world_scene and world_scene is Node3D:
		world_scene.add_child(member_node)
		Logger.info("Added gang member to World scene: %s" % world_scene.name, "GameManager")
	else:
		# Fallback: try to get the main scene using Engine
		var main_scene = Engine.get_main_loop().get_root()
		if main_scene:
			main_scene.add_child(member_node)
			Logger.info("Added gang member to main scene: %s" % main_scene.name, "GameManager")
		else:
			Logger.error("Could not find World scene to add gang member", "GameManager")
			return
	
	# Set member reference
	member_node.member_id = member_entity.id
	
	# Add to gang members group
	member_node.add_to_group("gang_members")
	
	# Set faction color
	if member_node.has_node("MeshInstance3D"):
		var mesh = member_node.get_node("MeshInstance3D")
		if mesh and mesh.get_surface_override_material_count() > 0:
			var material = mesh.get_surface_override_material(0)
			if material:
				material.albedo_color = faction_color
				Logger.info("Set faction color for gang member: %s" % faction_color, "GameManager")
			else:
				Logger.warning("Gang member mesh has no material", "GameManager")
		else:
			Logger.warning("Gang member mesh has no surface material overrides", "GameManager")
		# Debug mesh properties
		Logger.info("Gang member mesh scale: %s, visible: %s" % [mesh.scale, mesh.visible], "GameManager")
	else:
		Logger.warning("Gang member node missing MeshInstance3D", "GameManager")
	
	# WorldState is disabled - using ECS system instead
	# No need to register with legacy WorldState
	
	# Debug: Check if node is visible
	Logger.info("Created visual node for gang member: %s at %s (visible: %s)" % [
		member_comp.member_name, 
		member_node.position, 
		member_node.visible
	], "GameManager")

func _find_optimal_spawn_position(base_location: Vector3, _member_id: String) -> Vector3:
	# Get configuration for spawn behavior
	var spawn_radius_min = config.get("spawn_radius_min", 2.0)
	var spawn_radius_max = config.get("spawn_radius_max", 8.0)
	var max_attempts = config.get("max_spawn_attempts", 20)
	var min_distance_between_members = config.get("min_distance_between_members", 1.5)
	
	# Get existing member positions to avoid collisions
	var existing_positions = _get_existing_member_positions()
	
	# Try to find a good spawn position
	for attempt in range(max_attempts):
		# Generate position using circular distribution
		var angle = randf() * 2 * PI
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var candidate_pos = base_location + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		# Check for ground level using raycast
		var ground_pos = _find_ground_level(candidate_pos)
		if ground_pos != Vector3.ZERO:
			candidate_pos = ground_pos
		
		# Check if position is clear of other members
		if _is_position_clear(candidate_pos, existing_positions, min_distance_between_members):
			Logger.info("Found optimal spawn position after %d attempts" % (attempt + 1), "GameManager")
			return candidate_pos
	
	# Fallback: spawn near base with small random offset
	var fallback_pos = base_location + Vector3(
		randf_range(-2, 2),
		0,
		randf_range(-2, 2)
	)
	Logger.warning("Using fallback spawn position after %d failed attempts" % max_attempts, "GameManager")
	return fallback_pos

func _get_existing_member_positions() -> Array:
	var positions = []
	
	# Check if we're in the scene tree
	if not is_inside_tree():
		return positions
	
	var gang_members = get_tree().get_nodes_in_group("gang_members")
	for member in gang_members:
		if member.has_method("get_global_position"):
			positions.append(member.get_global_position())
		elif member.has_method("get_position"):
			positions.append(member.get_position())
	return positions

func _is_position_clear(candidate_pos: Vector3, existing_positions: Array, min_distance: float) -> bool:
	for existing_pos in existing_positions:
		if candidate_pos.distance_to(existing_pos) < min_distance:
			return false
	return true

func _find_ground_level(candidate_pos: Vector3) -> Vector3:
	# Check if we have access to the viewport and world
	if not is_inside_tree():
		return candidate_pos
	
	var viewport = get_viewport()
	if not viewport:
		return candidate_pos
	
	var world_3d = viewport.get_world_3d()
	if not world_3d:
		return candidate_pos
	
	# Use raycast to find ground level
	var space_state = world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		candidate_pos + Vector3(0, 10, 0),  # Start 10 units above
		candidate_pos + Vector3(0, -10, 0)  # End 10 units below
	)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		# No ground found, return original position
		return candidate_pos

func _process_npcs() -> void:
	# Process NPCs (currently just placeholder for future NPC behavior)
	var npcs = entity_manager.get_entities_with_component("NPCComponent")
	for npc_entity in npcs:
		var npc_comp = npc_entity.get_component("NPCComponent")
		if npc_comp:
			# Future: Add NPC wandering behavior here
			pass

func _generate_npc() -> void:
	# Create a new NPC entity
	var npc_entity = entity_manager.create_entity("npc_" + str(randi() % 1000000))
	var npc_comp = preload("res://scripts/components/npc_component.gd").new()
	
	# Generate NPC data
	npc_comp.npc_id = "npc_" + str(randi() % 1000000)
	npc_comp.npc_name = _generate_npc_name()
	npc_comp.spawn_day = int(current_tick / 24.0)
	npc_comp.recruitment_chance = randf_range(0.2, 0.5)  # 20-50% recruitment chance
	
	# Find a spawn position
	var spawn_pos = _find_npc_spawn_position()
	npc_comp.location = spawn_pos
	
	# Add component to entity
	npc_entity.add_component(npc_comp)
	
	# Create visual node for the NPC
	_create_npc_visual_node(npc_entity, spawn_pos)
	
	Logger.info("NPC Generated: " + str({
		"npc_id": npc_comp.npc_id,
		"npc_name": npc_comp.npc_name,
		"spawn_day": npc_comp.spawn_day,
		"recruitment_chance": npc_comp.recruitment_chance,
		"location": spawn_pos
	}))

func _generate_npc_name() -> String:
	var names = [
		"Shadow", "Blade", "Raven", "Ghost", "Viper", "Fang", "Storm", "Thunder",
		"Frost", "Ember", "Crystal", "Steel", "Iron", "Copper", "Silver", "Gold",
		"Phoenix", "Dragon", "Tiger", "Wolf", "Eagle", "Hawk", "Falcon", "Crow",
		"Fox", "Bear", "Lion", "Panther", "Jaguar", "Leopard", "Cheetah", "Lynx"
	]
	return names[randi() % names.size()]

func _find_npc_spawn_position() -> Vector3:
	# Find a random position away from existing faction members
	var base_location = Vector3.ZERO
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	if factions.size() > 0:
		var faction_comp = factions[0].get_component("FactionComponent")
		if faction_comp:
			base_location = faction_comp.base_location
	
	# Spawn NPCs further away from the base
	var angle = randf() * 2 * PI
	var distance = randf_range(20.0, 40.0)  # 20-40 units from base
	var candidate_pos = base_location + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	
	# Find ground level
	return _find_ground_level(candidate_pos)

func _create_npc_visual_node(npc_entity: Entity, spawn_pos: Vector3) -> void:
	# Load the NPC scene (reuse player scene for now)
	var npc_scene = preload("res://test/player.tscn")
	var npc_node = npc_scene.instantiate()
	
	# Set NPC-specific properties before adding to tree
	npc_node.name = "NPC_" + npc_entity.id
	
	# Add to world scene first
	var world_scene = get_node("/root/World")
	if world_scene:
		world_scene.add_child(npc_node)
		
		# Now set position and material after node is in tree
		npc_node.global_position = spawn_pos
		
		# Set NPC color (gray)
		var mesh_instance = npc_node.get_node("MeshInstance3D")
		if mesh_instance:
			var material = mesh_instance.get_surface_override_material(0)
			if material:
				material.albedo_color = Color(0.5, 0.5, 0.5, 1.0)  # Gray color for NPCs
		
		# Register with WorldState for compatibility
		if Engine.has_singleton("WorldState"):
			var world_state = Engine.get_singleton("WorldState")
			world_state.register_gang_member_node(npc_node)
	
	Logger.info("NPC Visual Node Created: " + str({
		"npc_id": npc_entity.id,
		"position": spawn_pos,
		"visible": npc_node.visible
	}))

func get_game_stats() -> Dictionary:
	return {
		"game_time": game_time,
		"current_tick": current_tick,
		"is_running": is_running,
		"entity_count": entity_manager.entity_count,
		"entity_stats": entity_manager.get_stats(),
		"event_stats": event_bus.get_stats(),
		"faction_count": entity_manager.get_entities_with_component("FactionComponent").size(),
		"gang_member_count": entity_manager.get_entities_with_component("GangMemberComponent").size(),
		"business_count": entity_manager.get_entities_with_component("BusinessComponent").size(),
		"npc_count": entity_manager.get_entities_with_component("NPCComponent").size(),
		"performance": {
			"updates_per_frame": updates_this_frame,
			"max_updates": max_updates_per_frame
		}
	}
