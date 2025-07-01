extends AIBrain  
class_name NormalMemberAI

func process_tick(current_tick: int):
	super.process_tick(current_tick)
	
	var member = get_member()
	if not member or not member.current_order:
		return
		
	_process_current_order(member, current_tick)

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

	
