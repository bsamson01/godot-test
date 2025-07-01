extends Panel

@onready var faction_color = $VBoxContainer/FactionColor
@onready var faction_name_label = $VBoxContainer/FactionLabel
@onready var funds_label = $VBoxContainer/FundsLabel
@onready var supplies_label = $VBoxContainer/SuppliesLabel
@onready var order_queue_list = $VBoxContainer/OrderQueueList
@onready var income_log_list = $VBoxContainer/IncomeLogList
@onready var member_cards = $VBoxContainer/MemberCards

var faction: Faction

func set_faction(f: Faction):
	if f == null:
		push_warning("Tried to set null faction.")
		return

	faction = f
	
	# Lazy init on demand
	if faction_color == null:
		faction_color = $VBoxContainer/FactionColor
	if faction_name_label == null:
		faction_name_label = $VBoxContainer/FactionColor/FactionLabel
	if funds_label == null:
		funds_label = $VBoxContainer/FactionColor/FundsLabel
	if supplies_label == null:
		supplies_label = $VBoxContainer/FactionColor/SuppliesLabel
	if order_queue_list == null:
		order_queue_list = $VBoxContainer/FactionColor/OrderQueueList
	if income_log_list == null:
		income_log_list = $VBoxContainer/FactionColor/IncomeLogList
	if member_cards == null:
		member_cards = $VBoxContainer/FactionColor/MemberCards
	
	if faction_color:
		faction_color.color = f.color

	if faction_name_label:
		faction_name_label.text = f.name

	if funds_label:
		funds_label.text = "Funds: %.1f" % f.funds

	if supplies_label:
		supplies_label.text = "Supplies: %.1f" % f.supplies

	# Clear order queue list safely
	if order_queue_list:
		for child in order_queue_list.get_children():
			child.queue_free()

		var commander = f.get_commander()
		if commander and commander.ai_brain:
			for order in commander.ai_brain.order_queue:
				if order != null:
					var label = Label.new()
					var type_str = order.name()
					label.text = "%s → %s" % [type_str, order.target_id]
					order_queue_list.add_child(label)

	# Clear income log safely
	if income_log_list:
		for child in income_log_list.get_children():
			child.queue_free()

		var last_entry = f.income_log.back()
		if last_entry and last_entry.has("amount") and last_entry.has("source_business"):
			var label = Label.new()
			var business = WorldState.get_business(last_entry.source_business)
			label.text = "+%.1f from %s" % [last_entry.amount, business.name]
			income_log_list.add_child(label)

	# Clear member cards safely
	if member_cards:
		for child in member_cards.get_children():
			child.queue_free()

		for member in f.get_members():
			if member != null:
				var card = preload("res://MemberCard.tscn").instantiate()
				card.set_member(member)
				member_cards.add_child(card)
