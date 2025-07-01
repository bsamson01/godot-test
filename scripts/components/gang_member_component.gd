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

func _on_attached(entity: Entity) -> void:
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

func _on_detached(entity: Entity) -> void:
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
				change_state(MemberState.WORKING)
				order_progress = 0.0
				
		MemberState.WORKING:
			if elapsed >= order_comp.work_time:
				# Complete the work
				_complete_order()
				change_state(MemberState.RETURNING)
				order_progress = 0.0
				
		MemberState.RETURNING:
			if elapsed >= order_comp.return_time:
				# Fully complete and return to idle
				current_order = null
				order_progress = 0.0
				change_state(MemberState.IDLE)

func _complete_order() -> void:
	if not current_order:
		return
	
	missions_completed += 1
	
	Logger.info("Order completed by gang member", "GangMember", {
		"member": member_name,
		"order_id": current_order.id
	})
	
	# Emit completion event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_COMPLETED,
			{
				"order_id": current_order.id,
				"member_id": entity.id,
				"faction_id": faction_id
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

# Factory method for creating random gang members
static func create_random() -> Dictionary:
	return {
		"name": _get_random_name(),
		"role": AVAILABLE_ROLES[randi() % AVAILABLE_ROLES.size()],
		"loyalty": randf_range(60, 90),
		"personality": AVAILABLE_PERSONALITIES[randi() % AVAILABLE_PERSONALITIES.size()]
	}

static func _get_random_name() -> String:
	var first_names = ["Ghost", "Snake", "Viper", "Blaze", "Razor", "Shadow", "Storm", "Ace"]
	var last_names = ["Runner", "Blade", "Strike", "Claw", "Fang", "Edge", "Wolf", "Hawk"]
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]