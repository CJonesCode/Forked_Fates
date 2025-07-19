# Universal Interaction System - Future Vision

**Date**: Future Implementation  
**Status**: Vision Document - Post Architecture Fixes  
**Dependencies**: Requires completion of weapon_system_architecture_fixes.md first  
**Scope**: Mario Party-style minigame variety with Duck Game weapon preservation  

## Executive Summary

**Vision**: Create a **Universal Interaction System** that enables **unlimited minigame variety** while preserving the excellent Duck Game throwing mechanics as the premier combat system.

**Current Foundation**: Duck Game weapon mechanics are **working perfectly** - throwing, collision, damage, pooling all functional. Architecture fixes (see `weapon_system_architecture_fixes.md`) will create clean foundation for this Universal System.

**Goal**: Support Mario Party-style diversity:
- **Combat Minigames**: Duck Game weapons (pistols, bats, throwable projectiles)
- **Racing Minigames**: Power-ups, hazards, vehicle modifications  
- **UI Minigames**: Buttons, cards, interface elements
- **Strategy Minigames**: Board pieces, tokens, drag-and-drop elements

## Foundation Status

### **✅ Duck Game Mechanics (Working)**
```gdscript
# Core throwing mechanics - fully functional
weapon.fire_weapon()    # Fire held weapon
weapon.throw_weapon()   # Throw weapon as dangerous projectile  
weapon.pickup_weapon()  # Pick up nearby weapon
```

**Current Achievements**:
- **Pure Throwing-Centric Philosophy**: Everything thrown becomes dangerous projectiles ✅
- **Collision System**: Proper projectile collision detection ✅
- **Object Pooling**: Bullets and weapons properly pooled ✅
- **Minigame Integration**: Works perfectly in Sudden Death ✅

### **🔧 Architecture Foundation (Prerequisite)**
**Dependencies**: Complete `weapon_system_architecture_fixes.md` first

Required architectural patterns from agent_context_guide:
- **Factory Patterns**: ItemFactory.create_item() for all objects
- **Configuration-Driven**: ItemConfig .tres files for all properties  
- **Event-Driven Communication**: EventBus for loose coupling
- **Lazy Loading**: On-demand resource loading
- **Interface-Based Design**: Clean abstraction layers

**Status**: See `weapon_system_architecture_fixes.md` for implementation plan

## Universal Interaction System Implementation 🌟

**Goal**: Enable unlimited minigame variety while preserving Duck Game weapons as premier combat system  
**Dependencies**: Requires weapon_system_architecture_fixes.md completion first

### **Phase 10: Universal Interaction Framework**
**Scope**: Foundation supporting Duck Game weapons, racing power-ups, UI buttons, board pieces

```gdscript
# Universal interaction interface
class_name IInteractable extends RefCounted
virtual func can_interact(player: BasePlayer, interaction_type: InteractionType) -> bool: pass
virtual func interact(player: BasePlayer, interaction_data: Dictionary) -> InteractionResult: pass

enum InteractionType {
    COLLISION,      # Auto-collect (coins, power-ups)
    PROXIMITY,      # Get near (hidden items, zones)
    MANUAL_PICKUP,  # Press button to grab (Duck Game weapons)
    MANUAL_USE,     # Press button to activate (Duck Game firing)
    CLICK,          # Mouse/touch (UI buttons, cards)
    DRAG,           # Drag and drop (board pieces)
    THROW,          # Duck Game throwing mechanics
    AREA_OCCUPY     # Stand in area (king of hill)
}

enum InteractionResult { CONSUMED, ACTIVATED, CARRIED, TRIGGERED, FAILED }
```

**Implementation**:
- Universal InteractionManager coordinates per-minigame interactions
- InteractableFactory creates items with appropriate interaction types
- EventBus handles interaction events across systems

### **Phase 11: Duck Game Weapon Integration**
**Critical**: Preserve ALL current throwing mechanics within Universal System

```gdscript
# Duck Game weapons become IInteractable - ZERO behavior changes
class_name BaseWeapon implements IInteractable

func can_interact(player: BasePlayer, interaction_type: InteractionType) -> bool:
    match interaction_type:
        InteractionType.MANUAL_PICKUP: return can_be_picked_up and not is_held
        InteractionType.MANUAL_USE: return is_held and has_ammo()
        InteractionType.THROW: return is_held
        _: return false

func interact(player: BasePlayer, interaction_data: Dictionary) -> InteractionResult:
    # Route to existing methods - no behavior changes!
    match interaction_data.interaction_type:
        InteractionType.MANUAL_PICKUP: return _pickup_weapon(player)
        InteractionType.MANUAL_USE: return _fire_weapon(player) 
        InteractionType.THROW: return _throw_weapon(player, interaction_data)
```

**Success Criteria**: Sudden Death plays identically with Universal System

### **Phase 12: Combat Minigame Specialization**  
**Goal**: Combat minigames inherit full Duck Game weapon arsenal

```gdscript
class_name CombatMinigame extends PhysicsMinigame

func _spawn_minigame_specific_items():
    interaction_manager.enabled_interactions = [
        InteractionType.MANUAL_PICKUP,  # Duck Game pickup
        InteractionType.MANUAL_USE,     # Duck Game firing
        InteractionType.THROW           # Duck Game throwing
    ]
    
    InteractableFactory.create_interactable("pistol", weapon_spawn_1)
    InteractableFactory.create_interactable("bat", weapon_spawn_2)
```

**Minigame Types**: Sudden Death, King of Hill, Team Battle, Last Stand

### **Phase 13: Racing Minigame System**
**Goal**: Racing gets racing-specific items - NO Duck Game weapons

```gdscript
class_name RacingMinigame extends PhysicsMinigame

func _spawn_minigame_specific_items():
    interaction_manager.enabled_interactions = [
        InteractionType.COLLISION,      # Auto-collect power-ups
        InteractionType.PROXIMITY       # Trigger zone effects
    ]
    
    InteractableFactory.create_interactable("speed_boost", powerup_spawn_1)
    InteractableFactory.create_interactable("oil_slick", hazard_spawn_1)
```

**Racing Items**: Speed boosts, hazards, vehicle modifications with collision-based activation

### **Phase 14: UI Minigame System**
**Goal**: UI games get interface elements - NO physics items

```gdscript
class_name UIMinigame extends BaseMinigame

func _spawn_minigame_specific_items():
    interaction_manager.enabled_interactions = [
        InteractionType.CLICK           # UI button interactions only
    ]
    
    InteractableFactory.create_interactable("simon_button", ui_container_1)
```

**UI Items**: Buttons, score displays, card interfaces with click-based activation

### **Phase 15: Strategy Minigame System**
**Goal**: Board games get pieces and tokens - discrete turn-based interactions

```gdscript
class_name TurnBasedMinigame extends BaseMinigame

func _spawn_minigame_specific_items():
    interaction_manager.enabled_interactions = [
        InteractionType.CLICK,          # Select pieces
        InteractionType.DRAG            # Move pieces
    ]
    
    InteractableFactory.create_interactable("chess_piece", board_position_1)
```

**Strategy Items**: Chess pieces, cards, tokens with drag-and-drop mechanics

## Phase 16: Minigame Item Catalogs 📋

**Goal**: Data-driven item spawning per minigame type

### **Combat Catalogs**
```json
{
    "sudden_death": {
        "available_items": ["pistol", "bat"],
        "enabled_interactions": ["MANUAL_PICKUP", "MANUAL_USE", "THROW"]
    },
    "king_of_hill": {
        "available_items": ["pistol", "bat", "shield"],
        "enabled_interactions": ["MANUAL_PICKUP", "MANUAL_USE", "THROW", "AREA_DEPLOY"]
    }
}
```

### **Racing Catalogs**  
```json
{
    "speed_racing": {
        "available_items": ["speed_boost", "turbo_charge", "oil_slick"],
        "enabled_interactions": ["COLLISION", "PROXIMITY"]
    }
}
```

### **UI/Strategy Catalogs**
```json
{
    "simon_says": {
        "available_items": ["simon_button", "timer_display"],
        "enabled_interactions": ["CLICK"]
    },
    "chess_battle": {
        "available_items": ["chess_piece", "game_card"],
        "enabled_interactions": ["CLICK", "DRAG"]
    }
}
```

**Benefits**: Designers can create new minigames by configuring catalogs without programming

## Implementation Timeline

### **Prerequisites (2-3 weeks)**
Complete `weapon_system_architecture_fixes.md` phases 4-9:
- Factory patterns, configuration-driven properties
- Event-driven communication, lazy loading  
- Interface-based design for modularity

### **Universal System (4-6 weeks)**
- **Phases 10-11**: IInteractable interface + Duck Game preservation
- **Phases 12-13**: Combat and Racing minigame systems
- **Phases 14-15**: UI and Strategy minigame systems  
- **Phase 16**: Data-driven catalog system

### **Total Timeline**: 6-9 weeks for complete Universal Interaction System

## Conclusion

### **🎯 Vision: Unlimited Minigame Variety**
The Universal Interaction System will enable **Mario Party-style diversity** while preserving Duck Game's excellent throwing mechanics:

**Combat Minigames** → Duck Game weapons (pistols, bats, projectiles)  
**Racing Minigames** → Power-ups, hazards, vehicle modifications  
**UI Minigames** → Buttons, cards, interface elements  
**Strategy Minigames** → Board pieces, tokens, drag-and-drop elements

### **🏗️ Implementation Strategy**
1. **Architecture Foundation** (2-3 weeks): Complete `weapon_system_architecture_fixes.md`
2. **Universal Interface** (1-2 weeks): IInteractable system preserving Duck Game mechanics  
3. **Minigame Diversity** (3-4 weeks): Racing, UI, Strategy systems with appropriate items
4. **Data-Driven Catalogs** (1 week): Designer-friendly configuration system

### **🎮 Success Metrics**
**Immediate**: Duck Game mechanics work identically within Universal System  
**Long-term**: 4+ minigame types with distinct interaction patterns  
**Developer**: Data-driven catalog system for easy content creation

### **Current Status**
**Foundation Ready**: Duck Game throwing mechanics are excellent and fully functional  
**Next Step**: Complete architectural fixes to enable Universal System implementation  
**Timeline**: 6-9 weeks for complete Mario Party-style minigame variety

The Universal Interaction System will transform Forked Fates into a true party game platform supporting unlimited minigame variety while keeping Duck Game's throwing mechanics as the premier combat experience. 