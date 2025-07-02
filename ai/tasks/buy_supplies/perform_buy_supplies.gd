extends BTAction

@export var buy_duration: float = 2.0
@export var supplies_amount: int = 10

var _buying_timer: float = 0.0

func _enter():
	_buying_timer = 0.0
	if agent.has_method("set_status"):
		agent.set_status("Buying supplies...")

func _tick(delta: float) -> Status:
	var shop = blackboard.get_var("target_shop")
	if not shop:
		return FAILURE
		
	# Simulate buying process
	_buying_timer += delta
	
	if _buying_timer >= buy_duration:
		# Get gang member data
		var member = agent.get_member() if agent.has_method("get_member") else null
		if not member:
			return FAILURE
			
		# Check if member has enough money
		var cost = supplies_amount * 10  # Assume $10 per supply unit
		if member.cash < cost:
			blackboard.set_var("buy_failure_reason", "insufficient_funds")
			return FAILURE
			
		# Perform the transaction
		member.cash -= cost
		blackboard.set_var("supplies_bought", supplies_amount)
		blackboard.set_var("supplies_cost", cost)
		
		return SUCCESS
		
	return RUNNING
