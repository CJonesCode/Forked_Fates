# Forked Fates Comprehensive Refactor Plan

**Version**: 1.0  
**Date**: Current Analysis  
**Status**: Proposed Comprehensive Improvements  

## Executive Summary

The current Forked Fates codebase demonstrates solid foundational architecture with good signal-based communication and type safety. However, it requires both architectural improvements and code hygiene updates to align with Godot 4 best practices. This comprehensive plan addresses both immediate code quality issues and long-term architectural concerns through a systematic, phased approach that maintains system stability while improving maintainability and extensibility.

### Key Findings

**Code Quality Issues:**
- Inconsistent strict typing across scripts
- Missing `super()` calls in lifecycle methods
- Oversized monolithic classes (BasePlayer.gd >650 LOC)
- Excessive runtime logging affecting performance
- Magic numbers scattered throughout codebase

**Architectural Concerns:**
- Monolithic minigame system handling too many responsibilities
- UI coupling issues with scattered state management
- Player system overload violating single responsibility
- Item-player tight coupling hindering independent testing
- Missing component architecture for extensible mechanics

## Current Architecture Analysis

### Strengths ✅
- **Signal-Based Communication**: EventBus provides excellent decoupling
- **Type Safety**: Proper GDScript typing in most areas
- **Collision Management**: Centralized CollisionLayers enum system
- **Configuration System**: GameConfig eliminates many magic numbers
- **Input Abstraction**: Flexible InputConfig system
- **Scene Management**: Clean transitions via Main.gd

### Critical Issues Identified

#### 1. **Monolithic Systems**
- **SuddenDeathMinigame**: Handles player spawning, item management, damage processing, UI management, respawn logic, and victory conditions
- **BasePlayer**: Combines physics, input handling, item management, health, and state in single class

#### 2. **Code Quality Violations**
- Inconsistent strict typing (`var` without type hints)
- Missing `super()` calls in inherited lifecycle methods
- Verbose `print()` statements throughout codebase
- Magic numbers not properly abstracted

#### 3. **Coupling Issues**
- PlayerHUD instantiated within minigame rather than global system
- Items directly reference and manipulate players
- Mixed use of EventBus and direct node references

#### 4. **Minigame Control & State Management**
- No comprehensive override system for minigames to control all gameplay aspects
- Lack of standardized communication protocol between minigames and persistent map state
- No clear data flow for territory control, player relationships, and economic changes
- Missing rollback/snapshot system for failed or abandoned minigames

#### 5. **Missing Architecture Patterns**
- No component system for extensible player abilities
- No factory patterns for object creation
- No proper data access layer

## Comprehensive Refactor Plan: 6 Phases

---

## Phase 1: Code Hygiene & Style Compliance
**Priority**: Critical  
**Duration**: 1-2 weeks  
**Risk**: Low  

### 1.1 Type Safety & Standards
- Enforce strict typing across all scripts (`var name: String` instead of `var name`)
- Add explicit `super()` calls in all overridden lifecycle methods
- Replace magic numbers with `const` values in dedicated config classes
- Update all variable and function names to follow snake_case conventions

### 1.2 Logging & Debug Cleanup
- Replace excessive `print()` calls with structured logging system
- Implement `Logger` utility gated by build flags
- Remove or gate debug-only code paths

### 1.3 Documentation Standards
- Add docstrings for all public methods and signals
- Document signal contracts with parameter types and descriptions
- Create inline comments for complex logic blocks

### 1.4 CI/CD Integration
- Set up GDScript-Lint for automated style checking
- Configure pre-commit hooks for style validation
- Update `.editorconfig` with project formatting standards

**Deliverables:**
- Style-compliant codebase with CI gates
- Logger utility class
- Updated development documentation

---

## Phase 2: Minigame System Decomposition
**Priority**: High  
**Duration**: 2-3 weeks  
**Risk**: Medium  

### 2.1 Create Truly Flexible Minigame Framework
```
scripts/minigames/core/
├── base_minigame.gd             # Minimal lifecycle interface only
├── minigame_registry.gd         # Dynamic minigame discovery and loading
├── minigame_context.gd          # Shared context for map state communication
└── standard_managers/           # OPTIONAL common components
    ├── player_spawner.gd        # For minigames that need BasePlayer
    ├── item_spawner.gd          # For minigames with items
    ├── victory_condition_manager.gd # For elimination/scoring games
    └── respawn_manager.gd       # For games with respawning
```

**Key Change**: Managers are **optional tools**, not required dependencies.

### 2.2 Minimal Base Minigame Interface
```gdscript
class_name BaseMinigame
extends Node

# Minimal required interface - all minigames implement these
signal minigame_started()
signal minigame_ended(result: MinigameResult)

@export var minigame_name: String = "Unknown Minigame"
@export var max_players: int = 4
@export var min_players: int = 1

# Virtual methods - minigames implement what they need
func initialize_minigame(context: MinigameContext) -> void:
    # Setup phase - receive player data, map state, etc.
    pass

func start_minigame() -> void:
    # Begin gameplay
    minigame_started.emit()

func end_minigame(result: MinigameResult) -> void:
    # Cleanup and return results
    minigame_ended.emit(result)

func pause_minigame() -> void:
    # Optional: Handle pause state
    pass

func resume_minigame() -> void:
    # Optional: Handle resume from pause
    pass

# Examples of specialized implementations:

# Physics-based minigame (like SuddenDeath)
class_name PhysicsMinigame
extends BaseMinigame

@onready var player_spawner: PlayerSpawner = $PlayerSpawner
@onready var item_spawner: ItemSpawner = $ItemSpawner
# Uses standard managers when needed

# UI-based minigame (like Simon Says)
class_name UIMinigame  
extends BaseMinigame

@onready var game_ui: Control = $GameUI
# No physics managers needed - pure UI interaction

# Turn-based minigame (like strategy games)
class_name TurnBasedMinigame
extends BaseMinigame

@onready var game_board: GridContainer = $GameBoard
@onready var turn_manager: TurnManager = $TurnManager
# Completely different interaction paradigm
```

### 2.3 Implement Specialized Managers
- **PlayerSpawner**: Handle player creation, positioning, and lifecycle
- **ItemSpawner**: Manage item spawning with object pooling
- **VictoryConditionManager**: Evaluate game end conditions with configurable rules
- **RespawnManager**: Handle player death/respawn cycles

### 2.3 Complete System Override Architecture
Minigames need **complete autonomy** over all game systems. Rather than "overriding" existing systems, they should be able to **replace them entirely** or **ignore them completely**:

```gdscript
class_name MinigameContext
extends Resource

# What the minigame receives from the map/session
@export var participating_players: Array[PlayerData]
@export var map_state_snapshot: MapSnapshot
@export var available_systems: Dictionary  # Optional systems minigame can use

# What the minigame can control
func request_system_override(system_name: String, replacement: Node) -> void:
    # Replace core systems (physics, input, UI) with custom implementations
    pass

func disable_system(system_name: String) -> void:
    # Completely disable systems the minigame doesn't need
    pass

func get_standard_manager(manager_type: String) -> Node:
    # Optionally use standard managers (PlayerSpawner, ItemSpawner, etc.)
    return null
```

#### System Control Levels:

**Level 1: Standard Override** (for similar minigames)
```gdscript
# Sudden Death variant - tweaks existing systems
class_name FastPacedSuddenDeath
extends PhysicsMinigame

func initialize_minigame(context: MinigameContext) -> void:
    super.initialize_minigame(context)
    # Use standard systems but modify parameters
    player_spawner.modify_spawn_settings({"health": 1, "speed": 500})
    item_spawner.set_spawn_rate(2.0)  # Faster item spawning
```

**Level 2: Selective Replacement** (hybrid approach)
```gdscript
# Racing game - replaces player system, keeps items
class_name RacingMinigame
extends BaseMinigame

func initialize_minigame(context: MinigameContext) -> void:
    # Disable standard player system
    context.disable_system("player_spawner")
    context.disable_system("base_player")
    
    # Use custom vehicle system
    var vehicle_spawner = preload("res://minigames/racing/VehicleSpawner.gd").new()
    context.request_system_override("player_spawner", vehicle_spawner)
    
    # Keep item system for power-ups
    item_spawner = context.get_standard_manager("item_spawner")
```

**Level 3: Complete Replacement** (totally different games)
```gdscript
# Simon Says - ignores all physics/items, pure UI
class_name SimonSaysMinigame
extends UIMinigame

func initialize_minigame(context: MinigameContext) -> void:
    # Disable ALL standard systems
    context.disable_system("player_spawner")
    context.disable_system("item_spawner")
    context.disable_system("physics")
    
    # Create custom UI-only interaction
    var ui_controller = preload("res://minigames/simon/UIController.gd").new()
    add_child(ui_controller)
    
    # Track players as data only, no BasePlayer instances needed
    player_states = {}
    for player in context.participating_players:
        player_states[player.player_id] = {"alive": true, "mistakes": 0}
```

#### System Categories Minigames Can Control:
- **Player Representation**: BasePlayer, vehicles, UI avatars, data-only tracking
- **Input Handling**: Real-time, turn-based, gesture, voice, mouse-only
- **Physics**: Character physics, vehicle physics, no physics, custom simulation
- **UI Paradigm**: HUD overlay, full-screen interface, board game layout
- **Time Flow**: Real-time, turn-based, pausable, time pressure
- **Win Conditions**: Elimination, scoring, puzzle completion, survival
- **Networking**: P2P combat, turn relay, central authority, async play

### 2.4 Map State Communication Protocol
Minigames must communicate critical state information back to the map system for persistent world effects:

```gdscript
# Data structure for minigame results
class_name MinigameResult
extends Resource

@export var outcome: MinigameOutcome
@export var participating_players: Array[int]
@export var winners: Array[int] 
@export var statistics: Dictionary  # kills, deaths, items used, etc.
@export var rewards_earned: Array[Reward]
@export var penalties_applied: Array[Penalty]
@export var territory_changes: TerritoryChangeData
@export var item_state_changes: Array[ItemStateChange]
@export var player_relationship_changes: Array[RelationshipChange]

enum MinigameOutcome {
    VICTORY,
    DEFEAT, 
    DRAW,
    TIMEOUT,
    ABANDONED
}
```

#### Information Flow: Minigame → Map State
1. **Player State Updates**:
   - Health changes that persist post-minigame
   - Inventory modifications (items gained/lost)
   - Skill progression or experience points
   - Status effects that carry over

2. **World State Changes**:
   - Territory control modifications
   - Resource node ownership changes
   - Environmental damage or improvements
   - Unlocked areas or blocked passages

3. **Relationship Matrix Updates**:
   - Alliance formations or betrayals
   - Trust/reputation score adjustments
   - Temporary or permanent enemy status
   - Trade agreement modifications

4. **Economic Impact**:
   - Currency/resource rewards distribution
   - Market price fluctuations from minigame results
   - Trade route availability changes
   - Economic sanctions between players

#### Map State Interface:
```gdscript
# Communication bridge between minigames and overworld
class_name MapStateInterface
extends Node

signal minigame_completed(result: MinigameResult)
signal map_state_updated(changes: Array[StateChange])

func apply_minigame_results(result: MinigameResult) -> void:
    _update_player_states(result.participating_players, result.statistics)
    _apply_territory_changes(result.territory_changes)
    _process_relationship_changes(result.player_relationship_changes)
    _distribute_rewards_and_penalties(result.rewards_earned, result.penalties_applied)
    
    map_state_updated.emit(_generate_change_summary(result))
    
func get_pre_minigame_snapshot() -> MapSnapshot:
    # Capture current state for rollback scenarios
    return MapSnapshot.new(current_map_state)
```

### 2.5 Refactor SuddenDeathMinigame as Example
- Inherit from `PhysicsMinigame` (demonstrates Level 1 override)
- Use standard managers (PlayerSpawner, ItemSpawner, VictoryConditionManager)
- Implement territory control victory conditions via context system
- Demonstrate clean architecture with improved gameplay systems
- Serve as reference implementation for physics-based minigames

**Deliverables:**
- Flexible minigame framework supporting complete system replacement
- Map state communication protocol with MinigameResult and MapStateInterface
- BaseMinigame class with minimal interface requirements
- MinigameContext system for complete control over game systems
- Standard manager library (optional tools for common patterns)
- Refactored SuddenDeathMinigame as physics-based example
- Templates for UIMinigame and TurnBasedMinigame patterns
- Unit tests for each standard manager component
- Integration tests for map state synchronization
- Documentation for all three system control levels

---

## Phase 3: Player System Component Architecture
**Priority**: High  
**Duration**: 3-4 weeks  
**Risk**: High  

### 3.1 Create Component System
```
scripts/player/components/
├── movement_component.gd        # Physics and movement logic
├── health_component.gd          # Health management and damage
├── inventory_component.gd       # Item handling and storage
├── input_component.gd           # Input processing and mapping
└── ragdoll_component.gd         # Ragdoll physics and transitions
```

### 3.2 Refactor BasePlayer as Component Coordinator
```gdscript
class_name BasePlayer
extends CharacterBody2D

# Component references with strict typing
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var input: InputComponent = $InputComponent
@onready var ragdoll: RagdollComponent = $RagdollComponent

func _ready() -> void:
    super()
    _setup_components()
    _connect_component_signals()

func _setup_components() -> void:
    # Configure component dependencies and initialization
    pass

func _connect_component_signals() -> void:
    # Wire up component communication via signals
    health.died.connect(_on_health_died)
    inventory.item_used.connect(_on_inventory_item_used)
```

### 3.3 Implement Typed Component Communication
```gdscript
# Example: HealthComponent with proper signal typing
class_name HealthComponent
extends Node

signal health_changed(new_health: int, max_health: int)
signal damage_taken(amount: int, source: Node)
signal died()
signal respawned()

@export var max_health: int = 3
var current_health: int : set = _set_current_health

func _set_current_health(value: int) -> void:
    var old_health: int = current_health
    current_health = clampi(value, 0, max_health)
    if current_health != old_health:
        health_changed.emit(current_health, max_health)
        if current_health <= 0:
            died.emit()
```

### 3.4 Create Component Dependencies Management
- Components communicate primarily through signals
- Player coordinates component interactions
- Each component handles single, well-defined responsibility
- Components can be independently tested and configured

**Deliverables:**
- Component-based player system
- Comprehensive unit tests for each component
- Scene reconfiguration guide for designers
- Component interaction documentation

---

## Phase 4: UI System Redesign & Event Flow
**Priority**: Medium  
**Duration**: 2-3 weeks  
**Risk**: Medium  

### 4.1 Create Global UI Management
```
scripts/ui/core/
├── ui_manager.gd                # Global UI coordinator (autoload)
├── hud_controller.gd           # Game HUD management
├── screen_manager.gd           # Screen transitions and stack
└── ui_event_router.gd          # UI-specific event routing
```

### 4.2 Implement UIManager Autoload
```gdscript
class_name UIManager
extends Node

var current_hud: PlayerHUD = null
var screen_stack: Array[Control] = []

signal screen_pushed(screen_name: String)
signal screen_popped(screen_name: String)
signal hud_visibility_changed(visible: bool)

func show_game_hud(players: Array[PlayerData]) -> void:
    if current_hud == null:
        current_hud = preload("res://scenes/ui/player_hud.tscn").instantiate()
        get_tree().current_scene.add_child(current_hud)
    current_hud.setup_for_players(players)
    current_hud.visible = true
    hud_visibility_changed.emit(true)

func hide_game_hud() -> void:
    if current_hud != null:
        current_hud.visible = false
        hud_visibility_changed.emit(false)
```

### 4.3 Formalize EventBus Architecture
- Make EventBus the single global mediator for cross-system communication
- Remove direct calls from gameplay scripts to GameManager where possible
- Introduce typed SignalBus helper with automatic disconnection on `queue_free()`
- Create clear signal contracts and documentation

### 4.4 Refactor GameManager as State Machine
```gdscript
class_name GameManager
extends Node

enum GameState {
    MENU,
    LOADING,
    PLAYING,
    PAUSED,
    GAME_OVER
}

var current_state: GameState = GameState.MENU : set = _set_current_state
var player_registry: PlayerRegistry

signal state_changed(old_state: GameState, new_state: GameState)

func _set_current_state(new_state: GameState) -> void:
    var old_state: GameState = current_state
    current_state = new_state
    state_changed.emit(old_state, new_state)
    _handle_state_transition(old_state, new_state)
```

**Deliverables:**
- Global UI management system
- Decoupled event architecture
- State machine-based GameManager
- Signal documentation and contracts

---

## Phase 5: Scene & Resource Optimization
**Priority**: Medium  
**Duration**: 2-3 weeks  
**Risk**: Low  

### 5.1 Object Pooling Implementation
```gdscript
class_name ObjectPool
extends Node

var pool: Dictionary = {}

func get_object(scene_path: String) -> Node:
    if not pool.has(scene_path):
        pool[scene_path] = []
    
    if pool[scene_path].is_empty():
        return load(scene_path).instantiate()
    else:
        return pool[scene_path].pop_back()

func return_object(obj: Node, scene_path: String) -> void:
    obj.reset() # Assume objects have reset method
    pool[scene_path].append(obj)
```

### 5.2 Scene Structure Optimization
- Replace runtime-generated pickup areas with prefab scenes
- Implement object pooling for bullets, items, and effects
- Convert deprecated TileMap nodes to TileMapLayer system
- Update navigation queries for new TileMapLayer structure

### 5.3 Resource Management Improvements
- Audit preload() vs load() usage throughout codebase
- Move optional assets to lazy loading patterns
- Implement ResourceLoader GC pass in scene transitions
- Create resource preloading manifest for critical assets

### 5.4 Performance Monitoring
- Add profiling markers for key systems
- Implement performance dashboard for development builds
- Create automated performance regression tests

**Deliverables:**
- Object pooling system
- Optimized scene structures
- Resource management improvements
- Performance monitoring tools

---

## Phase 6: Data Layer & Factory Patterns
**Priority**: Low  
**Duration**: 2-3 weeks  
**Risk**: Low  

### 6.1 Create Factory System
```
scripts/core/factories/
├── player_factory.gd            # Player creation and configuration
├── item_factory.gd              # Item instantiation and setup
├── minigame_factory.gd          # Minigame initialization
└── ui_factory.gd                # UI component creation
```

### 6.2 Implement Data Access Layer
```gdscript
class_name DataManager
extends Node

var session_data: SessionData
var player_registry: Dictionary = {}
var game_settings: GameSettings

signal data_saved(save_name: String)
signal data_loaded(save_name: String)

func get_player_data(player_id: int) -> PlayerData:
    return player_registry.get(player_id, PlayerData.new())

func update_player_data(player_id: int, data: PlayerData) -> void:
    player_registry[player_id] = data
    # Trigger persistence if needed
```

### 6.3 Configuration System Expansion
```
configs/
├── player_configs/              # Player type definitions
├── item_configs/                # Item behavior configurations
├── minigame_configs/            # Minigame rule sets
└── ui_configs/                  # UI layout and theme configs
```

### 6.4 Save/Load System Implementation
- Resource-based save system with versioning
- Modular data serialization for different systems
- Clean slate save system optimized for new architecture
- Validation and error recovery for corrupted saves

**Deliverables:**
- Factory pattern implementation
- Data access layer
- Expanded configuration system
- Robust save/load functionality

---

## Implementation Strategy

### Migration Approach
1. **Clean Refactoring**: Replace existing systems with improved implementations
2. **Component-First Development**: Build new components with comprehensive testing
3. **Atomic Integration**: Complete system replacement rather than gradual migration
4. **Continuous Testing**: Unit tests for each new component before integration

### Risk Mitigation
- **Phase 3 High Risk**: Player system changes affect core gameplay
  - Create comprehensive test suite before refactoring
  - Implement in feature branch with extensive playtesting
  - Focus on improved functionality and performance over legacy behavior

### Success Metrics
- [ ] 100% type safety compliance across codebase
- [ ] Reduced coupling between major systems
- [ ] Improved test coverage (target: 80%+)
- [ ] Faster feature development velocity
- [ ] Cleaner separation of concerns
- [ ] Performance improvements in critical paths

## Timeline & Resource Allocation

| Phase | Duration | Priority | Risk | Dependencies |
|-------|----------|----------|------|--------------|
| 1 | 1-2 weeks | Critical | Low | None |
| 2 | 2-3 weeks | High | Medium | Phase 1 |
| 3 | 3-4 weeks | High | High | Phase 1, 2 |
| 4 | 2-3 weeks | Medium | Medium | Phase 1, 3 |
| 5 | 2-3 weeks | Medium | Low | Phase 2, 3 |
| 6 | 2-3 weeks | Low | Low | Phase 4, 5 |

**Total Estimated Duration**: 12-18 weeks  
**Recommended Team Size**: 2-3 developers  
**Overlap Potential**: Phases 4-6 can partially overlap

## Final File Structure

```
scripts/
├── core/
│   ├── factories/               # Object creation patterns
│   ├── managers/                # System coordinators
│   ├── data/                    # Data models and persistence
│   └── utilities/               # Shared utility classes
├── player/
│   ├── components/              # Player behavior components
│   ├── systems/                 # Player-related systems
│   └── controllers/             # Input and AI controllers
├── items/
│   ├── components/              # Item behavior components
│   └── types/                   # Specific item implementations
├── minigames/
│   ├── core/                    # Shared minigame framework
│   └── implementations/         # Specific minigame types
├── ui/
│   ├── core/                    # UI framework and management
│   ├── screens/                 # Game screens and menus
│   └── widgets/                 # Reusable UI components
├── map/                         # Map and level systems
├── physics/                     # Physics utilities and helpers
└── ai/                          # AI systems (future expansion)
```

## Conclusion

This comprehensive refactor plan addresses both immediate code quality issues and long-term architectural concerns. The phased approach ensures system stability while systematically improving maintainability, testability, and extensibility. By starting with code hygiene and moving through architectural improvements, the project will be well-positioned for future feature development and team scaling.

**Recommended Start**: Begin with Phase 1 (Code Hygiene) immediately, as it provides the foundation for all subsequent phases and has the lowest risk with immediate benefits.

**Success Criteria**: The refactor will be considered successful when the codebase demonstrates clean separation of concerns, comprehensive test coverage, consistent code quality, and improved development velocity for new features. 