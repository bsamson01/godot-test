# Blackboard Best Practices

## Always Set Blackboard Values If Not Exists

To prevent `Blackboard: Variable "name" not found` errors, always use defensive programming when accessing blackboard variables.

## ✅ RECOMMENDED Pattern

### Method 1: Safe Access Helper Function (BEST)

Add this helper function to your behavior tree tasks:

```gdscript
extends BTAction

# Safe blackboard variable access with automatic default setting
func _safe_get_blackboard_var(key: String, default_value):
    if blackboard.has_var(key):
        return blackboard.get_var(key)
    else:
        # Set the default value for future use
        blackboard.set_var(key, default_value)
        return default_value

func _tick(_delta: float) -> Status:
    # Use the helper function
    var patrol_center = _safe_get_blackboard_var("patrol_center", Vector3.ZERO)
    var patrol_radius = _safe_get_blackboard_var("patrol_radius", 20.0)
    var supplies_bought = _safe_get_blackboard_var("supplies_bought", 0)
    
    # ... rest of your logic
```

### Method 2: Manual Check and Set

```gdscript
func _tick(_delta: float) -> Status:
    var patrol_center: Vector3
    if blackboard.has_var("patrol_center"):
        patrol_center = blackboard.get_var("patrol_center")
    else:
        patrol_center = Vector3.ZERO  # or calculate a sensible default
        blackboard.set_var("patrol_center", patrol_center)
```

## ❌ AVOID These Patterns

### Bad: Direct get_var() without checking
```gdscript
# This can cause "Variable not found" errors
var patrol_center = blackboard.get_var("patrol_center")
var patrol_radius = blackboard.get_var("patrol_radius", 20.0)  # Default may not work in all implementations
```

### Bad: get_var() without setting defaults
```gdscript
# This doesn't help future tasks that need the same variable
var patrol_center = blackboard.get_var("patrol_center", Vector3.ZERO) if blackboard.has_var("patrol_center") else Vector3.ZERO
```

## 🎯 Common Default Values

Use these sensible defaults for common blackboard variables:

```gdscript
# Movement and positioning
var pos = _safe_get_blackboard_var("pos", Vector3.ZERO)
var target_location = _safe_get_blackboard_var("target_location", Vector3.ZERO)
var patrol_center = _safe_get_blackboard_var("patrol_center", Vector3.ZERO)
var patrol_radius = _safe_get_blackboard_var("patrol_radius", 20.0)

# Order execution results
var supplies_bought = _safe_get_blackboard_var("supplies_bought", 0)
var supplies_cost = _safe_get_blackboard_var("supplies_cost", 0.0)
var goods_sold = _safe_get_blackboard_var("goods_sold", 0)
var sale_revenue = _safe_get_blackboard_var("sale_revenue", 0.0)
var threats_detected = _safe_get_blackboard_var("threats_detected", [])
var combat_result = _safe_get_blackboard_var("combat_result", "unknown")
var enemies_defeated = _safe_get_blackboard_var("enemies_defeated", 0)
var protection_money = _safe_get_blackboard_var("protection_money", 0.0)
var businesses_visited = _safe_get_blackboard_var("businesses_visited", 0)

# State tracking
var current_action = _safe_get_blackboard_var("current_action", "idle")
var order_type = _safe_get_blackboard_var("order_type", -1)
var member_state = _safe_get_blackboard_var("member_state", 0)
```

## 🔧 Special Cases

### For Entity References
```gdscript
var current_order = _safe_get_blackboard_var("current_order", null)
if not current_order:
    return FAILURE  # Handle null case appropriately
```

### For Dynamic Defaults
```gdscript
func _tick(_delta: float) -> Status:
    # Calculate default based on context
    var default_center = Vector3.ZERO
    if agent:
        default_center = agent.global_transform.origin
    
    var patrol_center = _safe_get_blackboard_var("patrol_center", default_center)
```

## 📋 Benefits

1. **No More Blackboard Errors**: Prevents "Variable not found" runtime errors
2. **Consistent State**: All tasks can rely on variables being available
3. **Self-Healing**: Missing variables are automatically initialized with sensible defaults
4. **Better Debugging**: You know exactly what default values are being used
5. **Robust Behavior Trees**: Trees continue working even if setup tasks fail

## 🚀 Implementation Tips

1. **Add the helper function to every BTAction task**
2. **Use sensible defaults that won't break your logic**
3. **Set defaults early in behavior tree execution**
4. **Document what each variable represents**
5. **Consider using the BlackboardHelper class for shared functionality**
