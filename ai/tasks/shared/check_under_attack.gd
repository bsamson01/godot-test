# check_under_attack.gd - Check if character is under attack
extends BTCondition

func _tick(_delta: float) -> Status:
	# For now, no attack detection is implemented
	# This can be extended later when combat system is added
	return FAILURE
