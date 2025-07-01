extends Control

@onready var faction_list = $ScrollContainer/FactionList

func render_all():
	for child in faction_list.get_children():
		child.queue_free()

	for faction in WorldState.get_all_factions():
		if faction == null:
			continue

		var card = preload("res://FactionCard.tscn").instantiate()
		card.set_faction(faction)
		faction_list.add_child(card)
