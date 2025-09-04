extends AIBrain
class_name CommanderAI

var order_queue: Array[Order] = []
var order_history: Array = []

func process_tick(current_tick: int):
	super.process_tick(current_tick)
	
	reevaluate_order_queue()
	consider_new_orders()
	assign_orders_to_members()

func consider_new_orders():
	var faction_entity = get_faction_entity()
	if not faction_entity:
		return
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		return

	var members = faction_comp.get_members()
	var idle_members = []
	
	# Get idle members using ECS
	for member_entity_id in members:
		var member_entity = Engine.get_singleton("EntityManager").get_entity(member_entity_id)
		if member_entity:
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp and member_comp.is_idle() and member_comp.role != GangMemberComponent.ROLE_COMMANDER:
				idle_members.append(member_entity)
	
	var territories = faction_comp.get_territories()

	# BUY_SUPPLIES: funds are high, but supplies are low
	if faction_comp.funds > 500 and faction_comp.supplies < 500:
		maybe_queue_order(Order.TYPE_BUY_SUPPLIES)

	# SPY: funds are good and no negotiation in progress
	if faction_comp.funds > 600 and not faction_comp.negotiations_active:
		maybe_queue_order(Order.TYPE_SPY)

	# RECRUIT: if we're under-strength
	if faction_comp.funds > 2000 and members.size() < 5:
		maybe_queue_order(Order.TYPE_RECRUIT_MEMBERS)

	# DEFEND: low supplies or few members = risk
	if faction_comp.supplies < 300 or members.size() <= 2:
		maybe_queue_order(Order.TYPE_DEFEND_TERRITORY)

	# ATTACK: if faction is strong and has surplus funds
	if faction_comp.funds > 1000 and members.size() >= 5:
		maybe_queue_order(Order.TYPE_ATTACK_ENEMY)

	# PATROL: idle members + territories => patrol them
	if idle_members.size() > 0 and territories.size() > 0:
		maybe_queue_order(Order.TYPE_PATROL_TERRITORY)


func maybe_queue_order(order_type: int, target_id: String = "") -> bool:
	var faction_entity = get_faction_entity()
	if not faction_entity:
		return false
		
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		return false
		
	var members = faction_comp.get_members()

	# Prevent duplicate orders of the same type (with same target_id)
	for order in order_queue:
		if order.type == order_type and order.target_id == target_id:
			return false
	
	# For BUY_SUPPLIES, only one allowed in the queue at any time
	if order_type == Order.TYPE_BUY_SUPPLIES:
		for member_entity_id in members:
			var member_entity = Engine.get_singleton("EntityManager").get_entity(member_entity_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.current_order and member_comp.current_order.type == Order.TYPE_BUY_SUPPLIES:
					return false

		for order in order_queue:
			if order.type == Order.TYPE_BUY_SUPPLIES:
				return false

	var new_order = Order.new()
	new_order.type = order_type
	new_order.target_id = target_id
	new_order.issued_tick = WorldState.current_tick
	
	order_queue.append(new_order)
	order_queue.sort_custom(func(a, b): return a.get_priority() > b.get_priority())
	
	return true


func reevaluate_order_queue():
	var valid_orders: Array[Order] = []
	for order in order_queue:
		if _is_order_still_valid(order):
			valid_orders.append(order)
	order_queue = valid_orders

func assign_orders_to_members():
	var faction_entity = get_faction_entity()
	if not faction_entity:
		return
		
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		return
		
	var members = faction_comp.get_members()
	var available_members = []
	
	# Get available members using ECS
	for member_entity_id in members:
		var member_entity = Engine.get_singleton("EntityManager").get_entity(member_entity_id)
		if member_entity:
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp and member_comp.is_idle() and member_comp.role != GangMemberComponent.ROLE_COMMANDER:
				available_members.append(member_entity)

	var assigned_supply_order = false

	for order in order_queue.duplicate():
		if available_members.is_empty():
			break

		if order.type == Order.TYPE_BUY_SUPPLIES and assigned_supply_order:
			continue

		var member_entity = available_members.pop_front()
		var member_comp = member_entity.get_component("GangMemberComponent")
		if member_comp and member_comp.assign_order(order):
			order_history.append(order)
			order_queue.erase(order)
			if order.type == Order.TYPE_BUY_SUPPLIES:
				assigned_supply_order = true


func _is_order_still_valid(order: Order) -> bool:
	var faction_entity = get_faction_entity()
	if not faction_entity:
		return false
		
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		return false
		
	match order.type:
		Order.TYPE_BUY_SUPPLIES:
			return faction_comp.funds > 500
		Order.TYPE_SPY:
			return not faction_comp.negotiations_active
		_:
			return true

func get_faction_entity() -> Entity:
	# Get faction entity using ECS
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return null
		
	# Find faction entity by checking all faction components
	var faction_entities = entity_manager.get_entities_with_component("FactionComponent")
	for faction_entity in faction_entities:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp and faction_comp.get_members().has(self.member_id):
			return faction_entity
	return null
