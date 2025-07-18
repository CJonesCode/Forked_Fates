# Time Management System Implementation Plan

**Status**: Not Yet Implemented  
**Priority**: Medium  
**Estimated Effort**: 2-3 development sessions  
**Dependencies**: Existing GameManager, EventBus, BaseMinigame

## System Overview

TimeManager autoload providing pause functionality and minigame-specific time scaling (0.1x to 4.0x speed) with perfect physics preservation via Engine.time_scale.

## Core Components

### 1. TimeManager Autoload
```gdscript
# autoloads/time_manager.gd
enum TimeState { RUNNING, PAUSED, TIME_SCALED }
var current_time_scale: float = 1.0
var time_scale_enabled: bool = false  # Only true in minigames

func set_time_scale(scale: float) -> void  # 0.1-4.0 range, minigames only
func pause_game() -> void              # Engine.time_scale = 0.0
func resume_game() -> void             # Restore previous time_scale
func enable_time_scaling() -> void     # Called on minigame start
func disable_time_scaling() -> void    # Called on minigame end
```

### 2. Enhanced GameManager Integration
```gdscript
# Existing PAUSED state enhanced with TimeManager calls
func _enter_paused_state() -> void:
    TimeManager.pause_game()  # Instead of get_tree().paused = true

func _exit_paused_state() -> void:
    TimeManager.resume_game()
```

### 3. Enhanced BaseMinigame Integration
```gdscript
func _on_initialize() -> void:
    TimeManager.enable_time_scaling()

func _on_end() -> void:
    TimeManager.disable_time_scaling()
```

### 4. Pause Menu UI
```gdscript
# Show time scale slider only when TimeManager.time_scale_enabled == true
@onready var time_scale_slider: HSlider  # Range: 0.1 to 4.0
time_scale_container.visible = TimeManager.is_in_minigame
```

## Visual Effects System

### Speed Effects
- **Fast Mode (>1.0x)**: Smear streak length = (time_scale - 1.0) * 50px
- **Slow Mode (<1.0x)**: Ghost fade time = (1.0 - time_scale) * 2.0 seconds  
- **Normal Mode (1.0x)**: No effects

### Implementation
```gdscript
# scripts/effects/time_scale_effects.gd
func apply_speed_effects(character: BasePlayer, time_scale: float)
func _apply_speed_streak(character, time_scale)  # >1.0x speeds
func _apply_ghost_effect(character, time_scale)  # <1.0x speeds
```

## Input System

### Simple Pause Input
- **Escape Key**: Toggle pause (works in all game states)
- **No time scale hotkeys**: Controlled via pause menu slider only

## Physics Preservation

### Engine.time_scale Benefits
- ✅ **Perfect state preservation**: All physics continue from exact state
- ✅ **Velocity preservation**: Bullet trajectories, player movement maintained
- ✅ **Collision integrity**: All collision states preserved
- ✅ **Ragdoll physics**: Exact position/rotation maintained

### State Transitions
```gdscript
pause:   Engine.time_scale = 0.0    # Physics stops, state preserved
resume:  Engine.time_scale = previous_scale  # Continues seamlessly
scale:   Engine.time_scale = new_value       # Proportional simulation speed
```

## Scope Limitations

### Map/Menu States
- **Pausable**: Yes (simple pause menu)
- **Time Scalable**: No (always 1.0x speed)
- **Implementation**: get_tree().paused for UI-only pause

### Minigame States  
- **Pausable**: Yes (full pause menu with time controls)
- **Time Scalable**: Yes (0.1x to 4.0x range)
- **Implementation**: Engine.time_scale for physics-aware control

## Implementation Phases

### Phase 1: Core Infrastructure
1. Create TimeManager autoload with basic pause/resume
2. Add simple Escape key input handler
3. Integrate with existing GameManager PAUSED state
4. Update BaseMinigame initialization/cleanup

### Phase 2: Time Scaling
1. Implement time scale range control (0.1x to 4.0x)
2. Add minigame context awareness
3. Create pause menu with conditional time scale slider
4. Add EventBus time scale signals

### Phase 3: Visual Effects
1. Create TimeScaleEffects system
2. Implement speed streak effects for >1.0x
3. Implement ghost trail effects for <1.0x  
4. Integrate with player movement systems

### Phase 4: Polish
1. Add audio pitch shifting for time scales
2. Implement smooth transition animations
3. Add settings persistence for preferred time scales
4. Performance optimization for visual effects

## File Structure

```
autoloads/
├── time_manager.gd           # Main system controller

scripts/
├── effects/
│   └── time_scale_effects.gd # Visual effect system
└── ui/
    └── pause_menu.gd         # Enhanced pause menu

scenes/
├── effects/
│   ├── SpeedStreak.tscn     # Fast motion effect
│   └── GhostTrail.tscn      # Slow motion effect
└── ui/
    └── pause_menu.tscn       # Updated pause menu UI
```

## EventBus Signal Extensions

```gdscript
# New signals to add
signal time_scale_changed(new_scale: float)
signal time_scaling_enabled()
signal time_scaling_disabled()
```

## Testing Checklist

### Core Functionality
- [ ] Pause/resume preserves physics state perfectly
- [ ] Time scaling only available in minigames
- [ ] Map/menu pause works independently
- [ ] Scene transitions reset time scale properly

### Visual Effects
- [ ] Speed streaks appear/scale correctly for fast motion
- [ ] Ghost trails fade appropriately for slow motion
- [ ] Effects cleanup properly on time scale changes
- [ ] No performance impact during normal gameplay

### Integration
- [ ] Existing pause functionality continues working
- [ ] GameManager state machine handles time states
- [ ] Minigame pause/resume integration seamless
- [ ] UI responsiveness maintained during pause

## Notes

- **Physics Fidelity**: Engine.time_scale provides perfect physics preservation
- **Scope Simplicity**: Time scaling only where it adds value (minigames)
- **UI Responsiveness**: Pause menu remains fully functional during pause
- **Backward Compatibility**: Existing pause systems continue working
- **Performance**: Visual effects use pooled objects for efficiency 