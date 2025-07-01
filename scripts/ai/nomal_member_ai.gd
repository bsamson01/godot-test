extends AIBrain
class_name NormalMemberAI

var bt_player: BTPlayer

func _ready():
	super._ready()
	_setup_behavior_tree()

func _setup_behavior_tree():
	# Create BTPlayer node
	bt_player = BTPlayer.new()
	bt_player.name = "BTPlayer"
	add_child(bt_player)
	
	# Create and assign the master behavior tree
	var behavior_tree = MasterAIBehavior.create_behavior_tree()
	bt_player.behavior_tree = behavior_tree
	
	# Initialize blackboard with member data
	bt_player.blackboard.set_var("member_id", member_id)
	
	# Set update mode
	bt_player.update_mode = BTPlayer.UpdateMode.PHYSICS
	bt_player.active = true

func process_tick(current_tick: int):
	# Update current tick in blackboard for time-based behaviors
	bt_player.blackboard.set_var("current_tick", current_tick)
	
	# The BTPlayer handles the actual behavior tree execution

func _exit_tree():
	if bt_player:
		bt_player.queue_free()

# Override these methods to provide agent functionality
func get_member() -> GangMember:
	return WorldState.get_gang_member(member_id)

func set_status(status_text: String):
	# Update visual status if available
	var member_node = WorldState.get_gang_member_node(member_id)
	if member_node and member_node.has_node("StatusLabel"):
		var label = member_node.get_node("StatusLabel")
		if label:
			label.text = status_text

func updateTargetLocation(target_pos: Vector3):
	var member_node = WorldState.get_gang_member_node(member_id)
	if member_node and member_node.has_method("updateTargetLocation"):
		member_node.updateTargetLocation(target_pos)

func _process_current_order(member: GangMember, current_tick: int):
	var order = member.current_order
	var elapsed_ticks = current_tick - order.issued_tick
	
	match member.state:
		"traveling":
			if elapsed_ticks >= order.get_travel_time():
				member.state = "working"
		"working":
			if elapsed_ticks >= (order.get_travel_time() + order.get_work_time()):
				_complete_order(member)
		
		"returning_to_base":
			if elapsed_ticks >= (order.get_travel_time() + order.get_work_time() + order.get_return_time()):
				# Clean up
				member.state = "idle"
				member.current_order = null
				elapsed_ticks = 0

func _complete_order(member: GangMember):
	var order = member.current_order
	var faction = member.get_faction()
	if not order or not faction:
		return

	match order.type:
		Order.OrderType.BUY_SUPPLIES:
			if faction.funds >= 100:
				faction.funds -= 100
				faction.supplies += 3500
				print("%s bought supplies for %s" % [member.name, faction.name])

		Order.OrderType.SPY:
			var target_id = order.target_id
			if target_id != "":
				# Store dummy intel
				faction.intel[target_id] = {
					"summary": "Gathered intel on %s" % target_id,
					"tick": WorldState.current_tick
				}
				print("%s spied on %s for %s" % [member.name, target_id, faction.name])

		Order.OrderType.ATTACK:
			var success = randf() < 0.6  # Simplified win chance
			print("%s led an attack. Success: %s" % [member.name, success])
			if success:
				faction.funds += 300
				faction.supplies += 200
			else:
				faction.funds -= 500
				faction.supplies -= 200

		Order.OrderType.DEFEND:
			print("%s organized a defensive effort for %s" % [member.name, faction.name])
			# Slight boost to defense intel or morale
			faction.intel["defense_readiness"] = {
				"level": "High",
				"tick": WorldState.current_tick
			}

		Order.OrderType.RECRUIT:
			if faction.funds >= 2000:
				var new_member = WorldState.spawn_gang_member(faction.id)
				faction.add_member(new_member)
				faction.funds -= 1500
				print("%s recruited a new member: %s" % [member.name, new_member.name])

		Order.OrderType.PATROL:
			print("%s completed a patrol." % member.name)
			# Optional: reduce chance of future attacks, or reveal nearby threats
			faction.intel["last_patrol_tick"] = WorldState.current_tick

		_:
			print("Order type %s has no defined outcome." % order.type)

	# Mark member as returning
	member.state = "returning_to_base"

	
