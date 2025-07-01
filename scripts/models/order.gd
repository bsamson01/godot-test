extends Resource
class_name Order

enum OrderType {
	BUY_SUPPLIES,
	SPY,
	ATTACK,
	DEFEND,
	RECRUIT,
	PATROL
}

@export var type: int
@export var target_id: String = ""
@export var data: Dictionary = {}
@export var issued_tick: int = 0

func name() -> String:
	match type:
		OrderType.BUY_SUPPLIES: return 'Buy Supplies'
		OrderType.DEFEND: return 'Defend'
		OrderType.SPY: return 'Spy'
		OrderType.ATTACK: return 'Attack'
		_: return 'Unknown'

func get_priority() -> int:
	match type:
		OrderType.BUY_SUPPLIES: return 100
		OrderType.DEFEND: return 90
		OrderType.SPY: return 70
		OrderType.ATTACK: return 50
		_: return 0

func get_travel_time() -> int:
	if data.has("travel_time"):
		return data["travel_time"]
	match type:
		OrderType.DEFEND: return 1
		OrderType.BUY_SUPPLIES: return 5
		OrderType.SPY: return 4
		OrderType.ATTACK: return 5
		OrderType.RECRUIT: return 3
		OrderType.PATROL: return 2
		_: return 5

func get_work_time() -> int:
	if data.has("work_time"):
		return data["work_time"]
	match type:
		OrderType.DEFEND: return 10
		OrderType.BUY_SUPPLIES: return 2
		OrderType.SPY: return 5
		OrderType.ATTACK: return 6
		OrderType.RECRUIT: return 4
		OrderType.PATROL: return 3
		_: return 3

func get_return_time() -> int:
	if data.has("return_time"):
		return data["return_time"]
	match type:
		OrderType.DEFEND: return 1
		OrderType.BUY_SUPPLIES: return 5
		OrderType.SPY: return 4
		OrderType.ATTACK: return 5
		OrderType.RECRUIT: return 3
		OrderType.PATROL: return 2
		_: return 5
