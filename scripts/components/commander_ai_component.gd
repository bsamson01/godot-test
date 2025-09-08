# CommanderAIComponent.gd - AI for faction commanders
extends AIComponent
class_name CommanderAIComponent

# Order queue management
var order_queue: Array = []
var max_queue_size: int = 10
var orders_issued_today: int = 0

# Goal tracking
var completed_goals: Dictionary = {} # goal_name -> completion_time
var goal_cooldowns: Dictionary = {
	"emergency_supplies": 30.0,  # 30 seconds before re-evaluating
	"maintain_supplies": 60.0,   # 60 seconds
	"recruit_members": 120.0,    # 2 minutes
	"defend_territory": 45.0,    # 45 seconds
	"gather_intel": 180.0,       # 3 minutes
	"expand_territory": 300.0,   # 5 minutes
	"improve_relations": 240.0,  # 4 minutes
	"patrol_territories": 90.0   # 90 seconds
}
var pending_orders_by_goal: Dictionary = {} # goal_name -> order_count

# Strategic thresholds
const MIN_FUNDS_FOR_OPERATIONS = 500.0
const MIN_SUPPLIES_FOR_OPERATIONS = 200.0
const CRITICAL_SUPPLIES = 100.0
const CRITICAL_FUNDS = 200.0

# Goal weights
var goal_weights: Dictionary = {
	"maintain_supplies": 1.0,
	"expand_territory": 0.8,
	"gather_intel": 0.6,
	"improve_relations": 0.5,
	"recruit_members": 0.7
}

func get_component_name() -> String:
	return "CommanderAIComponent"

func _ready():
	ai_type = "commander"
	decision_interval = 5.0  # Commanders think less frequently but more deeply
	
	# Subscribe to order completion events to track goal progress
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed_event)

func _update_cached_state() -> void:
	# Get the gang member component to access faction_id
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		Logger.error("Commander AI missing gang member component", "AI")
		return
	
	var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
	if not entity_manager:
		return
	
	# Find the faction entity using the faction_id
	var faction_entity = entity_manager.get_entity(member_comp.faction_id)
	if not faction_entity:
		Logger.error("Commander AI could not find faction entity: " + member_comp.faction_id, "AI")
		return
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		Logger.error("Commander AI faction entity missing faction component", "AI")
		return
	
	# Cache faction state
	cached_state = {
		"funds": faction_comp.funds,
		"supplies": faction_comp.supplies,
		"member_count": faction_comp.get_members().size(),
		"territory_count": faction_comp.get_territories().size(),
		"business_count": faction_comp.get_businesses().size(),
		"relationships": faction_comp.relationships.duplicate(),
		"intel": faction_comp.intel.duplicate(),
		"supply_consumption": faction_comp.calculate_supply_consumption()
	}
	
	# Cache member availability
	var available_members = 0
	var busy_members = 0
	for member_entity in faction_comp.get_members():
		var member_comp_check = member_entity.get_component("GangMemberComponent")
		if member_comp_check:
			if member_comp_check.is_available():
				available_members += 1
			else:
				busy_members += 1
	
	cached_state["available_members"] = available_members
	cached_state["busy_members"] = busy_members
	
	# Cache threats and opportunities
	var threats = []
	var opportunities = []
	
	# Analyze other factions
	var all_factions = entity_manager.get_entities_by_type("faction")
	for other_faction in all_factions:
		if other_faction.id == entity.id:
			continue
		
		var other_comp = other_faction.get_component("FactionComponent")
		if not other_comp:
			continue
		
		var relationship = faction_comp.get_relationship(other_faction.id)
		
		if relationship == FactionComponent.RelationType.HOSTILE:
			threats.append({
				"faction_id": other_faction.id,
				"strength": other_comp.get_members().size(),
				"funds": other_comp.funds
			})
		elif relationship == FactionComponent.RelationType.NEUTRAL:
			opportunities.append({
				"faction_id": other_faction.id,
				"potential": "alliance"
			})
	
	cached_state["threats"] = threats
	cached_state["opportunities"] = opportunities
	
	cache_valid_until = Time.get_ticks_msec() / 1000.0 + 10.0  # Cache for 10 seconds

func _think() -> void:
	# Get current world state
	var world_state = _gather_world_state()
	
	# Debug logging
	Logger.debug("Commander AI thinking", "AI", {
		"commander": entity.id,
		"supplies": world_state.get("supplies", 0),
		"funds": world_state.get("funds", 0),
		"member_count": world_state.get("member_count", 0)
	})
	
	# Evaluate possible goals
	var goals = _evaluate_goals(world_state)
	
	# Debug goals
	Logger.debug("Commander AI goals evaluated", "AI", {
		"commander": entity.id,
		"goals_count": goals.size(),
		"goals": goals
	})

	print("Commander AI goals evaluated", "AI", {
		"commander": entity.id,
		"goals_count": goals.size(),
		"goals": goals
	})
	
	# Select best goal
	var best_goal = _select_goal(goals)
	
	print("COMMANDER: Goal selection - best_goal=", best_goal, " current_goal=", current_goal)
	
	if best_goal and best_goal.name != current_goal:
		print("COMMANDER: Setting new goal from ", current_goal, " to ", best_goal.name)
		_set_goal(best_goal)
	else:
		print("COMMANDER: No goal change needed")
	
	# Execute current goal
	print("COMMANDER: Checking current goal - current_goal=", current_goal, " has_goal=", current_goal != "")
	
	if current_goal:
		print("COMMANDER: Executing goal - ", current_goal)
		_execute_goal(world_state)
	else:
		print("COMMANDER: No current goal to execute!")

func _evaluate_goals(world_state: Dictionary) -> Array[Dictionary]:
	var goals: Array[Dictionary] = []
	
	# Get values with defaults
	var supplies = world_state.get("supplies", 0.0)
	var funds = world_state.get("funds", 0.0)
	var member_count = world_state.get("member_count", 0)
	var _territory_count = world_state.get("territory_count", 0)
	var _available_members = world_state.get("available_members", 0)
	var _threats = world_state.get("threats", [])
	var _opportunities = world_state.get("opportunities", [])
	var _intel = world_state.get("intel", {})
	var supply_consumption = world_state.get("supply_consumption", 1.0)

	# Critical supply emergency - only if supplies are critically low AND not recently completed
	if supplies < CRITICAL_SUPPLIES and _can_execute_goal("emergency_supplies"):
		goals.append({
			"name": "emergency_supplies",
			"priority": 100.0,
			"action": "buy_supplies"
		})
	
	# Defense against threats
	# if threats.size() > 0 and supplies < 300:
	# 	goals.append({
	# 		"name": "defend_territory",
	# 		"priority": 90.0,
	# 		"action": "defend"
	# 	})
	
	# Regular supply maintenance
	var days_of_supplies = supplies / max(supply_consumption, 1.0)
	if days_of_supplies < 5 and funds > MIN_FUNDS_FOR_OPERATIONS and _can_execute_goal("maintain_supplies"):
		goals.append({
			"name": "maintain_supplies",
			"priority": 80.0 * goal_weights.maintain_supplies,
			"action": "buy_supplies"
		})
	
	# Intelligence gathering
	# if funds > MIN_FUNDS_FOR_OPERATIONS and intel.size() < threats.size():
	# 	goals.append({
	# 		"name": "gather_intel",
	# 		"priority": 60.0 * goal_weights.gather_intel,
	# 		"action": "spy"
	# 	})
	
	# Recruitment (only if NPCs are available)
	print("Commander AI has available NPCs", "AI", {
		"commander": entity.id,
		"member_count": member_count,
		"funds": funds,
		"has_available_npcs": _has_available_npcs()
	})
	# if member_count < 5 and funds > 2 and _has_available_npcs() and _can_execute_goal("recruit_members"):
	# 	goals.append({
	# 		"name": "recruit_members",
	# 		"priority": 70.0 * goal_weights.recruit_members,
	# 		"action": "recruit"
	# 	})
	
	# Expansion
	# if funds > 1000 and member_count >= 5:
	# 	goals.append({
	# 		"name": "expand_territory",
	# 		"priority": 50.0 * goal_weights.expand_territory,
	# 		"action": "attack"
	# 	})
	
	# Diplomacy
	# if opportunities.size() > 0:
	# 	goals.append({
	# 		"name": "improve_relations",
	# 		"priority": 40.0 * goal_weights.improve_relations,
	# 		"action": "negotiate"
	# 	})
	
	# Patrol territories
	if _territory_count > 0 and _available_members > 0:
		goals.append({
			"name": "patrol_territories",
			"priority": 30.0,
			"action": "patrol"
		})
	
	return goals

func _execute_goal(world_state: Dictionary) -> void:
	# Execute the current goal by creating appropriate orders
	print("COMMANDER: _execute_goal called with goal=", current_goal)
	
	# Check if we already have pending orders for this goal
	var pending_count = pending_orders_by_goal.get(current_goal, 0)
	if pending_count > 0:
		print("COMMANDER: Goal ", current_goal, " already has ", pending_count, " pending orders. Skipping execution.")
		return
	
	if not Engine.has_singleton("OrderManager"):
		print("COMMANDER: ERROR - OrderManager not available!")
		return
	
	var order_manager = Engine.get_singleton("OrderManager")
	print("COMMANDER: Got OrderManager")
	
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		print("COMMANDER: ERROR - Missing gang member component!")
		return
	
	var faction_id = member_comp.faction_id
	print("COMMANDER: Faction ID = ", faction_id)
	
	match current_goal:
		"emergency_supplies", "maintain_supplies":
			print("COMMANDER: Creating BUY_SUPPLIES order for faction ", faction_id)
			order_manager.create_order(Order.OrderType.BUY_SUPPLIES, faction_id, {"amount": 1000.0})
			_track_order_for_goal(current_goal)
			print("COMMANDER: Order creation call completed")
			
			# Try to assign orders to available members
			print("COMMANDER: Attempting to assign orders to members")
			_assign_orders_to_members()
		
		"defend_territory":
			order_manager.create_order(Order.OrderType.DEFEND_TERRITORY, faction_id, {})
			_track_order_for_goal(current_goal)
			_assign_orders_to_members()
		
		"gather_intel":
			if world_state.threats.size() > 0:
				var target = world_state.threats[0]
				order_manager.create_order(Order.OrderType.SPY, faction_id, {"target_faction": target.faction_id})
				_track_order_for_goal(current_goal)
				_assign_orders_to_members()
		
		"recruit_members":
			# Find a specific recruitable NPC
			var target_npc = _get_recruitable_npc()
			if target_npc:
				order_manager.create_order(Order.OrderType.RECRUIT_SPECIFIC_NPC, faction_id, {"target_id": target_npc.id})
				_track_order_for_goal(current_goal)
				_assign_orders_to_members()
		
		"expand_territory":
			# Find weakest hostile faction
			var weakest_enemy = null
			var min_strength = INF
			for threat in world_state.threats:
				if threat.strength < min_strength:
					min_strength = threat.strength
					weakest_enemy = threat
			
			if weakest_enemy:
				order_manager.create_order(Order.OrderType.ATTACK_ENEMY, faction_id, {"target_faction": weakest_enemy.faction_id})
				_track_order_for_goal(current_goal)
				_assign_orders_to_members()
		
		"improve_relations":
			if world_state.opportunities.size() > 0:
				var target = world_state.opportunities[0]
				order_manager.create_order(Order.OrderType.NEGOTIATE, faction_id, {"target_faction": target.faction_id})
				_track_order_for_goal(current_goal)
				_assign_orders_to_members()
		
		"patrol_territories":
			order_manager.create_order(Order.OrderType.PATROL_TERRITORY, faction_id, {})
			_track_order_for_goal(current_goal)
			_assign_orders_to_members()

# DEPRECATED: Use OrderManager instead
func _issue_order_old(order_type: Order.OrderType, target_id: String = "", parameters: Dictionary = {}) -> bool:
	# Check if we already have this type of order in queue
	for order_entity in order_queue:
		var existing_order_comp = order_entity.get_component("OrderComponent")
		if existing_order_comp and existing_order_comp.order_type == order_type and existing_order_comp.target_id == target_id:
			Logger.debug("Order already in queue", "AI", {
				"type": Order.OrderType.keys()[order_type]
			})
			return false
	
	# Check queue size
	if order_queue.size() >= max_queue_size:
		_cleanup_order_queue()
		if order_queue.size() >= max_queue_size:
			Logger.warning("Order queue full", "AI")
			return false
	
	# Create order entity
	var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
	if not entity_manager:
		return false
	
	var order_entity = entity_manager.create_entity("order")
	var order_comp = OrderComponent.new()
	order_comp.order_type = order_type
	order_comp.target_id = target_id
	order_comp.issued_by = entity.id
	order_comp.parameters = parameters
	order_entity.add_component(order_comp)
	
	# Validate order can be executed
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		entity_manager.mark_for_destruction(order_entity)
		return false
	
	var faction_entity = entity_manager.get_entity(member_comp.faction_id)
	if not faction_entity:
		entity_manager.mark_for_destruction(order_entity)
		return false
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp or not order_comp.can_be_executed_by(faction_comp):
		entity_manager.mark_for_destruction(order_entity)
		return false
	
	# Add to queue
	order_queue.append(order_entity)
	orders_issued_today += 1
	
	Logger.info("Commander issued order", "AI", {
		"commander": entity.id,
		"order_type": Order.OrderType.keys()[order_type],
		"target": target_id,
		"queue_size": order_queue.size()
	})
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_CREATED,
			{
				"order_id": order_entity.id,
				"order_type": order_type,
				"faction_id": faction_entity.id,
				"commander_id": entity.id
			}
		)
	
	# Try to assign immediately
	_assign_orders_to_members()
	
	return true

func _assign_orders_to_members() -> void:
	# Use OrderManager to assign orders from faction queue
	if not Engine.has_singleton("OrderManager"):
		Logger.error("OrderManager not available for order assignment", "CommanderAI")
		return
	
	var order_manager = Engine.get_singleton("OrderManager")
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		return
	
	var faction_id = member_comp.faction_id
	var available_orders = order_manager.get_available_orders(faction_id)
	print("COMMANDER: Available orders for faction ", faction_id, " = ", available_orders.size())
	
	if available_orders.is_empty():
		print("COMMANDER: No available orders for faction ", faction_id)
		return
	
	# Get available members
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return
	
	var faction_entity = entity_manager.get_entity(faction_id)
	if not faction_entity:
		return
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		return
	
	var available_members: Array = []
	for member_entity in faction_comp.get_members():
		var member_comp_available = member_entity.get_component("GangMemberComponent")
		if member_comp_available and member_comp_available.is_available() and member_comp_available.role != GangMemberComponent.ROLE_COMMANDER:
			available_members.append(member_entity)
	
	if available_members.is_empty():
		return
	
	# Try to assign orders to available members
	Logger.info("Commander AI attempting to assign orders", "CommanderAI", {
		"available_orders": available_orders.size(),
		"available_members": available_members.size()
	})
	
	for order_entity in available_orders:
		if available_members.is_empty():
			break
		
		# Find best member for this order
		var order_comp = order_entity.get_component("OrderComponent")
		if not order_comp:
			continue
		
		var best_member = _select_member_for_order(available_members, order_comp)
		if best_member:
			# Use OrderManager to assign the order
			if order_manager.assign_order_to_member(order_entity, best_member):
				available_members.erase(best_member)
				Logger.info("Order assigned via OrderManager", "CommanderAI", {
					"order_id": order_entity.id,
					"member": best_member.get_component("GangMemberComponent").member_name,
					"order_type": Order.OrderType.keys()[order_comp.get_order_type()]
				})
			else:
				Logger.warning("Failed to assign order to member", "CommanderAI", {
					"order_id": order_entity.id,
					"member": best_member.get_component("GangMemberComponent").member_name
				})

func _select_member_for_order(members: Array, order_comp: OrderComponent) -> Entity:
	# Select best member based on order type and member attributes
	var best_member = null
	var best_score = -1.0
	
	for member_entity in members:
		var member_comp = member_entity.get_component("GangMemberComponent")
		if not member_comp:
			continue
		
		var score = member_comp.get_efficiency()
		
		# Role-based scoring
		match order_comp.get_order_type():
			Order.OrderType.SPY:
				if member_comp.role == GangMemberComponent.ROLE_SPY:
					score *= 2.0
			Order.OrderType.ATTACK_ENEMY:
				if member_comp.role in [GangMemberComponent.ROLE_ENFORCER, GangMemberComponent.ROLE_SNIPER]:
					score *= 1.5
			Order.OrderType.NEGOTIATE:
				if member_comp.personality == GangMemberComponent.PERSONALITY_LOYAL:
					score *= 1.3
		
		if score > best_score:
			best_score = score
			best_member = member_entity
	
	return best_member

func _cleanup_order_queue() -> void:
	# Remove completed, failed, or invalid orders
	var valid_orders: Array = []
	
	for order_entity in order_queue:
		if order_entity.is_destroyed():
			continue
		
		var order_comp = order_entity.get_component("OrderComponent")
		if not order_comp:
			continue
		
		if order_comp.status in ["pending", "assigned"]:
			valid_orders.append(order_entity)
		else:
			# Destroy completed/failed orders
			var entity_manager = Engine.get_singleton("EntityManager")
			if entity_manager:
				entity_manager.mark_for_destruction(order_entity)
	
	order_queue = valid_orders

func adjust_goal_weight(goal: String, weight: float) -> void:
	if goal_weights.has(goal):
		goal_weights[goal] = clamp(weight, 0.0, 2.0)
		Logger.info("Goal weight adjusted", "AI", {
			"goal": goal,
			"new_weight": weight
		})

func get_strategy_summary() -> Dictionary:
	return {
		"current_goal": current_goal,
		"goal_priority": goal_priority,
		"orders_in_queue": order_queue.size(),
		"orders_issued_today": orders_issued_today,
		"goal_weights": goal_weights.duplicate()
	}

func _has_available_npcs() -> bool:
	# Check if there are any NPCs available for recruitment
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var npcs = entity_manager.get_entities_with_component("NPCComponent")
		
		var current_day = int(Time.get_ticks_msec() / (24.0 * 60.0 * 60.0 * 1000.0))  # Correct day calculation

		for npc_entity in npcs:
			var npc_comp = npc_entity.get_component("NPCComponent")
			if npc_comp and npc_comp.can_be_recruited(current_day):
				return true
	
	return false

func _get_recruitable_npc() -> Entity:
	# Get a random recruitable NPC
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var npcs = entity_manager.get_entities_with_component("NPCComponent")
		var recruitable_npcs = []
		
		var current_day = int(Time.get_ticks_msec() / (24.0 * 60.0 * 60.0 * 1000.0))
		
		for npc_entity in npcs:
			var npc_comp = npc_entity.get_component("NPCComponent")
			if npc_comp and npc_comp.can_be_recruited(current_day):
				recruitable_npcs.append(npc_entity)
		
		if recruitable_npcs.size() > 0:
			return recruitable_npcs[randi() % recruitable_npcs.size()]
	
	return null

# Goal management methods
func _can_execute_goal(goal_name: String) -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_completed = completed_goals.get(goal_name, 0.0)
	var cooldown = goal_cooldowns.get(goal_name, 60.0)
	
	# Check if enough time has passed since last completion
	if current_time - last_completed < cooldown:
		print("COMMANDER: Goal ", goal_name, " is on cooldown for ", cooldown - (current_time - last_completed), " more seconds")
		return false
	
	# Check if we already have pending orders for this goal
	var pending_count = pending_orders_by_goal.get(goal_name, 0)
	if pending_count > 0:
		print("COMMANDER: Goal ", goal_name, " already has ", pending_count, " pending orders")
		return false
	
	return true

func _track_order_for_goal(goal_name: String) -> void:
	var current_count = pending_orders_by_goal.get(goal_name, 0)
	pending_orders_by_goal[goal_name] = current_count + 1
	print("COMMANDER: Tracking order for goal ", goal_name, ". Pending count: ", pending_orders_by_goal[goal_name])

func _complete_goal(goal_name: String) -> void:
	completed_goals[goal_name] = Time.get_ticks_msec() / 1000.0
	pending_orders_by_goal[goal_name] = 0
	print("COMMANDER: Goal ", goal_name, " completed and marked with cooldown")
	
	# Clear current goal if it matches the completed one
	if current_goal == goal_name:
		current_goal = ""
		print("COMMANDER: Cleared current goal after completion")

func _on_order_completed_for_goal(goal_name: String) -> void:
	var current_count = pending_orders_by_goal.get(goal_name, 0)
	if current_count > 0:
		pending_orders_by_goal[goal_name] = current_count - 1
		print("COMMANDER: Order completed for goal ", goal_name, ". Remaining pending: ", pending_orders_by_goal[goal_name])
		
		# If no more pending orders, mark goal as complete
		if pending_orders_by_goal[goal_name] == 0:
			_complete_goal(goal_name)

func _on_order_completed_event(event: EventBus.Event) -> void:
	# Check if this order completion affects our faction
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		return
	
	var faction_id = event.data.get("faction_id", "")
	if faction_id != member_comp.faction_id:
		return
	
	# Map order types to goal names for tracking
	var order_id = event.data.get("order_id", "")
	if order_id.is_empty():
		return
	
	# Get the order entity to determine its type
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return
	
	var order_entity = entity_manager.get_entity(order_id)
	if not order_entity:
		return
	
	var order_comp = order_entity.get_component("OrderComponent")
	if not order_comp:
		return
	
	# Map order type to goal name
	var goal_name = _map_order_type_to_goal(order_comp.get_order_type())
	if not goal_name.is_empty():
		_on_order_completed_for_goal(goal_name)

func _map_order_type_to_goal(order_type: int) -> String:
	match order_type:
		Order.OrderType.BUY_SUPPLIES:
			# Return the current goal if it's a supply-related goal
			if current_goal in ["emergency_supplies", "maintain_supplies"]:
				return current_goal
			return "emergency_supplies"  # Default fallback
		Order.OrderType.RECRUIT_SPECIFIC_NPC:
			return "recruit_members"
		Order.OrderType.DEFEND_TERRITORY:
			return "defend_territory"
		Order.OrderType.SPY:
			return "gather_intel"
		Order.OrderType.ATTACK_ENEMY:
			return "expand_territory"
		Order.OrderType.NEGOTIATE:
			return "improve_relations"
		Order.OrderType.PATROL_TERRITORY:
			return "patrol_territories"
		_:
			return ""
