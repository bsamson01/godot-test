# check_low_health.gd - Check if character has low health
extends BTCondition

func _tick(_delta: float) -> Status:
	# For now, no health system is implemented
	# This can be extended later when health system is added
	return FAILURE
