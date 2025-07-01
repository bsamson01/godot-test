extends Panel

@onready var name_label = $VBoxContainer/NameLabel
@onready var state_label = $VBoxContainer/StateLabel
@onready var order_label = $VBoxContainer/OrderLabel
@onready var role_label = $VBoxContainer/RoleLabel

var member: GangMember

func set_member(m: GangMember):
	member = m
	
	# Lazy init — ensures UI nodes are available
	if name_label == null:
		name_label = $VBoxContainer/NameLabel
	if state_label == null:
		state_label = $VBoxContainer/StateLabel
	if order_label == null:
		order_label = $VBoxContainer/OrderLabel
	if role_label == null:
		role_label = $VBoxContainer/RoleLabel

	name_label.text = member.name
	state_label.text = "State: %s" % member.state.capitalize()

	if member.current_order:
		var order_name = Order.OrderType.keys()[member.current_order.type]
		order_label.text = "Order: %s" % order_name
	else:
		order_label.text = "Order: None"

	role_label.text = "Role: %s" % member.role.capitalize()
