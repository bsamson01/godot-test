# AI Behavior Tree System

This directory contains the complete AI behavior tree system for gang members using LimboAI.

## Overview

The AI system uses a hierarchical behavior tree approach where:
- Each gang member has a master behavior tree that manages their overall behavior
- Orders are executed using specialized sub-behaviors
- Tasks are modular and reusable across different order types

## Directory Structure

```
ai/
├── tasks/                    # Individual action tasks
│   ├── shared/              # Reusable tasks used by multiple behaviors
│   ├── buy_supplies/        # Tasks specific to buy supplies orders
│   ├── patrol/              # Tasks for patrol orders
│   ├── attack/              # Tasks for attack orders
│   └── ...                  # Other order-specific tasks
├── behaviors/               # Behavior tree definitions
│   └── master_ai_behavior.gd # Main behavior orchestrator
└── AI_SYSTEM_README.md      # This file
```

## Core Components

### 1. Master Behavior Tree (`behaviors/master_ai_behavior.gd`)
The root behavior that:
- Checks for emergency situations (low health, threats)
- Processes assigned orders
- Falls back to idle behavior when no orders exist

### 2. Order System
Orders flow through these stages:
1. **Check for Order** - Scans for pending orders assigned to the member
2. **Select Order Behavior** - Loads the appropriate behavior tree for the order type
3. **Execute Order** - Runs the order-specific tasks
4. **Complete Order** - Reports results back to the faction

### 3. Blackboard Variables
Key variables shared between tasks:
- `member_id` - The gang member's ID
- `current_order` - Active order being executed
- `order_type` - Type of the current order
- `target_location` - Where to move/act
- `target_entity` - What to interact with

## Order Types

### Buy Supplies (TYPE_BUY_SUPPLIES)
1. Find nearest shop
2. Move to shop
3. Purchase supplies
4. Return to base
5. Offload supplies

### Patrol Territory (TYPE_PATROL_TERRITORY)
1. Get territory boundaries
2. Pick random patrol points
3. Move between points
4. Check for threats
5. Report findings

### Attack Enemy (TYPE_ATTACK_ENEMY)
1. Find enemy targets
2. Assess target strength
3. Move to engage
4. Execute combat
5. Report results

### Other Orders
- `TYPE_SELL_GOODS` - Sell items at shops
- `TYPE_DEFEND_TERRITORY` - Defend faction territory
- `TYPE_COLLECT_PROTECTION` - Collect protection money
- `TYPE_RECRUIT_MEMBERS` - Recruit new gang members
- `TYPE_SCOUT_ENEMY` - Scout enemy territories

## Creating New Tasks

Tasks should extend `BTAction` and implement `_tick()`:

```gdscript
extends BTAction

func _tick(delta: float) -> Status:
    # Your task logic here
    
    # Return one of:
    # - SUCCESS: Task completed successfully
    # - FAILURE: Task failed
    # - RUNNING: Task still in progress
    return SUCCESS
```

## Creating New Order Types

1. Add the order type to `Order` enum in `scripts/models/order.gd`
2. Create task files in `ai/tasks/your_order_type/`
3. Add behavior tree mapping in `select_order_behavior.gd`
4. Update `complete_order.gd` to handle results

## Testing

Use `test/ai_test_scene.gd` to test the AI system:
- Press keys 1-8 to create different order types
- Watch gang members execute orders
- Check console for debug output

## Best Practices

1. **Keep Tasks Small** - Each task should do one thing well
2. **Use Blackboard** - Share data between tasks via blackboard
3. **Handle Failures** - Always return appropriate status
4. **Debug with Status** - Update agent status for visual debugging
5. **Reuse Tasks** - Use shared tasks when possible

## Integration Points

The AI system integrates with:
- **WorldState** - For accessing game entities
- **Order System** - For receiving and reporting orders
- **EventBus** - For emitting AI events
- **Navigation** - For pathfinding
- **Combat** - For attack/defense behaviors