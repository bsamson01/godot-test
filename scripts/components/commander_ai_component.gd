# CommanderAIComponent.gd - AI for faction commanders
extends AIComponent
class_name CommanderAIComponent

# Order queue management
var order_queue: Array[Entity] = []
var max_queue_size: int = 10
var orders_issued_today: int = 0

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

func _update_cached_state() -> void:
	var faction_comp = entity.get_component("FactionComponent")
	if not faction_comp:
		Logger.error("Commander AI missing faction component", "AI")
		return
	
	var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
	if not entity_manager:
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
		var member_comp = member_entity.get_component("GangMemberComponent")
		if member_comp:
			if member_comp.is_available():
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

func _evaluate_goals(world_state: Dictionary) -> Array[Dictionary]:
	var goals: Array[Dictionary] = []
	
	# Critical supply maintenance
	if world_state.supplies < CRITICAL_SUPPLIES:
		goals.append({
			"name": "emergency_supplies",
			"priority": 100.0,
			"action": "buy_supplies"
		})
	
	# Defense against threats
	if world_state.threats.size() > 0 and world_state.supplies < 300:
		goals.append({
			"name": "defend_territory",
			"priority": 90.0,
			"action": "defend"
		})
	
	# Regular supply maintenance
	var days_of_supplies = world_state.supplies / max(world_state.supply_consumption, 1.0)
	if days_of_supplies < 5 and world_state.funds > MIN_FUNDS_FOR_OPERATIONS:
		goals.append({
			"name": "maintain_supplies",
			"priority": 80.0 * goal_weights.maintain_supplies,
			"action": "buy_supplies"
		})
	
	# Intelligence gathering
	if world_state.funds > MIN_FUNDS_FOR_OPERATIONS and world_state.intel.size() < world_state.threats.size():
		goals.append({
			"name": "gather_intel",
			"priority": 60.0 * goal_weights.gather_intel,
			"action": "spy"
		})
	
	# Recruitment
	if world_state.member_count < 5 and world_state.funds > 2000:
		goals.append({
			"name": "recruit_members",
			"priority": 70.0 * goal_weights.recruit_members,
			"action": "recruit"
		})
	
	# Expansion
	if world_state.funds > 1000 and world_state.member_count >= 5:
		goals.append({
			"name": "expand_territory",
			"priority": 50.0 * goal_weights.expand_territory,
			"action": "attack"
		})
	
	# Diplomacy
	if world_state.opportunities.size() > 0:
		goals.append({
			"name": "improve_relations",
			"priority": 40.0 * goal_weights.improve_relations,
			"action": "negotiate"
		})
	
	# Patrol territories
	if world_state.territory_count > 0 and world_state.available_members > 0:
		goals.append({
			"name": "patrol_territories",
			"priority": 30.0,
			"action": "patrol"
		})
	
	return goals

func _execute_goal(world_state: Dictionary) -> void:
	match current_goal:
		"emergency_supplies", "maintain_supplies":
			_issue_order(OrderComponent.OrderType.BUY_SUPPLIES, "", {"amount": 1000.0})
		
		"defend_territory":
			_issue_order(OrderComponent.OrderType.DEFEND, "")
		
		"gather_intel":
			if world_state.threats.size() > 0:
				var target = world_state.threats[0]
				_issue_order(OrderComponent.OrderType.SPY, target.faction_id)
		
		"recruit_members":
			_issue_order(OrderComponent.OrderType.RECRUIT, "")
		
		"expand_territory":
			# Find weakest hostile faction
			var weakest_enemy = null
			var min_strength = INF
			for threat in world_state.threats:
				if threat.strength < min_strength:
					min_strength = threat.strength
					weakest_enemy = threat
			
			if weakest_enemy:
				_issue_order(OrderComponent.OrderType.ATTACK, weakest_enemy.faction_id)
		
		"improve_relations":
			if world_state.opportunities.size() > 0:
				var target = world_state.opportunities[0]
				_issue_order(OrderComponent.OrderType.NEGOTIATE, target.faction_id)
		
		"patrol_territories":
			_issue_order(OrderComponent.OrderType.PATROL, "")

func _issue_order(order_type: OrderComponent.OrderType, target_id: String = "", parameters: Dictionary = {}) -> bool:
	# Check if we already have this type of order in queue
	for order_entity in order_queue:
		var order_comp = order_entity.get_component("OrderComponent")
		if order_comp and order_comp.order_type == order_type and order_comp.target_id == target_id:
			Logger.debug("Order already in queue", "AI", {
				"type": OrderComponent.OrderType.keys()[order_type]
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
	var faction_comp = entity.get_component("FactionComponent")
	if not order_comp.can_be_executed_by(faction_comp):
		entity_manager.mark_for_destruction(order_entity)
		return false
	
	# Add to queue
	order_queue.append(order_entity)
	orders_issued_today += 1
	
	Logger.info("Commander issued order", "AI", {
		"commander": entity.id,
		"order_type": OrderComponent.OrderType.keys()[order_type],
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
				"faction_id": faction_comp.entity.id,
				"commander_id": entity.id
			}
		)
	
	# Try to assign immediately
	_assign_orders_to_members()
	
	return true

func _assign_orders_to_members() -> void:
	var faction_comp = entity.get_component("FactionComponent")
	if not faction_comp:
		return
	
	# Get available members
	var available_members: Array[Entity] = []
	for member_entity in faction_comp.get_members():
		var member_comp = member_entity.get_component("GangMemberComponent")
		if member_comp and member_comp.is_available() and member_comp.role != GangMemberComponent.ROLE_COMMANDER:
			available_members.append(member_entity)
	
	if available_members.is_empty():
		return
	
	# Sort orders by priority
	order_queue.sort_custom(func(a, b):
		var a_comp = a.get_component("OrderComponent")
		var b_comp = b.get_component("OrderComponent")
		return a_comp.priority > b_comp.priority if a_comp and b_comp else false
	)
	
	# Assign orders
	var assigned_orders: Array[Entity] = []
	
	for order_entity in order_queue:
		if available_members.is_empty():
			break
		
		var order_comp = order_entity.get_component("OrderComponent")
		if not order_comp or order_comp.status != "pending":
			continue
		
		# Special handling for supply orders - only one at a time
		if order_comp.order_type == OrderComponent.OrderType.BUY_SUPPLIES:
			var supply_order_active = false
			for member in faction_comp.get_members():
				var m_comp = member.get_component("GangMemberComponent")
				if m_comp and m_comp.current_order:
					var o_comp = m_comp.current_order.get_component("OrderComponent")
					if o_comp and o_comp.order_type == OrderComponent.OrderType.BUY_SUPPLIES:
						supply_order_active = true
						break
			
			if supply_order_active:
				continue
		
		# Find best member for this order
		var best_member = _select_member_for_order(available_members, order_comp)
		if best_member:
			var member_comp = best_member.get_component("GangMemberComponent")
			if member_comp.assign_order(order_entity):
				available_members.erase(best_member)
				assigned_orders.append(order_entity)
	
	# Remove assigned orders from queue
	for order in assigned_orders:
		order_queue.erase(order)

func _select_member_for_order(members: Array[Entity], order_comp: OrderComponent) -> Entity:
	# Select best member based on order type and member attributes
	var best_member = null
	var best_score = -1.0
	
	for member_entity in members:
		var member_comp = member_entity.get_component("GangMemberComponent")
		if not member_comp:
			continue
		
		var score = member_comp.get_efficiency()
		
		# Role-based scoring
		match order_comp.order_type:
			OrderComponent.OrderType.SPY:
				if member_comp.role == GangMemberComponent.ROLE_SPY:
					score *= 2.0
			OrderComponent.OrderType.ATTACK:
				if member_comp.role in [GangMemberComponent.ROLE_ENFORCER, GangMemberComponent.ROLE_SNIPER]:
					score *= 1.5
			OrderComponent.OrderType.NEGOTIATE:
				if member_comp.personality == GangMemberComponent.PERSONALITY_LOYAL:
					score *= 1.3
		
		if score > best_score:
			best_score = score
			best_member = member_entity
	
	return best_member

func _cleanup_order_queue() -> void:
	# Remove completed, failed, or invalid orders
	var valid_orders: Array[Entity] = []
	
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
