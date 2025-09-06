extends Node

# Minimal WorldState - only for ECS compatibility
var current_tick: int = 0

func update_tick(tick: int):
	current_tick = tick
