# Forked Fates - Development Tasks & Context

**Project Type**: Mario Party-style Minigame Collection with Slay the Spire Map Progression  
**Engine**: Godot 4.4.1  
**Current Status**: Component-based architecture implemented, critical bugs identified  
**Last Updated**: Current Analysis

## 🎮 Project Vision

**Forked Fates** combines:
- **Mario Party-style minigames** for varied party gameplay experiences
- **Slay the Spire-style map progression** with node-based advancement
- **Duck Game-style ragdoll physics** for chaotic combat mechanics

### Core Gameplay Loop
1. Players navigate a procedurally generated map with connected nodes
2. Each node represents a different minigame or event
3. Minigames determine player progression, rewards, and relationships
4. Players advance through the map until reaching the final confrontation

## 🏗️ Current Architecture Status

### ✅ **Implemented & Working**
- **Component-based Player System**: Movement, Health, Inventory, Input, Ragdoll components
- **Minigame Framework**: 3-tier system (Physics/UI/Turn-based minigames)
- **Signal Architecture**: EventBus for decoupled communication
- **Object Pooling**: Performance optimization for bullets/items
- **Factory Patterns**: Consistent object creation
- **One Complete Minigame**: Sudden Death elimination combat

### ⚠️ **Partially Implemented**
- **Map System**: UI placeholder exists, generation logic needed
- **AI System**: Architecture ready, no implementation
- **Additional Minigames**: Framework supports many, only one exists

### ❌ **Not Started**
- **Assets**: Using placeholder graphics/audio
- **Networking**: Architecture ready for multiplayer

## 🐛 CRITICAL BUGS (Fix Immediately)

### 1. **EventBus Signal Parameter Mismatch** 🚨
**File**: `autoloads/event_bus.gd` vs `scripts/player/base_player.gd`
```gdscript
# Signal defined with 2 params:
signal player_health_changed(player_id: int, new_health: int)

# Emitted with 3 params:
EventBus.player_health_changed.emit(player_data.player_id, new_health, max_health)
```
**Impact**: Runtime errors, UI updates failing

### 2. **GameConfig Access Pattern Bug** 🚨
**Files**: All player components (`health_component.gd`, `movement_component.gd`, etc.)
```gdscript
# INCORRECT - Resource doesn't have .get() method:
max_health = player.game_config.default_max_health if player.game_config.has_method("get") and player.game_config.get("default_max_health", null) != null else max_health

# SHOULD BE:
max_health = player.game_config.default_max_health if player.game_config else max_health
```
**Impact**: Configuration values not loading, potential crashes

### 3. **Null Safety Crash Risk** 💥
**File**: `scripts/player/components/base_component.gd:22`
```gdscript
Logger.debug("Component " + get_class() + " initialized for " + player.player_data.player_name, get_class())
```
**Issue**: `player.player_data` can be null during initialization
**Impact**: Game crashes during player spawning

### 4. **Bullet Collision Logic Error** 🎯
**File**: `scripts/items/bullet.gd:82-85`
```gdscript
if body == shooter:
    has_hit = false  # BUG: This can cause multiple collision processing
    return
```
**Impact**: Bullets hitting multiple targets, performance issues

### 5. **Incorrect Super() Calls** 🔄
**File**: `scripts/minigames/core/ui_minigame.gd`
```gdscript
func _on_pause() -> void:
    super._ready()  # WRONG: Should be super()
```
**Impact**: Inherited functionality not working properly

## 📋 TASK LIST (Prioritized)

### 🚨 **PHASE 1: Critical Bug Fixes** (Do First)
- [ ] **Fix EventBus signal mismatch** - Update signal definition to match emissions
- [ ] **Simplify GameConfig access** - Remove complex has_method checks, use direct property access
- [ ] **Add null safety checks** - Protect component initialization from null player_data
- [ ] **Fix bullet collision logic** - Proper has_hit flag management
- [ ] **Correct super() calls** - Fix inheritance method calls in UI minigames

### 🎨 **PHASE 2: Code Quality** (After bugs fixed)
- [ ] **Add missing type hints** - Complete strict typing in bat.gd, pistol.gd, player_hud.gd
- [ ] **Standardize variable naming** - Ensure snake_case throughout
- [ ] **Add comprehensive null checks** - Especially in item and player interactions
- [ ] **Document signal contracts** - Clear documentation for all signal parameters

### 🎮 **PHASE 3: Core Minigames** (Expand gameplay)
- [ ] **Racing Minigame** - Vehicle-based competition using Level 2 system override
- [ ] **Simon Says** - UI-based memory game using Level 3 complete replacement
- [ ] **King of the Hill** - Territory control variant of Sudden Death
- [ ] **Puzzle Challenge** - Turn-based logic minigame
- [ ] **Treasure Hunt** - Exploration and collection minigame

### 🗺️ **PHASE 4: Map System** (Core progression)
- [ ] **Map Generation Algorithm** - Random node placement with valid paths
- [ ] **Node Types Implementation** - Minigame, Event, Shop, Boss nodes
- [ ] **Player Progression Logic** - Track advancement through map
- [ ] **Map State Persistence** - Save/load map progress
- [ ] **Victory Conditions** - End-game scenarios and win states

### 🤖 **PHASE 5: AI System** (Computer players)
- [ ] **Basic AI Behaviors** - Simple computer players for minigames
- [ ] **Difficulty Scaling** - Easy/Medium/Hard AI opponents
- [ ] **AI Personalities** - Different behavioral patterns (aggressive, defensive, etc.)
- [ ] **Minigame-specific AI** - Tailored behaviors for each game type

### 🎨 **PHASE 6: Polish & Assets** (Visual/Audio)
- [ ] **Character Art** - Player sprites and animations
- [ ] **Minigame Assets** - Backgrounds, UI elements, effects
- [ ] **Sound Effects** - Combat, movement, UI feedback
- [ ] **Music System** - Background music with dynamic switching
- [ ] **Particle Effects** - Visual feedback for actions

### 🌐 **PHASE 7: Multiplayer** (Online play)
- [ ] **Network Architecture** - Client/server setup
- [ ] **State Synchronization** - Player positions, game state
- [ ] **Input Prediction** - Smooth online experience
- [ ] **Matchmaking System** - Find and join games
- [ ] **Spectator Mode** - Watch ongoing games

## 🎯 **Immediate Next Steps**

1. **START HERE**: Fix the EventBus signal mismatch (Phase 1, Item 1)
2. **Then**: Simplify GameConfig access patterns (Phase 1, Item 2)
3. **Test**: Verify no crashes during player spawning
4. **Validate**: Confirm all existing functionality still works

## 📊 **Success Metrics**

- [ ] Zero runtime crashes during normal gameplay
- [ ] All minigames playable start-to-finish
- [ ] Consistent 60fps performance with 4 players
- [ ] Clean code passing all style guidelines
- [ ] Comprehensive test coverage for core systems

## 🔧 **Development Guidelines**

### **For Minigame Development**
1. Choose appropriate base class (PhysicsMinigame/UIMinigame/TurnBasedMinigame)
2. Implement required virtual methods
3. Use standard managers where possible
4. Test with 2-4 players
5. Add to MinigameRegistry

### **For Bug Fixes**
1. Create reproduction case
2. Fix root cause, not symptoms
3. Test related functionality
4. Update any affected documentation
5. Verify no regressions

### **For New Features**
1. Follow component-based architecture
2. Use factory patterns for object creation
3. Emit events through EventBus
4. Add proper error handling
5. Include configuration options

---

**Remember**: This is a party game - prioritize fun, chaos, and player interaction over complex mechanics. The goal is laughs and memorable moments with friends! 🎉 