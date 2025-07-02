extends BTAction

@export var status_text: String = ""
@export var use_blackboard_var: bool = false
@export var blackboard_var_name: String = "status_text"

func _tick(_delta: float) -> Status:
	var text = status_text
	
	if use_blackboard_var and blackboard.has_var(blackboard_var_name):
		text = str(blackboard.get_var(blackboard_var_name))
	
	if agent.has_method("set_status"):
		agent.set_status(text)
	elif agent.has_node("StatusLabel"):
		var label = agent.get_node("StatusLabel")
		if label and label is Label3D:
			label.text = text
	
	return SUCCESS
