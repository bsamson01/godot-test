# defend_action.gd - Defend against attack
extends BTAction

func _tick(_delta: float) -> Status:
	# For now, no defend action is implemented
	# This can be extended later when combat system is added
	agent.updateLabel('Defending (not implemented)')
	return FAILURE
