extends Node
class_name OrderLogic

# Check if an order can be triggered right now
static func can_trigger_order(order_type: int, commander_ai: CommanderAI, game_state: Dictionary) -> bool:
	match order_type:
		Order.OrderType.BUY_SUPPLIES:
			# Always allow buying supplies if funds > 100 (example)
			return game_state.get("funds", 0) > 100
		Order.OrderType.SPY:
			# Allow spying only if not negotiating and funds > 50
			return (not game_state.get("negotiations_active", false)) and game_state.get("funds", 0) > 50
		Order.OrderType.ATTACK:
			# Attack only if intel available and funds > 200
			return game_state.get("intel", {}).size() > 0 and game_state.get("funds", 0) > 200
		_:
			return false

# Check if an existing queued order should stay or be dropped
static func should_keep_order(order: Order, commander_ai: CommanderAI, game_state: Dictionary) -> bool:
	match order.type:
		Order.OrderType.BUY_SUPPLIES:
			# Remove if funds dropped below 50
			return game_state.get("funds", 0) > 50
		Order.OrderType.SPY:
			# Remove if negotiations started
			return not game_state.get("negotiations_active", false)
		Order.OrderType.ATTACK:
			# Remove if intel lost or funds too low
			return game_state.get("intel", {}).size() > 0 and game_state.get("funds", 0) > 150
		_:
			return false
