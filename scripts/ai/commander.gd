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
	var faction = get_faction()
	if not faction:
		return

	var members = faction.get_members()
	var idle_members = members.filter(func(m): return m.is_idle() && m.role != GangMember.ROLE_COMMANDER)
	var territories = faction.get_territories()

	# BUY_SUPPLIES: funds are high, but supplies are low
	if faction.funds > 500 and faction.supplies < 500:
		maybe_queue_order(Order.OrderType.BUY_SUPPLIES)

	# SPY: funds are good and no negotiation in progress
	if faction.funds > 600 and not faction.negotiations_active:
		maybe_queue_order(Order.OrderType.SPY)

	# RECRUIT: if we’re under-strength
	if faction.funds > 2000 and members.size() < 5:
		maybe_queue_order(Order.OrderType.RECRUIT)

	# DEFEND: low supplies or few members = risk
	if faction.supplies < 300 or members.size() <= 2:
		maybe_queue_order(Order.OrderType.DEFEND)

	# ATTACK: if faction is strong and has surplus funds
	if faction.funds > 1000 and members.size() >= 5:
		maybe_queue_order(Order.OrderType.ATTACK)

	# PATROL: idle members + territories => patrol them
	if idle_members.size() > 0 and territories.size() > 0:
		maybe_queue_order(Order.OrderType.PATROL)


func maybe_queue_order(order_type: int, target_id: String = "") -> bool:
	var faction = get_faction()
	var members = faction.get_members()

	# Prevent duplicate orders of the same type (with same target_id)
	for order in order_queue:
		if order.type == order_type and order.target_id == target_id:
			return false
	
	# For BUY_SUPPLIES, only one allowed in the queue at any time
	if order_type == Order.OrderType.BUY_SUPPLIES:
		for member in members:
			if member.current_order && member.current_order.type == Order.OrderType.BUY_SUPPLIES:
				return false

		for order in order_queue:
			if order.type == Order.OrderType.BUY_SUPPLIES:
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
	var faction = get_faction()
	if not faction:
		return
		
	var available_members = faction.get_members().filter(func(m): return m.is_idle() && m.role != GangMember.ROLE_COMMANDER )

	var assigned_supply_order = false

	for order in order_queue.duplicate():
		if available_members.is_empty():
			break

		if order.type == Order.OrderType.BUY_SUPPLIES and assigned_supply_order:
			continue

		var member = available_members.pop_front()
		if member.assign_order(order):
			order_history.append(order)
			order_queue.erase(order)
			if order.type == Order.OrderType.BUY_SUPPLIES:
				assigned_supply_order = true


func _is_order_still_valid(order: Order) -> bool:
	var faction = get_faction()
	if not faction:
		return false
		
	match order.type:
		Order.OrderType.BUY_SUPPLIES:
			return faction.funds > 500
		Order.OrderType.SPY:
			return not faction.negotiations_active
		_:
			return true
