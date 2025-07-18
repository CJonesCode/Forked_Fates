# Ragdoll Physics Implementation Plan

## Overview

This document outlines the implementation of a dual physics system inspired by Duck Game, where characters use kinematic movement while alive and transition to full physics-based ragdolls when dead or unconscious.

## Research Summary

### Duck Game Physics Analysis

Duck Game uses a **dual physics system**:
1. **Living Characters**: Use kinematic movement (similar to CharacterBody2D) for responsive, precise control
2. **Ragdolls**: Only activate full physics simulation when characters die/are unconscious  
3. **Transition**: Seamless switch between kinematic control and physics-based ragdoll

This approach provides:
- Responsive gameplay controls when alive
- Satisfying physics interactions when dead
- Performance optimization (physics only when needed)

### Godot 4.4 CharacterBody2D Benefits

- `move_and_slide()` with built-in collision response
- `is_on_floor()`, `is_on_wall()` detection
- Platform movement support
- Precise control over movement behavior
- Better performance than RigidBody2D for controlled movement

## Implementation Plan

### Phase 1: Enhanced CharacterBody2D System (Living Characters)

**Extend existing `BasePlayer` to include physics state management:**

```gdscript
# In scripts/player/base_player.gd
extends CharacterBody2D
class_name BasePlayer

# Physics states
enum PhysicsState {
    KINEMATIC,    # Normal gameplay
    TRANSITIONING, # Converting to ragdoll
    RAGDOLL       # Full physics simulation
}

var physics_state: PhysicsState = PhysicsState.KINEMATIC
var health: float = 100.0
var is_dead: bool = false

# Ragdoll components (created when needed)
var ragdoll_body: Node2D
var ragdoll_parts: Array[RigidBody2D] = []
var original_collision_shape: CollisionShape2D
```

### Phase 2: Ragdoll System Architecture

**Core Components:**

1. **RagdollManager** (Autoload)
   - Handles ragdoll creation/destruction
   - Manages transitions between states
   - Object pooling for performance

2. **RagdollPart** (extends RigidBody2D)
   - Individual body segments (head, torso, arms, legs)
   - Joint connections using HingeJoint2D
   - Collision handling with proper layers

3. **RagdollBuilder**
   - Procedurally creates ragdoll from CharacterBody2D
   - Sets up joints and constraints
   - Configures physics properties and limits

### Phase 3: Key Implementation Details

**1. Character State Management**
```gdscript
# Use CharacterBody2D for precise movement
func _physics_process(delta: float) -> void:
    match physics_state:
        PhysicsState.KINEMATIC:
            handle_kinematic_movement(delta)
        PhysicsState.TRANSITIONING:
            handle_ragdoll_transition(delta)
        PhysicsState.RAGDOLL:
            # Ragdoll is handled by separate RigidBody2D system
            handle_ragdoll_state(delta)
```

**2. Ragdoll Creation System**
```gdscript
# Convert to ragdoll when health <= 0
func trigger_ragdoll(death_force: Vector2 = Vector2.ZERO) -> void:
    physics_state = PhysicsState.TRANSITIONING
    
    # Create ragdoll body parts
    ragdoll_body = RagdollBuilder.create_from_character(self)
    
    # Apply death force for dramatic effect
    if death_force != Vector2.ZERO:
        ragdoll_body.apply_death_impulse(death_force)
    
    # Hide kinematic body, show ragdoll
    set_collision_layer_value(CollisionLayers.PLAYER_KINEMATIC, false)
    set_collision_mask_value(CollisionLayers.PLAYER_KINEMATIC, false)
    visible = false
    physics_state = PhysicsState.RAGDOLL
```

**3. Joint Configuration**
```gdscript
# Use HingeJoint2D for 2D ragdolls with anatomical limits
func setup_body_joints() -> void:
    # Head to torso - limited neck movement
    var neck_joint = HingeJoint2D.new()
    neck_joint.node_a = torso_body.get_path()
    neck_joint.node_b = head_body.get_path()
    neck_joint.limit_lower = deg_to_rad(-45)
    neck_joint.limit_upper = deg_to_rad(45)
    neck_joint.use_limits = true
    
    # Arms - shoulder joints
    var shoulder_joint = HingeJoint2D.new()
    shoulder_joint.limit_lower = deg_to_rad(-180)
    shoulder_joint.limit_upper = deg_to_rad(180)
    
    # Legs - hip joints  
    var hip_joint = HingeJoint2D.new()
    hip_joint.limit_lower = deg_to_rad(-90)
    hip_joint.limit_upper = deg_to_rad(90)
```

### Phase 4: Performance Optimizations

**1. Object Pooling**
- Pool ragdoll components to avoid frequent allocation
- Reuse rather than create/destroy
- Limit active ragdolls (despawn distant/old ones)

**2. Physics Layers**
```gdscript
# In scripts/core/collision_layers.gd
enum CollisionLayers {
    PLAYER_KINEMATIC = 1,
    PLAYER_RAGDOLL = 2,
    RAGDOLL_PARTS = 4,
    ENVIRONMENT = 8,
    WEAPONS = 16
}
```

**3. Selective Physics**
- Only enable complex ragdoll physics when visible on screen
- Simplified physics for off-screen ragdolls
- Automatic cleanup after time limit
- Sleep inactive ragdolls

### Phase 5: Integration with Existing Systems

**1. Weapon Handling**
```gdscript
# Weapons drop when ragdoll activates
func on_ragdoll_transition() -> void:
    if current_weapon:
        # Drop weapon with physics
        current_weapon.drop_with_force(last_movement_velocity)
    
    # Optionally attach to ragdoll hand for visual continuity
    if ragdoll_body:
        ragdoll_body.try_attach_weapon_to_hand(current_weapon)
```

**2. Visual Consistency**
```gdscript
# Match ragdoll appearance to character
func sync_ragdoll_appearance() -> void:
    for part in ragdoll_parts:
        part.sprite.texture = get_body_part_texture(part.body_part_type)
        part.sprite.modulate = character_sprite.modulate
        part.copy_animation_frame_from_character()
```

### Phase 6: Enhanced Features

**1. Partial Ragdoll States**
- **Stumbling**: Legs become ragdoll while upper body stays kinematic
- **Arm Hit Reactions**: Individual limbs react to impacts
- **Gradual Transitions**: Smooth blend between kinematic and physics

**2. Recovery System**
```gdscript
# Allow players to recover from non-fatal ragdoll states
func attempt_recovery() -> bool:
    if health > 0 and ragdoll_body.is_stable():
        transition_back_to_kinematic()
        EventBus.player_recovered.emit(self)
        return true
    return false

func is_stable() -> bool:
    # Check if ragdoll has settled (low velocity, upright-ish)
    return ragdoll_body.linear_velocity.length() < STABILITY_THRESHOLD
```

**3. Advanced Ragdoll Features**
- **Limb Dismemberment**: Remove joints on severe damage
- **Blood Effects**: Particle systems attached to ragdoll parts
- **Sound Integration**: Bone breaking, body impact sounds
- **Environmental Interactions**: Ragdolls affect physics objects

## File Structure

```
scripts/
├── physics/
│   ├── ragdoll_manager.gd          # Singleton for ragdoll management
│   ├── ragdoll_builder.gd          # Creates ragdolls from characters
│   ├── ragdoll_part.gd             # Individual body part physics
│   ├── physics_transition.gd       # Handles state transitions
│   └── ragdoll_pool.gd             # Object pooling system
├── player/
│   ├── base_player.gd              # Enhanced with physics states
│   ├── player_physics_controller.gd # Kinematic movement logic
│   ├── player_death_handler.gd     # Death and revival logic
│   └── player_ragdoll_bridge.gd    # Interface between systems
└── core/
    ├── collision_layers.gd         # Updated layer definitions
    └── physics_config.gd           # Physics constants and settings
```

## Benefits of This Approach

1. **Responsive Gameplay**: CharacterBody2D provides precise, responsive controls for living characters
2. **Satisfying Physics**: Full ragdoll simulation creates dramatic death sequences
3. **Performance Optimized**: Physics complexity only when needed
4. **Modular Design**: Clean separation allows easy modification and extension
5. **Scalable**: Easy to add more physics states (stumbling, partial ragdoll, etc.)
6. **Duck Game Authenticity**: Mirrors the successful dual-system approach

## Implementation Priority

1. **Core Ragdoll System**: RagdollManager, RagdollBuilder, RagdollPart
2. **Basic Transition**: Death triggers simple ragdoll creation
3. **Visual Polish**: Smooth transitions, proper sprite mapping
4. **Performance**: Object pooling, culling, optimization
5. **Advanced Features**: Partial states, recovery, environmental interaction

## Testing Strategy

1. **Unit Tests**: Individual ragdoll components
2. **Integration Tests**: Character to ragdoll transitions
3. **Performance Tests**: Multiple ragdolls, stress testing
4. **Gameplay Tests**: Feel, responsiveness, fun factor

This approach will create a robust, performant ragdoll system that enhances the game's combat feel while maintaining responsive character controls during normal gameplay. 