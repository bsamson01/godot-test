extends Resource
class_name Order

# Order types
enum {
	TYPE_BUY_SUPPLIES,
	TYPE_SELL_GOODS,
	TYPE_PATROL_TERRITORY,
	TYPE_ATTACK_ENEMY,
	TYPE_DEFEND_TERRITORY,
	TYPE_COLLECT_PROTECTION,
	TYPE_RECRUIT_MEMBERS,
	TYPE_SCOUT_ENEMY,
	TYPE_SPY,  # Legacy, kept for compatibility
}

# Order status
enum {
	STATUS_PENDING,
	STATUS_IN_PROGRESS,
	STATUS_COMPLETED,
	STATUS_FAILED,
	STATUS_CANCELLED
}

@export var id: String = ""
@export var type: int
@export var status: int = STATUS_PENDING
@export var assigned_to: String = ""  # Member ID
@export var target_id: String = ""
@export var data: Dictionary = {}
@export var issued_tick: int = 0
@export var started_at: int = 0
@export var completed_at: int = 0
@export var results: Dictionary = {}

func _init():
	id = "order_" + str(Time.get_ticks_msec())

func name() -> String:
	match type:
		TYPE_BUY_SUPPLIES: return 'Buy Supplies'
		TYPE_SELL_GOODS: return 'Sell Goods'
		TYPE_PATROL_TERRITORY: return 'Patrol Territory'
		TYPE_ATTACK_ENEMY: return 'Attack Enemy'
		TYPE_DEFEND_TERRITORY: return 'Defend Territory'
		TYPE_COLLECT_PROTECTION: return 'Collect Protection'
		TYPE_RECRUIT_MEMBERS: return 'Recruit Members'
		TYPE_SCOUT_ENEMY: return 'Scout Enemy'
		TYPE_SPY: return 'Spy'  # Legacy
		_: return 'Unknown'

func get_priority() -> int:
	match type:
		TYPE_DEFEND_TERRITORY: return 100
		TYPE_ATTACK_ENEMY: return 90
		TYPE_BUY_SUPPLIES: return 80
		TYPE_COLLECT_PROTECTION: return 70
		TYPE_PATROL_TERRITORY: return 60
		TYPE_SELL_GOODS: return 50
		TYPE_RECRUIT_MEMBERS: return 40
		TYPE_SCOUT_ENEMY: return 30
		TYPE_SPY: return 70  # Legacy
		_: return 0

func get_travel_time() -> int:
	if data.has("travel_time"):
		return data["travel_time"]
	match type:
		TYPE_DEFEND_TERRITORY: return 1
		TYPE_BUY_SUPPLIES: return 5
		TYPE_SELL_GOODS: return 5
		TYPE_SPY: return 4
		TYPE_ATTACK_ENEMY: return 5
		TYPE_RECRUIT_MEMBERS: return 3
		TYPE_PATROL_TERRITORY: return 2
		TYPE_COLLECT_PROTECTION: return 4
		TYPE_SCOUT_ENEMY: return 6
		_: return 5

func get_work_time() -> int:
	if data.has("work_time"):
		return data["work_time"]
	match type:
		TYPE_DEFEND_TERRITORY: return 10
		TYPE_BUY_SUPPLIES: return 2
		TYPE_SELL_GOODS: return 2
		TYPE_SPY: return 5
		TYPE_ATTACK_ENEMY: return 6
		TYPE_RECRUIT_MEMBERS: return 4
		TYPE_PATROL_TERRITORY: return 8
		TYPE_COLLECT_PROTECTION: return 3
		TYPE_SCOUT_ENEMY: return 10
		_: return 3

func get_return_time() -> int:
	if data.has("return_time"):
		return data["return_time"]
	return get_travel_time()  # Same as travel time by default
