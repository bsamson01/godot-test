extends Resource
class_name Order

# Order types - unified with OrderComponent
enum OrderType {
	BUY_SUPPLIES,
	SELL_GOODS,
	PATROL_TERRITORY,
	ATTACK_ENEMY,
	DEFEND_TERRITORY,
	COLLECT_PROTECTION,
	RECRUIT_MEMBERS,
	SCOUT_ENEMY,
	SPY,
	NEGOTIATE,
	SABOTAGE
}

# Order status
enum OrderStatus {
	PENDING,
	IN_PROGRESS,
	COMPLETED,
	FAILED,
	CANCELLED
}

@export var id: String = ""
@export var order_type: OrderType = OrderType.PATROL_TERRITORY
@export var status: OrderStatus = OrderStatus.PENDING
@export var assigned_to: String = ""  # Member ID
@export var target_id: String = ""
@export var data: Dictionary = {}
@export var issued_tick: int = 0
@export var started_at: int = 0
@export var completed_at: int = 0
@export var results: Dictionary = {}

# Time requirements (in seconds)
@export var travel_time: float = 5.0
@export var work_time: float = 10.0
@export var return_time: float = 5.0

# Order parameters
@export var priority: int = 50
@export var required_funds: float = 0.0
@export var required_supplies: float = 0.0
@export var success_chance: float = 0.8
@export var failure_reason: String = ""

func name() -> String:
	match order_type:
		OrderType.BUY_SUPPLIES: return 'Buy Supplies'
		OrderType.SELL_GOODS: return 'Sell Goods'
		OrderType.PATROL_TERRITORY: return 'Patrol Territory'
		OrderType.ATTACK_ENEMY: return 'Attack Enemy'
		OrderType.DEFEND_TERRITORY: return 'Defend Territory'
		OrderType.COLLECT_PROTECTION: return 'Collect Protection'
		OrderType.RECRUIT_MEMBERS: return 'Recruit Members'
		OrderType.SCOUT_ENEMY: return 'Scout Enemy'
		OrderType.SPY: return 'Spy'
		OrderType.NEGOTIATE: return 'Negotiate'
		OrderType.SABOTAGE: return 'Sabotage'
		_: return 'Unknown'

func get_priority() -> int:
	match order_type:
		OrderType.DEFEND_TERRITORY: return 100
		OrderType.ATTACK_ENEMY: return 90
		OrderType.BUY_SUPPLIES: return 80
		OrderType.COLLECT_PROTECTION: return 70
		OrderType.PATROL_TERRITORY: return 60
		OrderType.SELL_GOODS: return 50
		OrderType.RECRUIT_MEMBERS: return 40
		OrderType.SCOUT_ENEMY: return 30
		OrderType.SPY: return 70
		OrderType.NEGOTIATE: return 75
		OrderType.SABOTAGE: return 45
		_: return 0

func get_travel_time() -> float:
	if data.has("travel_time"):
		return data["travel_time"]
	# Return travel time in seconds (realistic values)
	match order_type:
		OrderType.DEFEND_TERRITORY: return 2.0  # 2 seconds to reach territory
		OrderType.BUY_SUPPLIES: return 5.0      # 5 seconds to reach shop
		OrderType.SELL_GOODS: return 5.0        # 5 seconds to reach market
		OrderType.SPY: return 4.0               # 4 seconds to reach target
		OrderType.ATTACK_ENEMY: return 5.0      # 5 seconds to reach enemy
		OrderType.RECRUIT_MEMBERS: return 3.0   # 3 seconds to reach recruitment area
		OrderType.PATROL_TERRITORY: return 2.0  # 2 seconds to reach patrol area
		OrderType.COLLECT_PROTECTION: return 4.0 # 4 seconds to reach business
		OrderType.SCOUT_ENEMY: return 6.0       # 6 seconds to reach enemy territory
		OrderType.NEGOTIATE: return 3.0         # 3 seconds to reach negotiation target
		OrderType.SABOTAGE: return 6.0          # 6 seconds to reach sabotage target
		_: return 5.0

func get_work_time() -> float:
	if data.has("work_time"):
		return data["work_time"]
	# Return work time in seconds (realistic values)
	match order_type:
		OrderType.DEFEND_TERRITORY: return 10.0  # 10 seconds defending
		OrderType.BUY_SUPPLIES: return 3.0       # 3 seconds to buy supplies
		OrderType.SELL_GOODS: return 3.0         # 3 seconds to sell goods
		OrderType.SPY: return 5.0                # 5 seconds to gather intel
		OrderType.ATTACK_ENEMY: return 6.0       # 6 seconds to attack
		OrderType.RECRUIT_MEMBERS: return 4.0    # 4 seconds to recruit
		OrderType.PATROL_TERRITORY: return 8.0   # 8 seconds patrolling
		OrderType.COLLECT_PROTECTION: return 3.0 # 3 seconds to collect
		OrderType.SCOUT_ENEMY: return 10.0       # 10 seconds scouting
		OrderType.NEGOTIATE: return 10.0         # 10 seconds negotiating
		OrderType.SABOTAGE: return 5.0           # 5 seconds sabotaging
		_: return 3.0

func get_return_time() -> float:
	if data.has("return_time"):
		return data["return_time"]
	return get_travel_time()  # Same as travel time by default

# Initialize order with proper values
func _init():
	id = "order_" + str(Time.get_ticks_msec())
	_calculate_requirements()

func _calculate_requirements() -> void:
	# Calculate requirements based on order type
	match order_type:
		OrderType.BUY_SUPPLIES:
			required_funds = data.get("amount", 500.0)
			travel_time = 5.0
			work_time = 3.0
			return_time = 5.0
			priority = 80
			
		OrderType.DEFEND_TERRITORY:
			required_supplies = 50.0
			travel_time = 2.0
			work_time = 10.0
			return_time = 2.0
			priority = 90
			
		OrderType.SPY:
			required_funds = 100.0
			travel_time = 4.0
			work_time = 5.0
			return_time = 4.0
			priority = 60
			success_chance = 0.7
			
		OrderType.ATTACK_ENEMY:
			required_funds = 200.0
			required_supplies = 100.0
			travel_time = 5.0
			work_time = 6.0
			return_time = 5.0
			priority = 50
			success_chance = 0.6
			
		OrderType.RECRUIT_MEMBERS:
			required_funds = 1500.0
			travel_time = 3.0
			work_time = 4.0
			return_time = 3.0
			priority = 40
			
		OrderType.PATROL_TERRITORY:
			travel_time = 2.0
			work_time = 8.0
			return_time = 2.0
			priority = 30
			
		OrderType.NEGOTIATE:
			required_funds = 300.0
			travel_time = 3.0
			work_time = 10.0
			return_time = 3.0
			priority = 70
			success_chance = 0.5
			
		OrderType.SABOTAGE:
			required_supplies = 75.0
			travel_time = 6.0
			work_time = 5.0
			return_time = 6.0
			priority = 45
			success_chance = 0.65

func get_total_time() -> float:
	return travel_time + work_time + return_time

func can_be_executed_by(faction_comp) -> bool:
	if not faction_comp:
		return false
	
	# Check resource requirements
	if faction_comp.funds < required_funds:
		return false
	
	if faction_comp.supplies < required_supplies:
		return false
	
	return true

func execute(_executor_entity) -> bool:
	# This will be implemented by the OrderComponent
	# For now, just mark as in progress
	status = OrderStatus.IN_PROGRESS
	started_at = int(Time.get_ticks_msec() / 1000.0)
	return true

func complete(_executor_entity) -> Dictionary:
	# This will be implemented by the OrderComponent
	# For now, just mark as completed
	status = OrderStatus.COMPLETED
	completed_at = int(Time.get_ticks_msec() / 1000.0)
	return {"success": true}
