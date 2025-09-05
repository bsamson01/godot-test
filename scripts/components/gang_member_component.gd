# GangMemberComponent.gd - Component for gang member data and behavior
extends Component
class_name GangMemberComponent

@export var member_name: String = ""
@export var role: String = ""
@export var loyalty: float = 75.0
@export var personality: String = ""
@export var faction_id: String = ""

# State management
enum MemberState {
	IDLE,
	TRAVELING,
	WORKING,
	RETURNING,
	INJURED,
	DEAD
}

@export var current_state: MemberState = MemberState.IDLE
var previous_state: MemberState = MemberState.IDLE
var state_start_time: float = 0.0

# Order management
var current_order: Entity = null  # Order entity
var order_progress: float = 0.0
var order_start_time: float = 0.0

# Stats
var missions_completed: int = 0
var missions_failed: int = 0
var time_in_faction: float = 0.0

# Roles
const ROLE_COMMANDER = "Commander"
const ROLE_ENFORCER = "Enforcer"
const ROLE_SPY = "Spy"
const ROLE_HACKER = "Hacker"
const ROLE_LIEUTENANT = "Lieutenant"
const ROLE_SNIPER = "Sniper"

const AVAILABLE_ROLES = [ROLE_ENFORCER, ROLE_SPY, ROLE_HACKER, ROLE_LIEUTENANT, ROLE_SNIPER]

# Personalities
const PERSONALITY_LOYAL = "Loyal"
const PERSONALITY_GREEDY = "Greedy"
const PERSONALITY_PARANOID = "Paranoid"
const PERSONALITY_AMBITIOUS = "Ambitious"

const AVAILABLE_PERSONALITIES = [PERSONALITY_LOYAL, PERSONALITY_GREEDY, PERSONALITY_PARANOID, PERSONALITY_AMBITIOUS]

func get_component_name() -> String:
	return "GangMemberComponent"

func _on_attached(_entity: Entity) -> void:
	# Validate initial state
	var result = validate()
	if not result.is_valid:
		Logger.error("Invalid gang member component attached: " + result.to_string(), "GangMember")
	
	# Subscribe to events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)
		event_bus.subscribe(EventBus.EventType.ORDER_FAILED, _on_order_failed)
		event_bus.subscribe(EventBus.EventType.ORDER_CANCELLED, _on_order_cancelled)

func _on_detached(_entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)
		event_bus.unsubscribe(EventBus.EventType.ORDER_FAILED, _on_order_failed)
		event_bus.unsubscribe(EventBus.EventType.ORDER_CANCELLED, _on_order_cancelled)

func update(delta: float) -> void:
	if not is_enabled:
		return
	
	time_in_faction += delta
	
	# Update order progress based on state
	if current_order and current_state in [MemberState.TRAVELING, MemberState.WORKING, MemberState.RETURNING]:
		order_progress += delta
		_check_order_progress()

func change_state(new_state: MemberState) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	state_start_time = Time.get_ticks_msec() / 1000.0
	
	Logger.debug("Gang member state changed", "GangMember", {
		"member": member_name,
		"from": MemberState.keys()[previous_state],
		"to": MemberState.keys()[new_state]
	})
	
	# Emit state change event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ENTITY_STATE_CHANGED,
			{
				"entity_id": entity.id,
				"old_state": previous_state,
				"new_state": new_state,
				"component": "GangMemberComponent"
			}
		)
	
	# Emit movement event for visual updates
	_emit_movement_event(new_state)

func is_available() -> bool:
	return current_state == MemberState.IDLE and current_order == null

func assign_order(order_entity: Entity) -> bool:
	if not is_available():
		Logger.warning("Cannot assign order to busy member", "GangMember", {
			"member": member_name,
			"state": MemberState.keys()[current_state]
		})
		return false
	
	var order_comp = order_entity.get_component("OrderComponent")
	if not order_comp:
		Logger.error("Order entity missing OrderComponent", "GangMember")
		return false
	
	current_order = order_entity
	order_progress = 0.0
	order_start_time = Time.get_ticks_msec() / 1000.0
	
	# Change state based on order type
	change_state(MemberState.TRAVELING)
	
	Logger.info("Order assigned to gang member", "GangMember", {
		"member": member_name,
		"order_type": order_comp.order_type,
		"order_id": order_entity.id
	})
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_ASSIGNED,
			{
				"order_id": order_entity.id,
				"member_id": entity.id,
				"faction_id": faction_id
			}
		)
	
	return true

func cancel_order(reason: String = "") -> void:
	if not current_order:
		return
	
	Logger.info("Order cancelled for gang member", "GangMember", {
		"member": member_name,
		"reason": reason
	})
	
	var order_id = current_order.id
	current_order = null
	order_progress = 0.0
	change_state(MemberState.IDLE)
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_CANCELLED,
			{
				"order_id": order_id,
				"member_id": entity.id,
				"reason": reason
			}
		)

func injure(severity: float = 0.5) -> void:
	if current_state == MemberState.DEAD:
		return
	
	change_state(MemberState.INJURED)
	
	# Reduce loyalty when injured
	loyalty = max(0, loyalty - severity * 10)
	
	Logger.info("Gang member injured", "GangMember", {
		"member": member_name,
		"severity": severity,
		"new_loyalty": loyalty
	})

func kill() -> void:
	change_state(MemberState.DEAD)
	
	if current_order:
		cancel_order("Member killed")
	
	Logger.info("Gang member killed", "GangMember", {
		"member": member_name,
		"faction": faction_id
	})
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ENTITY_KILLED,
			{
				"entity_id": entity.id,
				"entity_type": "gang_member",
				"faction_id": faction_id
			}
		)

func modify_loyalty(amount: float, reason: String = "") -> void:
	var old_loyalty = loyalty
	loyalty = clamp(loyalty + amount, 0, 100)
	
	if loyalty == 0 and old_loyalty > 0:
		Logger.warning("Gang member loyalty reached zero", "GangMember", {
			"member": member_name,
			"reason": reason
		})
		# Could trigger betrayal or desertion

func get_efficiency() -> float:
	# Calculate efficiency based on loyalty and state
	var base_efficiency = 1.0
	
	# Loyalty affects efficiency
	base_efficiency *= (loyalty / 100.0)
	
	# State affects efficiency
	match current_state:
		MemberState.INJURED:
			base_efficiency *= 0.5
		MemberState.DEAD:
			base_efficiency = 0.0
	
	# Role-based modifiers
	match role:
		ROLE_COMMANDER:
			base_efficiency *= 1.2
		ROLE_LIEUTENANT:
			base_efficiency *= 1.1
	
	return clamp(base_efficiency, 0.0, 2.0)

func _check_order_progress() -> void:
	if not current_order:
		return
	
	var order_comp = current_order.get_component("OrderComponent")
	if not order_comp:
		return
	
	var elapsed = order_progress
	
	match current_state:
		MemberState.TRAVELING:
			if elapsed >= order_comp.travel_time:
				# Start working and execute the order
				Logger.debug("Order progress: Travel complete, starting work", "GangMember", {
					"member": member_name,
					"elapsed": elapsed,
					"required": order_comp.travel_time
				})
				change_state(MemberState.WORKING)
				order_progress = 0.0
				# Execute the order when we start working
				_execute_order()
				
		MemberState.WORKING:
			if elapsed >= order_comp.work_time:
				# Complete the work
				Logger.debug("Order progress: Work complete, starting return", "GangMember", {
					"member": member_name,
					"elapsed": elapsed,
					"required": order_comp.work_time
				})
				_complete_order()
				change_state(MemberState.RETURNING)
				order_progress = 0.0
				
		MemberState.RETURNING:
			if elapsed >= order_comp.return_time:
				# Fully complete and return to idle
				Logger.debug("Order progress: Return complete, order finished", "GangMember", {
					"member": member_name,
					"elapsed": elapsed,
					"required": order_comp.return_time
				})
				current_order = null
				order_progress = 0.0
				change_state(MemberState.IDLE)

func _execute_order() -> void:
	if not current_order:
		return
	
	var order_comp = current_order.get_component("OrderComponent")
	if not order_comp:
		return
	
	# Execute the order
	var success = order_comp.execute(entity)
	if not success:
		Logger.warning("Order execution failed", "GangMember", {
			"member": member_name,
			"order_id": current_order.id,
			"reason": order_comp.failure_reason
		})
		# Cancel the order if execution failed
		cancel_order("Execution failed: " + order_comp.failure_reason)
		return
	
	Logger.info("Order execution started", "GangMember", {
		"member": member_name,
		"order_id": current_order.id,
		"order_type": order_comp.order_type
	})

func _complete_order() -> void:
	if not current_order:
		return
	
	var order_comp = current_order.get_component("OrderComponent")
	if not order_comp:
		return
	
	# Complete the order and get results
	var result = order_comp.complete(entity)
	
	if result.get("success", false):
		missions_completed += 1
		Logger.info("Order completed successfully by gang member", "GangMember", {
			"member": member_name,
			"order_id": current_order.id,
			"effects": result
		})
	else:
		missions_failed += 1
		Logger.info("Order failed", "GangMember", {
			"member": member_name,
			"order_id": current_order.id,
			"reason": result.get("reason", "Unknown")
		})
	
	# Emit completion event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_COMPLETED,
			{
				"order_id": current_order.id,
				"member_id": entity.id,
				"faction_id": faction_id,
				"success": result.get("success", false)
			},
			10  # Higher priority
		)

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(member_name, "member_name", result)
	Validatable.validate_not_empty(role, "role", result)
	Validatable.validate_in_range(loyalty, 0, 100, "loyalty", result)
	
	if not role in (AVAILABLE_ROLES + [ROLE_COMMANDER]):
		result.add_error("Invalid role: " + role)
	
	if not personality.is_empty() and not personality in AVAILABLE_PERSONALITIES:
		result.add_warning("Unknown personality: " + personality)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": member_name,
		"role": role,
		"state": MemberState.keys()[current_state],
		"loyalty": loyalty,
		"personality": personality,
		"efficiency": get_efficiency(),
		"missions_completed": missions_completed,
		"missions_failed": missions_failed,
		"time_in_faction": time_in_faction,
		"has_order": current_order != null
	}

func _emit_movement_event(state: MemberState) -> void:
	if not Engine.has_singleton("EventBus"):
		return
	
	var target_location = Vector3.ZERO
	var movement_type = "idle"
	
	# Determine target location based on state and order
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			match order_comp.order_type:
				OrderComponent.OrderType.BUY_SUPPLIES:
					# Move to shop location
					target_location = _get_shop_location()
					movement_type = "travel_to_shop"
				OrderComponent.OrderType.RECRUIT:
					# Move to recruitment area
					target_location = _get_recruitment_location()
					movement_type = "travel_to_recruit"
				OrderComponent.OrderType.PATROL:
					# Move to patrol area
					target_location = _get_patrol_location()
					movement_type = "travel_to_patrol"
				_:
					# Default to base location
					target_location = _get_base_location()
					movement_type = "travel_to_base"
	else:
		# Return to base when idle
		target_location = _get_base_location()
		movement_type = "return_to_base"
	
	# Emit movement event
	var event_bus = Engine.get_singleton("EventBus")
	if event_bus:
		event_bus.emit_event(
			EventBus.EventType.ENTITY_MOVEMENT,
			{
				"entity_id": entity.id,
				"member_name": member_name,
				"target_location": target_location,
				"movement_type": movement_type,
				"state": MemberState.keys()[state]
			}
		)

func _get_base_location() -> Vector3:
	# Get faction base location
	var faction_entity = _get_faction_entity()
	if faction_entity:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			return faction_comp.base_location
	return Vector3.ZERO

func _get_shop_location() -> Vector3:
	# Find nearest shop
	var shops = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("shop")
	if shops.size() > 0:
		return shops[0].global_position
	return Vector3(0, 0, 25)  # Default shop location (25m away)

func _get_recruitment_location() -> Vector3:
	# Find a random NPC to recruit
	var npcs = _get_available_npcs()
	if npcs.size() > 0:
		var target_npc = npcs[randi() % npcs.size()]
		var npc_comp = target_npc.get_component("NPCComponent")
		if npc_comp:
			return npc_comp.location
	
	# Fallback to random location if no NPCs available
	return Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))

func _get_available_npcs() -> Array:
	# Get all NPCs that can be recruited
	var available_npcs = []
	
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var npcs = entity_manager.get_entities_with_component("NPCComponent")
		
		for npc_entity in npcs:
			var npc_comp = npc_entity.get_component("NPCComponent")
			if npc_comp and npc_comp.can_be_recruited(int(Time.get_ticks_msec() / 1000.0 / 60.0)):  # Rough day calculation
				available_npcs.append(npc_entity)
	
	return available_npcs

func _get_patrol_location() -> Vector3:
	# Get faction business location for patrol
	var faction_entity = _get_faction_entity()
	if faction_entity:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			# Find a business owned by this faction
			var business_nodes = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("business")
			for node in business_nodes:
				if node.get_meta("owner", "") == faction_entity.id:
					# Add random offset around the business for patrol variation
					var business_pos = node.global_position
					return business_pos + Vector3(
						randf_range(-5, 5),
						0,
						randf_range(-5, 5)
					)
	
	# Fallback: random location near base
	var base_location = _get_base_location()
	if base_location != Vector3.ZERO:
		return base_location + Vector3(
			randf_range(-10, 10),
			0,
			randf_range(-10, 10)
		)
	
	# Final fallback: random location
	return Vector3(randf_range(-25, 25), 0, randf_range(-25, 25))

func _get_faction_entity() -> Entity:
	if Engine.has_singleton("EntityManager"):
		return Engine.get_singleton("EntityManager").get_entity(faction_id)
	return null

# Event handlers
func _on_order_completed(event: EventBus.Event) -> void:
	if event.data.get("member_id") == entity.id:
		# Could add loyalty bonus for successful missions
		modify_loyalty(randf_range(1, 3), "Mission success")

func _on_order_failed(event: EventBus.Event) -> void:
	if event.data.get("member_id") == entity.id:
		missions_failed += 1
		modify_loyalty(randf_range(-5, -2), "Mission failure")

func _on_order_cancelled(event: EventBus.Event) -> void:
	if event.data.get("member_id") == entity.id:
		# Handle any cleanup if needed
		pass

# Static factory method for creating random members
static func create_random(existing_names: Array = []) -> Dictionary:
	var names = ["Ghost", "Snake", "Viper", "Blaze", "Razor", "Shadow", "Steel", "Flame", 
				"Storm", "Ace", "Blade", "Fang", "Claw", "Edge", "Wolf", "Hawk", "Fox",
				"Lynx", "Bear", "Tiger", "Lion", "Eagle", "Falcon", "Raven", "Crow",
				"Phoenix", "Dragon", "Viper", "Cobra", "Python", "Scorpion", "Spider"]
	var roles = AVAILABLE_ROLES
	var personalities = AVAILABLE_PERSONALITIES
	
	# Filter out existing names to prevent duplicates
	var available_names = []
	for name in names:
		if not name in existing_names:
			available_names.append(name)
	
	# If all names are taken, add numbers to make them unique
	var selected_name = ""
	if available_names.size() > 0:
		selected_name = available_names[randi() % available_names.size()]
	else:
		# Fallback: use a random name with a number
		selected_name = names[randi() % names.size()] + str(randi() % 1000)
	
	return {
		"name": selected_name,
		"role": roles[randi() % roles.size()],
		"loyalty": randf_range(70, 100),
		"personality": personalities[randi() % personalities.size()]
	}

static func _get_random_name() -> String:
	var first_names = ["Ghost", "Snake", "Viper", "Blaze", "Razor", "Shadow", "Storm", "Ace"]
	var last_names = ["Runner", "Blade", "Strike", "Claw", "Fang", "Edge", "Wolf", "Hawk"]
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]
