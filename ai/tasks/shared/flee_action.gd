# flee_action.gd - Flee from danger
extends BTAction

func _tick(_delta: float) -> Status:
	# For now, no flee action is implemented
	# This can be extended later when threat system is added
	agent.updateLabel('Fleeing (not implemented)')
	return FAILURE
