# Forked Fates - AI Agent Context Guide

**Purpose**: Context reference for AI agents working on this codebase

## Project Overview

**Forked Fates** is a multiplayer party game combining:
- Duck Game-style ragdoll physics for chaotic combat
- Slay the Spire-style map progression for structured gameplay
- Mario Party-style minigames for varied experiences

**Current Status**: The codebase uses modern Godot 4.4 syntax with component-based architecture. All critical bugs have been resolved using architectural solutions. The inheritance hierarchy uses proper class_name patterns with full type safety. Configuration loading system uses proper .tres resource format. Memory management includes proper resource cleanup on shutdown. The weapon system is operational with object pooling, signal management, and UI cleanup. Universal damage system is implemented across all minigame types. Minigame-controlled lives and victory system provides flexibility for different game modes. **UI architecture achieves 100% consistency** using Factory + Manager pattern with no manual UI creation remaining in the codebase. **Steamworks networking is implemented** with lobby creation/joining via GodotSteam GDExtension, completely replacing IP-based networking.

## Architecture Summary

### **Design Philosophy**
- Component-based architecture for modularity
- Signal-driven communication for loose coupling  
- Factory patterns for consistent object creation
- Configuration-driven behavior for flexibility
- Lazy loading architecture - resources loaded only when needed
- Performance optimization with object pooling and deferred initialization
- Network-ready design (multiplayer planned)
- Universal base functionality with specialized implementations
- Question assumptions - find the right abstraction level

### **Core Systems Status**
- **Player System**: Component-based with 6 specialized components
- **Weapon System**: Operational with pistols, bullets, and melee weapons
- **Universal Damage System**: All minigame types support damage with specialized handling
- **Minigame Framework**: Flexible with 3 specialization levels + automatic UI cleanup
- **Lives & Victory System**: Minigame-controlled for maximum flexibility (infinite lives, elimination, etc.)
- **Respawn Management**: Minigame-controllable blocking system for different game modes
- **UI Architecture**: Complete Factory + Manager pattern with 100% consistency across codebase
- **Data Persistence**: Versioned save/load with validation, extracted data structures
- **Performance Systems**: Object pooling and monitoring with optimized logging
- **Configuration**: Lazy-loaded configs with caching, extracted global config classes
- **Lazy Loading Architecture**: Minimal startup overhead, resources loaded on-demand
- **Memory Management**: Proper resource cleanup on shutdown
- **Code Quality**: Clean static analysis results
- **Parse Errors**: Critical bugs resolved - 30+ Logger calls, 26 inner classes, autoload conflicts

## Critical File Locations

### **Autoloads (Global Systems)**
```
autoloads/
├── event_bus.gd           # Global signal relay with connection management
├── game_manager.gd        # State machine-based game coordinator
├── steam_manager.gd       # Steamworks integration and P2P networking
└── [5 additional autoloads listed in project.godot]

Additional Autoloads:
- UIManager: scripts/ui/core/ui_manager.gd
- PoolManager: scripts/core/pool_manager.gd  
- PerformanceDashboard: scripts/core/performance_dashboard.gd
- DataManager: scripts/core/data_manager.gd
- ConfigManager: scripts/core/config_manager.gd
```

### **Core Systems**
```
scripts/core/
├── factories/             # PlayerFactory, ItemFactory, MinigameFactory, UIFactory
├── data_structures/       # Extracted data classes (SessionData, SaveData, etc.)
│   ├── session_data.gd    # Session tracking data
│   ├── session_config.gd  # Session configuration
│   ├── game_settings.gd   # User preferences/settings
│   ├── save_data.gd       # Save game data structure
│   └── player_statistics.gd # Player performance data
├── collision_layers.gd    # Centralized collision management
├── logger.gd              # Structured logging system
├── game_config.gd         # Runtime configuration values
├── save_system.gd         # Save/load operations (uses preload pattern)
├── data_manager.gd        # Central data coordination
└── [performance & monitoring systems]
```

### **Player Architecture**
```
scripts/player/
├── base_player.gd         # Component coordinator (NOT monolithic)
└── components/            # 6 specialized components
    ├── base_component.gd      # Abstract base with lifecycle
    ├── movement_component.gd  # Physics, jumping, facing
    ├── health_component.gd    # Health, damage, death
    ├── inventory_component.gd # Items, pickup, use
    ├── input_component.gd     # Input processing
    └── ragdoll_component.gd   # Ragdoll physics
```

### **Weapon System (Operational)**
```
scripts/items/
├── base_item.gd           # Core item behavior with proper holder management
├── pistol.gd              # Ranged weapon with bullet spawning
├── bullet.gd              # Projectile with collision detection and pooling
└── bat.gd                 # Melee weapon with swing mechanics

Key Features:
- Object pooling for bullets and items
- Proper signal connection management
- Collision layer configuration
- Holder attachment system
- ItemFactory integration
```

### **Minigame Framework (Proper Inheritance + UI Management)**
```
scripts/minigames/core/
├── base_minigame.gd           # class_name BaseMinigame - Automatic UI cleanup
├── physics_minigame.gd        # class_name PhysicsMinigame - For physics-based games
├── ui_minigame.gd             # class_name UIMinigame - For UI-only games  
├── turn_based_minigame.gd     # class_name TurnBasedMinigame - For strategy games
├── minigame_context.gd        # class_name MinigameContext - System control interface
├── minigame_registry.gd       # class_name MinigameRegistry - Dynamic loading
└── standard_managers/         # Optional tools with proper class_name declarations
```

## Key Architecture Patterns

### **1. Component System (Player)**
```gdscript
# BasePlayer is a COORDINATOR, not a monolith
class_name BasePlayer extends CharacterBody2D

@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
# ... other components

# Components communicate via signals
health.died.connect(_on_health_died)
```

### **2. Weapon System (Operational Architecture)**

**Item Lifecycle with Proper Pooling**:
```gdscript
# Pistol shooting with pooled bullets
func _shoot() -> bool:
    var bullet: Node = PoolManager.get_bullet()
    var bullet_obj: Bullet = bullet as Bullet
    bullet_obj.is_pooled = true  # Critical for pool return
    
    # Proper scene attachment
    get_tree().current_scene.add_child(bullet_obj)
    bullet_obj.initialize(shoot_direction, global_position, holder)

# Bullet signal management (prevent duplicate connections)
func _ready() -> void:
    if not body_shape_entered.is_connected(_on_body_shape_entered):
        body_shape_entered.connect(_on_body_shape_entered)

# ItemFactory with proper config classes
static func create_item(item_id: String) -> BaseItem:
    var config: ItemConfig = load("res://configs/item_configs/" + item_id + ".tres")
    return config.item_scene.instantiate()
```

### **3. UI Architecture (Factory + Manager Pattern)**

**Design Philosophy**: Split UI responsibilities for clean separation of concerns
- **UIFactory**: Creates UI elements with consistent styling and configuration
- **UIManager**: Manages UI lifecycle, navigation, and coordination

**Architecture Pattern**:
```gdscript
# Step 1: UIFactory creates UI elements
var notification = UIFactory.create_notification(message, UIFactory.NotificationType.INFO)
var screen_scene = UIFactory.get_screen_scene("direct_connect")
var player_panel = UIFactory.create_player_panel(player_data, id, colors)

# Step 2: UIManager handles lifecycle and management  
UIManager.show_overlay(notification, "notification")
UIManager.push_screen(screen_scene, "direct_connect")
# Player panels go directly to containers - no global management needed
```

**Factory Creation Patterns**:
```gdscript
# Generic UI elements with configuration
var label_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
label_config.element_name = "StatusLabel"
label_config.text = "Ready"
label_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

var label: Node = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, label_config)

# Specialized UI creation  
var player_panel: Control = UIFactory.create_player_panel(player_data, player_id, colors)

# Screen creation from configuration files
var screen: Control = UIFactory.create_screen("direct_connect")  # Loads from .tres
var screen_scene: PackedScene = UIFactory.get_screen_scene("direct_connect")  # For UIManager
```

**Manager Coordination Patterns**:
```gdscript
# Screen navigation with stack management
UIManager.push_screen(screen_scene, "screen_name")  # Adds to navigation stack
UIManager.pop_screen()  # Returns to previous screen
UIManager.get_current_screen()  # Access active screen

# Overlay management with z-indexing
UIManager.show_overlay(ui_element, "overlay_name")  # Proper layering
UIManager.hide_overlay("overlay_name")  # Clean removal
UIManager.clear_all_overlays()  # Reset overlay state

# HUD lifecycle (automatic in minigames)
UIManager.show_game_hud(player_data_array)  # Called by PhysicsMinigame
UIManager.hide_game_hud()  # Called automatically by BaseMinigame.end_minigame()
```

**Usage Guidelines**:
- **Always create through UIFactory** - No manual `Label.new()`, `Button.new()`, etc.
- **Use UIManager for global UI** - Screen navigation, overlays, HUD coordination
- **Direct container for local UI** - Simple parent-child relationships don't need UIManager
- **Configuration-driven creation** - Use .tres files and UIElementConfig for styling
- **No bypass routes** - UIManager only accepts UIFactory-created elements

### **4. Minigame Inheritance Hierarchy (Clean Architecture + UI Management)**

**Inheritance Chain** with automatic UI cleanup:
```gdscript
# Base interface - automatic HUD cleanup on end
class_name BaseMinigame extends Node

func end_minigame(result) -> void:
    # ... game logic ...
    UIManager.hide_game_hud()  # Automatic UI cleanup
    _on_end(result)  # Virtual method for subclasses

# Physics specialization - standard managers integration  
class_name PhysicsMinigame extends BaseMinigame
func _on_physics_initialize() -> void:
    UIManager.show_game_hud(player_data_array)  # Show HUD for physics games

# Concrete implementation - game-specific logic
class_name SuddenDeathMinigame extends PhysicsMinigame
# Inherits automatic UI cleanup from BaseMinigame
```

### **4. Universal Damage System (Critical Thinking Pattern)**

**The Problem**: Weapons weren't dealing damage - where should damage handling go?

**Initial Thinking**: "Damage is for combat, put it in SuddenDeathMinigame"
```gdscript
SuddenDeathMinigame._on_player_damage_reported()  # Too specific!
```

**Better Thinking**: "Combat happens in physics games, put it in PhysicsMinigame"
```gdscript
PhysicsMinigame._on_player_damage_reported()  # Still too narrow!
```

**Best Thinking**: **"Wait - what other games could have damage?"**
- **Collection games**: Jump on other players, environmental hazards
- **Vehicle games**: Crash damage, collision slowdowns, tire damage  
- **Turn-based games**: Spell damage, attack actions, resource theft
- **UI games**: Button-mashing penalties, reaction failures, momentum loss

**Conclusion**: Damage is a **fundamental game mechanic**, not specific to any one type!

**Universal Architecture Implemented**:
```gdscript
# BaseMinigame - ALL types get damage handling
class_name BaseMinigame extends Node

func initialize_minigame(context: MinigameContext) -> void:
    # Universal damage connection for ALL minigame types
    EventBus.player_damage_reported.connect(_on_player_damage_reported)

func _on_player_damage_reported(victim_id, attacker_id, damage, source_name) -> void:
    var victim_data = find_player_in_context(victim_id)
    # Delegate to subclass for specialized handling
    _on_damage_reported(victim_id, attacker_id, damage, source_name, victim_data)

# Virtual method - each type implements damage differently
func _on_damage_reported(victim_id, attacker_id, damage, source_name, victim_data) -> void:
    # Default: log damage event
    # Subclasses override for specific mechanics
```

**Specialized Implementations**:
```gdscript
# PhysicsMinigame - Direct health damage
func _on_damage_reported(...) -> void:
    var player = player_spawner.get_player(victim_id)
    player.take_damage(damage)  # Reduces health, triggers death

# Future CollectionMinigame - Item/score penalty  
func _on_damage_reported(...) -> void:
    var player = get_collection_player(victim_id)
    player.drop_collected_items(damage)  # Lose collected items
    player.respawn_at_safe_location()     # Knockback effect

# Future VehicleMinigame - Speed/performance penalty
func _on_damage_reported(...) -> void:
    var vehicle = get_player_vehicle(victim_id)
    vehicle.reduce_speed(damage * 10)     # Slow down vehicle
    vehicle.add_damage_effect(source_name) # Visual damage

# Future TurnBasedMinigame - Queue for next turn
func _on_damage_reported(...) -> void:
    pending_damage_queue.append({
        "victim": victim_id, "damage": damage, "source": source_name
    })  # Apply on their next turn
```

### **5. Minigame-Controlled Lives & Victory System**

**The Problem**: Different minigames need different lives/respawn rules - should this be automatic?

**Previous Approach**: "Automatically decrement lives globally when any player dies"
```gdscript
GameManager._on_player_died():  # Always decrement lives
    player_data.current_lives -= 1  # Too rigid!
```

**Problem with Global Automation**:
- **Infinite Lives Games**: Can't have players respawn forever
- **King of the Hill**: Lives might decrement based on zone control, not death
- **Last Stand**: Players might start with 1 life only
- **Survival Mode**: Lives might increase over time or with pickups

**Better Architecture**: **"Each minigame controls its own rules"**

**Minigame-Controlled Implementation**:
```gdscript
# RespawnManager - minigames control who can respawn
respawn_manager.block_player_respawn(player_id)     # Prevent respawning
respawn_manager.unblock_player_respawn(player_id)   # Allow respawning again

# VictoryConditionManager - minigames control elimination
victory_condition_manager.eliminate_player(player_id)  # Manual elimination

# EventBus - minigames control UI updates
EventBus.emit_player_lives_changed(player_id, new_lives)  # Update UI when needed
```

**Different Minigame Examples**:
```gdscript
# Sudden Death - 3 Lives Elimination
class_name SuddenDeathMinigame extends PhysicsMinigame
func _on_sudden_death_player_died(player_id: int) -> void:
    player_data.current_lives -= 1  # Decrement for this mode
    EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
    
    if player_data.is_out_of_lives():
        respawn_manager.block_player_respawn(player_id)
        victory_condition_manager.eliminate_player(player_id)

# Infinite Lives - Never Eliminate
class_name InfiniteLivesMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    # Never connect to death events - unlimited respawns
    victory_condition_manager.victory_type = VictoryConditionManager.VictoryType.SCORE

# King of the Hill - Zone-Based Lives
class_name KingOfHillMinigame extends PhysicsMinigame
func _on_player_left_hill(player: BasePlayer) -> void:
    if outside_hill_too_long(player):
        player.player_data.current_lives -= 1  # Custom lives logic
        if player.player_data.is_out_of_lives():
            respawn_manager.block_player_respawn(player.player_data.player_id)

# Last Stand - Start with 1 Life
class_name LastStandMinigame extends PhysicsMinigame  
func _on_physics_initialize() -> void:
    for player_data in context.participating_players:
        player_data.current_lives = 1      # Override default
        player_data.max_lives = 1
        EventBus.emit_player_lives_changed(player_data.player_id, 1)
```

**Benefits of Minigame Control**:
- **Flexibility**: Each game mode has complete freedom
- **Clarity**: Lives logic is explicit and visible in each minigame
- **Testing**: Easy to test different rule sets independently
- **Modding**: Custom minigames can implement any lives system
- **UI Consistency**: UI updates work the same regardless of rules

### **6. Modern Godot 4.x Syntax Patterns**
```gdscript
# CORRECT: Super method calls (modern syntax)
func get_item_info() -> Dictionary:
    var info = super.get_item_info()  # Note: super.method() not super().method()
    info["custom_data"] = custom_value
    return info

# CORRECT: Static method calls (no conditional checks needed)
CollisionLayers.setup_pickup_area(pickup_area)
CollisionLayers.setup_ragdoll(ragdoll_body)

# CORRECT: Signal connection safety (prevent duplicates)
if not signal_name.is_connected(callback_method):
    signal_name.connect(callback_method)

# CORRECT: Object pooling state management
bullet_obj.is_pooled = true  # Mark as pooled for proper return
bullet_obj.reset_for_pool()  # Reset state but don't reconnect signals

# CORRECT: Holder reference preservation during reparenting
var temp_holder: BasePlayer = holder  # Preserve during _exit_tree()
# ... reparenting operations ...
holder = temp_holder  # Restore after reparenting
```

### **7. Factory Pattern Usage**
```gdscript
# Create players with configuration
var player: BasePlayer = PlayerFactory.create_player("standard", player_data)

# Create items with pooling integration (restored functionality)
var bullet: Bullet = ItemFactory.create_item("bullet") as Bullet

# Create minigames with context
var minigame: BaseMinigame = MinigameFactory.create_minigame("sudden_death", context)
```

### **8. Lazy Loading Architecture**
```gdscript
# LAZY POOLING: Create pools only when first requested
func get_item(item_id: String) -> Node:
    # Pool created automatically on first access
    var scene_path: String = _ensure_item_pool_configured(item_id)
    return object_pool.get_object(scene_path)

# LAZY CONFIG LOADING: Load configs only when accessed
func get_player_config(config_id: String) -> PlayerConfig:
    # Config loaded and cached on first request
    if not player_configs.has(config_id):
        player_configs[config_id] = _load_player_config(config_id)
    return player_configs[config_id]

# LAZY SESSION INITIALIZATION: Create players only when game mode selected
func start_local() -> void:
    # Initialize session only now, not in _ready()
    _initialize_session()

# LAZY MINIGAME INITIALIZATION: Initialize only when explicitly started
func initialize_minigame(context: MinigameContext) -> void:
    # Systems initialize here, not in _ready()
    _setup_managers()
    _configure_ui()

# WRONG: Eager initialization in _ready()
func _ready() -> void:
    _load_all_configs()  # Loads everything upfront
    _prewarm_all_pools()  # Creates objects before needed
    _initialize_session()  # Creates players before game mode selected
```

### **9. Configuration System** (Lazy Loading Architecture)
```gdscript
# LAZY LOADING: Configurations loaded only when requested (minimal startup overhead)
var config: PlayerConfig = ConfigManager.get_player_config("standard")  # Loads on first access
var item_config: ItemConfig = ConfigManager.get_item_config("pistol")    # Loads on first access

# ConfigManager no longer pre-loads all configs in _ready() - uses lazy initialization
# func _ready(): # No eager loading!
#     # _load_all_configs()  # REMOVED: Eager loading deprecated

# Manual reload (no automatic hot-reloading implemented)
ConfigManager.reload_config("player", "standard")  # Reload specific config
ConfigManager.reload_config("item")                 # Reload all item configs

# Runtime game values (health managed per minigame, not globally)
var game_config: GameConfig = GameConfig.get_instance()
var move_speed: float = game_config.default_move_speed

# Config classes use preload pattern in ConfigManager for discovery:
# const PlayerConfig = preload("res://configs/player_configs/player_config.gd")
# const ItemConfig = preload("res://configs/item_configs/item_config.gd")
# const MinigameConfig = preload("res://configs/minigame_configs/minigame_config.gd")

# Config .tres files use proper ExtResource syntax (not preload):
# [gd_resource type="Resource" format=3 load_steps=2]
# [ext_resource type="Script" path="res://configs/player_configs/player_config.gd" id="1_script"]
# [ext_resource type="PackedScene" path="res://scenes/player/base_player.tscn" id="2_scene"]
# [resource]
# script = ExtResource("1_script")
# player_scene = ExtResource("2_scene")
```

## Current Implementation Status

### **Implemented Systems**
1. **SuddenDeathMinigame** - Elimination-based gameplay with UI management
2. **Player Components** - Movement, health, inventory, input, ragdoll
3. **Weapon System** - Pistol (ranged), Bat (melee), Bullet (projectile) - Operational
4. **UI Framework** - Menu, map view (placeholder), HUD system with automatic cleanup
5. **Performance Optimization** - Object pooling for frequently spawned items
6. **Data Persistence** - Save/load with versioning and validation

### **Partial/Placeholder**
1. **Map System** - UI exists, generation logic planned
2. **AI System** - Architecture ready, no implementation
3. **Steamworks Networking** - Lobby creation/joining implemented, player data sync pending

### **Not Implemented**
1. **Additional Minigames** - Framework supports, only sudden death exists
2. **Assets** - Using placeholder graphics/audio
3. **Map Generation** - Random node-based progression planned

## Development Workflows

### **Testing Changes with Temporary Scenes**
1. Create temporary test scene: `scenes/temp_ui_test.tscn`
2. Create simple test script: `scripts/temp_ui_test.gd`
```gdscript
extends Control
func _ready() -> void:
    # Test your specific changes
    var config = UIFactory.UIElementConfig.new()
    config.text = "Test"
    var element = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, config)
    print("UIFactory test: ", element != null and element is Label)
    get_tree().quit()  # Auto-exit
```
3. Run test: `/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_ui_test.tscn --headless`
4. Clean up: `rm scenes/temp_ui_test.tscn scripts/temp_ui_test.gd`

### **Critical: Test Actual User Interaction Paths**
**WRONG - Synthetic Testing (bypasses user flow):**
```gdscript
# This doesn't test the real user experience!
var retry_handler = steam_lobby.RetryHandler.new(steam_lobby)
if SteamManager: print("SteamManager accessible")  # Doesn't test actual lobby creation!
```

**CORRECT - Integration Testing (follows user flow):**
```gdscript
# Test the EXACT path users take
func _ready() -> void:
    var steam_lobby_scene = UIFactory.get_screen_scene("direct_connect")  # Now Steam lobby UI
    var steam_lobby = steam_lobby_scene.instantiate()
    add_child(steam_lobby)
    await get_tree().process_frame
    
    # Actually simulate user clicking Host Game button
    steam_lobby._on_host_button_pressed()  # Real user path!
    # This triggers: _start_hosting() → retry_handler.attempt_operation("host") → SteamManager.create_lobby()
    # Which would reveal any Steam initialization or lobby creation errors
```

**Key Principle:** Test the **same code path** users trigger, not simplified versions.
- Button clicks should be simulated: `button.pressed.emit()` or `_on_button_pressed()`
- Follow method chains: User action → handler → system calls
- Integration testing over unit testing for UI functionality
- Don't bypass user interaction flow with manual object creation
- Don't test components in isolation if users experience them integrated

**Real Example - Steam Lobby Host Game:**
```
User Experience Path:
Click "Host Game" → _on_host_button_pressed() → _start_hosting() → 
retry_handler.attempt_operation("host") → SteamManager.create_lobby()

Test Should Follow Same Path:
steam_lobby._on_host_button_pressed()  # Not manual RetryHandler creation!
```

### **Adding a New Minigame**
1. Decide specialization level (Physics/UI/TurnBased)
2. Create scene and script extending appropriate base class
3. Register in MinigameRegistry (automatic discovery available)
4. Create configuration in `configs/minigame_configs/`
5. Test with MinigameFactory
6. **UI cleanup is automatic** - no need to manually hide HUD

### **Adding Player Components**
1. Extend BaseComponent
2. Implement lifecycle methods (_component_ready, _component_process, etc.)
3. Add to BasePlayer scene and connect signals
4. Update component initialization in BasePlayer

### **Adding Items/Weapons**
1. Extend BaseItem or create specialized class
2. Implement reset(), activate(), deactivate() for pooling
3. Create scene with proper collision layers
4. Add to PoolManager configuration
5. Create ItemConfig resource
6. **Ensure proper signal management** to prevent connection conflicts

### **Extending UI**
1. **Create through UIFactory** - Use `UIFactory.create_ui_element()` for generic elements
2. **Specialized factories** - Use `UIFactory.create_player_panel()`, `UIFactory.create_notification()`, etc.
3. **Screen creation** - Use `UIFactory.get_screen_scene()` + `UIManager.push_screen()` for navigation
4. **Overlay management** - Use `UIFactory.create_*()` + `UIManager.show_overlay()` for modals
5. **Configuration-driven** - Create `.tres` files in `configs/ui_configs/` for styling
6. **Automatic HUD cleanup** - BaseMinigame handles `UIManager.hide_game_hud()` automatically
7. **No manual UI creation** - All `Label.new()`, `Button.new()` calls should use UIFactory

## Critical Guidelines

### **DO NOT**
- Make BasePlayer monolithic again - it's a component coordinator
- Make BaseMinigame handle everything - use specialization levels
- Bypass the factory patterns for object creation
- Ignore object pooling for frequently spawned items
- Create direct dependencies between major systems
- Skip configuration files - use ConfigManager
- Load resources eagerly in _ready() - use lazy loading patterns
- Pre-warm object pools - create pools only when needed
- Initialize systems before they're selected/used
- **Create UI elements manually** - Use UIFactory for all UI creation
- **Bypass UIManager for global UI** - Screen navigation and overlays must use UIManager
- **Mix UI creation approaches** - UIFactory + UIManager is the only pattern
- **Leave temporary test files** - Always clean up test scenes/scripts after validation
- **Bypass user interaction flows in tests** - Test the exact path users take, not simplified versions
- **Implement cleanup timing manually in individual minigames** - BaseMinigame.abort_minigame() handles this automatically
- Use `super().method()` syntax - use `super.method()` in Godot 4.x
- Create inner classes that are referenced before definition
- Add conditional checks for static methods with `has_method()`
- Use `Time.get_time_dict_from_system()["unix"]` - key doesn't exist
- Call static methods on instances - use class name directly
- Mix StringName and String types in ternary operators without conversion
- Use parameter names that shadow built-in properties (position, name, etc.)
- Reuse variable names in overlapping scopes - use descriptive names
- Use await on non-coroutine functions
- Name constants that conflict with global class names
- Connect signals without checking if already connected (object pooling)
- Clear holder references during reparenting operations
- Add default health values to GameConfig - health is per-minigame
- Manually add UI cleanup to specialized minigame classes

### **DO**
- Use strict typing throughout (`var name: String`)
- Follow component-based architecture patterns
- Emit signals through EventBus for global events
- Use Logger instead of print() statements
- Create configuration resources for new systems
- Test with existing factory and manager systems
- Use lazy loading - load resources only when needed
- Initialize systems only when game modes are selected
- Create pools on-demand, not in _ready() methods
- Use `super.method_name()` for parent method calls
- Use Dictionary structures for complex data instead of inner classes
- Call static methods directly without conditional checks
- Use `Time.get_unix_time_from_system()` for Unix timestamps
- Implement `_exit_tree()` for cleanup, signal disconnection, resource freeing
- Use descriptive parameter names that don't conflict with built-ins
- Convert types explicitly in ternary operators: `str(node.name) if node else "Default"`
- Call static methods directly on classes: `DirAccess.make_dir_recursive_absolute()`
- Use descriptive variable names in complex scopes to avoid confusion
- Only await coroutines and signals, not immediate functions
- Add suffixes to constants that might conflict: `PlayerConfigClass` not `PlayerConfig`
- Check signal connections before connecting: `if not signal.is_connected(method):`
- Preserve holder references during item attachment with temp variables
- Use ItemConfig, PlayerConfig, MinigameConfig classes for configurations
- Rely on BaseMinigame for automatic UI cleanup
- Create temporary test scenes for validating changes, then delete them after testing
- Test actual user interaction paths - Simulate button clicks and follow the same method chains users trigger
- Use await when calling abort_minigame() - BaseMinigame handles cleanup timing automatically

## Performance Considerations

### **Lazy Loading Architecture**
- **Minimal startup overhead**: No resources loaded during _ready()
- **PoolManager**: Pools created only when first item requested
- **ConfigManager**: Configs loaded only when accessed
- **MinigameManager**: Systems initialize only when starting games
- **GameManager**: Players created only when game mode selected
- **Memory efficient**: Resources freed when not needed

### **Object Pooling** (Lazy Initialization)
- **PoolManager** handles bullets, items automatically with lazy pool creation
- Call `PoolManager.get_item("bullet")` instead of instantiating
- Implement reset() method for pooled objects
- **Mark objects as pooled**: `bullet.is_pooled = true`
- **Pools created on-demand**: No pre-warming, minimal startup cost

### **Signal Management**
- **Check before connecting**: Prevent duplicate signal connections
- **Disconnect in _exit_tree()**: Proper cleanup for pooled objects
- **EventBus** provides automatic connection cleanup

### **Collision Optimization**
- Use **CollisionLayers** enum for consistent setup
- Avoid excessive collision checks in _physics_process

## Extension Points

### **Most Common Additions**
1. **New Minigames** - Use the 3-level system control approach (UI cleanup automatic)
2. **Player Abilities** - Add new components to player system
3. **Items/Weapons** - Extend BaseItem with factory integration and proper pooling
4. **UI Screens** - Use UIFactory and ScreenManager
5. **Map Nodes** - Implement BaseMapNode when map system is built

### **Advanced Extensions**
1. **AI Behaviors** - Extend BasePlayer with AI components
2. **Networking** - Signal-based architecture is ready
3. **Modding Support** - Factory patterns support runtime loading
4. **Performance Monitoring** - PerformanceDashboard extensible

## System Integration Map

```
EventBus (Global Signal Hub)
    ↕
GameManager (State Machine) ←→ UIManager (UI Coordinator w/ HUD Lifecycle)
    ↕                              ↕
MinigameRegistry                HUDController & ScreenManager  
    ↕                              ↕
BaseMinigame Variants ←→ Player Components ←→ UIEventRouter
    ↕                              ↕
Standard Managers ←→ Weapon System ←→ Object Pooling
```

## Quick Reference

### **Common Signal Patterns**
```gdscript
# Global events through EventBus
EventBus.player_died.emit(player_id)
EventBus.minigame_started.emit("sudden_death")

# Component-level signals
health.died.connect(_on_health_died)
inventory.item_used.connect(_on_item_used)

# Safe signal connections (pooled objects)
if not body_shape_entered.is_connected(_on_body_shape_entered):
    body_shape_entered.connect(_on_body_shape_entered)
```

### **Weapon System Patterns**
```gdscript
# Proper bullet creation and pooling
var bullet: Node = PoolManager.get_bullet()
var bullet_obj: Bullet = bullet as Bullet
bullet_obj.is_pooled = true
bullet_obj.initialize(direction, position, shooter)

# Item attachment with holder preservation
var temp_holder: BasePlayer = holder
# ... reparenting operations ...
holder = temp_holder
is_held = true
```

### **Logging Best Practices**
```gdscript
Logger.system("System initialized", "ComponentName")
Logger.game_flow("Player spawned", "MinigameName") 
Logger.warning("Configuration missing", "SystemName")
Logger.error("Critical failure", "SystemName")
```

### **Configuration Access** (Lazy Loading)
```gdscript
# Runtime values (no default health in GameConfig)
var config: GameConfig = GameConfig.get_instance()
var speed: float = config.default_move_speed

# LAZY LOADING: Resource configurations loaded only on first access
var player_config: PlayerConfig = ConfigManager.get_player_config("standard")    # Loads if not cached
var item_config: ItemConfig = ConfigManager.get_item_config("pistol")            # Loads if not cached
var minigame_config: MinigameConfig = ConfigManager.get_minigame_config("sudden_death")  # Loads if not cached

# All configs load successfully with proper scene references
if player_config and player_config.player_scene:
    var player: BasePlayer = player_config.player_scene.instantiate()

# ConfigManager._ready() no longer pre-loads configs - minimal startup overhead
# Configs cached after first access for performance
```

### **Universal Damage System Patterns**
```gdscript
# Reporting damage from ANY source (weapons, hazards, mechanics)
EventBus.report_player_damage(victim_id, attacker_id, damage_amount, "Bullet")
EventBus.report_player_damage(victim_id, -1, damage_amount, "Lava")  # Environmental
EventBus.report_player_damage(victim_id, other_player_id, 1, "Jump")  # Player action

# Implementing damage handling in minigames (override virtual method)
func _on_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String, victim_data: PlayerData) -> void:
    # Physics games: Apply to health
    var player = player_spawner.get_player(victim_id)
    player.take_damage(damage)
    
    # Collection games: Drop items/points
    var collection_player = get_collection_player(victim_id) 
    collection_player.lose_collected_items(damage)
    
    # Vehicle games: Reduce performance
    var vehicle = get_player_vehicle(victim_id)
    vehicle.apply_damage_slowdown(damage)
    
    # Turn-based games: Queue for later
    damage_queue.append({"victim": victim_id, "damage": damage})

# BaseMinigame automatically handles: Signal connection, player lookup, cleanup
# Each minigame type only implements: Damage effect specific to their game
```

### **Minigame-Controlled Lives System Patterns**
```gdscript
# Sudden Death - 3 Lives Elimination (current implementation)
class_name SuddenDeathMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    EventBus.player_died.connect(_on_sudden_death_player_died)

func _on_sudden_death_player_died(player_id: int) -> void:
    var player_data: PlayerData = GameManager.get_player_data(player_id)
    player_data.current_lives -= 1  # Decrement for this mode only
    EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
    
    if player_data.is_out_of_lives():
        respawn_manager.block_player_respawn(player_id)       # Stop respawning
        victory_condition_manager.eliminate_player(player_id) # Remove from game

# Infinite Lives - Unlimited Respawns
class_name InfiniteLivesMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    # Don't connect to death events - never decrement lives
    victory_condition_manager.victory_type = VictoryConditionManager.VictoryType.SCORE
    victory_condition_manager.target_score = 10  # Win by score instead

# King of the Hill - Zone-Based Lives Loss
class_name KingOfHillMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    hill_zone.body_exited.connect(_on_player_left_hill)
    # Death doesn't cost lives - only leaving the hill does

func _on_player_left_hill(player: BasePlayer) -> void:
    start_hill_timer(player)  # Custom mechanic

func _on_hill_timer_expired(player: BasePlayer) -> void:
    player.player_data.current_lives -= 1  # Custom lives decrement
    EventBus.emit_player_lives_changed(player.player_data.player_id, player.player_data.current_lives)

# Last Stand - Start with 1 Life Only
class_name LastStandMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    # Override default lives at start
    for player_data in context.participating_players:
        player_data.current_lives = 1
        player_data.max_lives = 1
        EventBus.emit_player_lives_changed(player_data.player_id, 1)
    
    # Connect for immediate elimination on death
    EventBus.player_died.connect(_on_last_stand_death)

func _on_last_stand_death(player_id: int) -> void:
    # Immediate elimination - no respawns
    respawn_manager.block_player_respawn(player_id)
    victory_condition_manager.eliminate_player(player_id)

# Minigame Control Methods - Available to all minigames
respawn_manager.block_player_respawn(player_id)     # Prevent respawning
respawn_manager.unblock_player_respawn(player_id)   # Allow respawning again
victory_condition_manager.eliminate_player(player_id) # Remove from victory tracking
EventBus.emit_player_lives_changed(player_id, new_lives) # Update UI display
```

## Recent Architectural Changes

### **Steamworks-Only Networking Implementation - Complete Replacement**
**Problem**: Codebase had dual networking systems (IP-based ENet + Steamworks), creating complexity and confusion
```
NetworkManager + ENetMultiplayerPeer  # IP-based direct connections
SteamManager + GodotSteam GDExtension  # Steamworks P2P networking
Direct Connect UI using IP addresses   # Mixed messaging to users
```

**Solution**: Complete removal of non-Steamworks networking for unified architecture
- **NetworkManager Removal**: Deleted NetworkManager autoload and all IP-based networking code
- **Network Configuration Cleanup**: Removed network config system for IP connections
- **UI Conversion**: Direct Connect UI now creates/joins Steam lobbies instead of IP connections
- **ConfigManager Update**: Removed all network configuration management functions
- **GameManager Cleanup**: Removed NetworkManager references, added TODO for Steam player data sync

**Result**: **Pure Steamworks networking** - lobby creation/joining works, unified user experience, simpler architecture

### **Minigame-Controlled Lives & Victory System - Flexible Implementation**
**Problem**: Lives and victory conditions were globally automatic, preventing different game modes
```
GameManager._on_player_died(): player_data.current_lives -= 1  # Too rigid!
VictoryConditionManager: Auto-eliminated players with 0 lives  # No flexibility!
```

**Solution**: Minigame-controlled system with flexible implementation
- **Lives Management**: Each minigame decides if/when/how to decrement lives
- **Respawn Control**: `block_player_respawn()` / `unblock_player_respawn()` methods
- **Victory Control**: Manual `eliminate_player()` calls when minigame decides
- **UI Updates**: Minigames emit `player_lives_changed` when appropriate

**Result**: **Flexibility for game modes** - infinite lives, elimination, zone-based, custom mechanics all supported

### **Weapon System Restoration - Operational Status**
**Problem**: Weapon system was broken - bullets not pooling, items disappearing, signal conflicts
```
ERROR: Signal 'body_shape_entered' is already connected
WARNING: Bat _update_held_position called but not properly held (holder=<null>)
ERROR: Node not found: "InputController" (should be "InputComponent")
```

**Solution**: Weapon system restoration with architectural fixes
- **Bullet Pooling**: Fixed state management - bullets properly marked as `is_pooled = true`
- **Signal Management**: Added connection checks to prevent duplicate signal connections
- **Holder Preservation**: Fixed item attachment with temp variable pattern during reparenting
- **Component Names**: Fixed InputController → InputComponent mismatch in player spawner
- **Config Cleanup**: Removed invalid WeaponConfig/ProjectileConfig, use ItemConfig throughout
- **Collision Reset**: Enhanced pool reset to properly restore collision detection

**Result**: **Operational weapon system** - pistols fire bullets, bats swing correctly, items attach properly

### **UI Management Architecture - Automatic Cleanup**
**Problem**: Game HUD stayed active after minigames ended, creating UI state confusion
**Solution**: Moved UI cleanup to BaseMinigame for automatic inheritance
```gdscript
# BaseMinigame.end_minigame() - automatic for all minigame types
func end_minigame(result) -> void:
    # ... game logic ...
    UIManager.hide_game_hud()  # Automatic UI cleanup
    _on_end(result)  # Virtual method for subclasses
```

**Result**: **Clean UI lifecycle** - HUD appears during gameplay, disappears automatically when minigames end

### **BaseMinigame Architecture Improvement - Automatic Cleanup Timing**
**Problem**: Each minigame had to implement await logic manually for proper HUD/system cleanup timing
**Solution**: Moved cleanup timing into BaseMinigame.abort_minigame() for automatic inheritance
```gdscript
# BaseMinigame.abort_minigame() - all children inherit automatically
func abort_minigame() -> void:
    # ... cleanup logic ...
    end_minigame(abort_result)
    
    # Wait for cleanup to complete before allowing scene transitions
    await get_tree().process_frame
    await get_tree().process_frame
    
    _on_abort()  # Virtual method for subclasses

# All minigames now inherit proper cleanup timing
await some_minigame.abort_minigame()  # Cleanup timing handled automatically
```

**Result**: **Fail-safe architecture** - All minigame types get proper cleanup timing automatically, impossible to forget

### **Configuration System Health**
**Status**: Removed inappropriate `default_max_health` from GameConfig
- Health should be managed per-minigame or player config, not globally
- HealthComponent now uses export values directly
- Proper separation of concerns maintained

### **Issues Resolved**
- **Weapon system operational** - shooting, pooling, attachment working
- **UI lifecycle management** - automatic HUD cleanup in base minigame class
- **Signal management** - duplicate connection prevention throughout
- **Object pooling** - proper state management and collision reset
- **Player spawning** - fixed component name resolution
- **Memory management** - proper resource cleanup on shutdown
- **Code quality** - clean static analysis results

## For AI Agents: Development Guidelines

### **1. Critical Thinking Pattern for Architecture**

**When designing any system, ask these questions:**

1. **"Where does this functionality belong?"** - Start with the obvious answer
2. **"What other systems might need this?"** - Challenge your assumptions  
3. **"What's the most general case?"** - Find the right abstraction level
4. **"How would different types implement this differently?"** - Design for specialization

**Example: Universal Damage System**
```
Question 1: "Where does weapon damage belong?"
Initial Answer: "SuddenDeathMinigame" (specific to combat)

Question 2: "What other games might have damage?"  
Better Answer: "PhysicsMinigame" (any physics-based game)

Question 3: "What's the most general case?"
Best Answer: "BaseMinigame" (ANY game type could have damage)

Question 4: "How would they differ?"
Implementation: Virtual method with specialized overrides
- Physics: Direct health damage
- Collection: Lose collected items  
- Vehicle: Reduce speed/performance
- Turn-based: Queue damage for turns
```

**Apply this pattern to ALL system design decisions!**

### **2. Minigame-Controlled Lives & Victory System**

**Core Principle**: Minigames have complete control over their lives and victory rules.

**Global Systems Provide Tools, NOT Automatic Behavior**:
```gdscript
# DON'T: Assume automatic lives management
# GameManager will NOT automatically decrement lives
# VictoryConditionManager will NOT automatically eliminate players
# RespawnManager will NOT automatically check lives

# DO: Explicitly control your minigame's rules
class_name MyMinigame extends PhysicsMinigame

func _on_physics_initialize() -> void:
    # Connect to events YOU want to handle
    EventBus.player_died.connect(_on_my_minigame_player_died)

func _on_my_minigame_player_died(player_id: int) -> void:
    # YOUR minigame decides what happens on death
    var player_data: PlayerData = GameManager.get_player_data(player_id)
    
    # Option 1: Traditional lives system
    player_data.current_lives -= 1
    EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
    if player_data.is_out_of_lives():
        respawn_manager.block_player_respawn(player_id)
        victory_condition_manager.eliminate_player(player_id)
    
    # Option 2: Infinite lives - do nothing special
    # Option 3: Custom mechanics - your choice!
```

**Available Control Methods**:
```gdscript
# Respawn Control
respawn_manager.block_player_respawn(player_id)     # Stop respawning
respawn_manager.unblock_player_respawn(player_id)   # Allow respawning

# Victory Control  
victory_condition_manager.eliminate_player(player_id) # Manual elimination
victory_condition_manager.victory_type = VictoryConditionManager.VictoryType.SCORE

# UI Updates
EventBus.emit_player_lives_changed(player_id, new_lives) # Update lives display

# Lives Modification
player_data.current_lives = new_value  # Set directly
player_data.max_lives = new_max        # Change maximum
```

**Common Patterns**:
- **Elimination Mode**: Connect to death events, decrement lives, eliminate when 0
- **Infinite Lives**: Don't connect to death events, use score/time victory
- **Custom Lives**: Connect to custom events (zone exit, objectives, etc.)
- **Mixed Rules**: Different players can have different rules in same game

### **3. Weapon System Development**
```gdscript
# Proper bullet pooling with state management
func _shoot() -> bool:
    var bullet: Node = PoolManager.get_bullet()
    var bullet_obj: Bullet = bullet as Bullet
    bullet_obj.is_pooled = true  # CRITICAL: Mark as pooled
    
    # Proper scene attachment and initialization
    get_tree().current_scene.add_child(bullet_obj)
    bullet_obj.initialize(direction, global_position, holder)

# Safe signal connection (prevent duplicates in pooled objects)
func _ready() -> void:
    if not body_shape_entered.is_connected(_on_body_shape_entered):
        body_shape_entered.connect(_on_body_shape_entered)

# Holder preservation during reparenting
func _attach_to_player(player: BasePlayer) -> void:
    var temp_holder: BasePlayer = holder  # Preserve reference
    var temp_is_held: bool = is_held
    
    # Reparenting operations...
    get_parent().remove_child(self)
    player.add_child(self)
    
    # Restore state after reparenting
    holder = temp_holder
    is_held = temp_is_held
```

### **4. UI Architecture Best Practices**
```gdscript
# ALWAYS use UIFactory + UIManager pattern - no exceptions
func _on_multiplayer_button_pressed() -> void:
    # Step 1: UIFactory creates the screen  
    var screen_scene: PackedScene = UIFactory.get_screen_scene("direct_connect")  # Steam lobby UI
    # Step 2: UIManager handles navigation
    var screen: Control = await UIManager.push_screen(screen_scene, "direct_connect")

# Tutorial UI creation - all labels through UIFactory
func _setup_rules_section(rules: Array[String]) -> void:
    for i in range(rules.size()):
        var rule_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
        rule_config.element_name = "Rule" + str(i)
        rule_config.text = "• " + rules[i]
        
        var rule_label: Node = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, rule_config)
        if rule_label and rule_label is Label:
            container.add_child(rule_label as Label)

# Notification creation - UIFactory + UIManager integration
func show_notification(message: String) -> void:
    var notification: Control = UIFactory.create_notification(message, UIFactory.NotificationType.INFO)
    UIManager.show_overlay(notification, "notification_" + str(Time.get_unix_time_from_system()))

# HUD management - automatic in minigames
class_name MyMinigame extends PhysicsMinigame
func _on_physics_initialize() -> void:
    UIManager.show_game_hud(player_data_array)  # Show HUD
    # UIManager.hide_game_hud() called automatically by BaseMinigame.end_minigame()
```

### **5. Object Pooling Best Practices**
```gdscript
# Pool object state management
func activate_from_pool() -> void:
    is_pooled = true  # Mark as active pooled object
    
    # Check signals before connecting
    if not body_shape_entered.is_connected(_on_body_shape_entered):
        body_shape_entered.connect(_on_body_shape_entered)

func reset_for_pool() -> void:
    # Reset state but let activation handle signal reconnection
    shooter = null
    velocity_vector = Vector2.ZERO
    
    # Disconnect signals to prevent conflicts
    if body_shape_entered.is_connected(_on_body_shape_entered):
        body_shape_entered.disconnect(_on_body_shape_entered)
    
    # DON'T reconnect here - let activate_from_pool() handle it
```

### **6. Component System Patterns** 
```gdscript
# Use correct component names (InputComponent not InputController)
var input_component: InputComponent = player.get_component(InputComponent)
if input_component and input_component.has_method("setup_for_player"):
    input_component.setup_for_player(player_id)

# Health management per-minigame (not global defaults)
func _initialize_component() -> void:
    current_health = max_health  # Use export value, not game_config default
```

### **7. Modern Syntax Reminders**
```gdscript
# Super calls - correct Godot 4.x syntax
func custom_method() -> Dictionary:
    var base_data = super.get_data()  # Not super().get_data()
    return base_data

# Time API - correct usage
var timestamp = Time.get_unix_time_from_system()  # Not ["unix"]

# Signal safety in pooled objects
if not signal_name.is_connected(callback_method):
    signal_name.connect(callback_method)
```

## Quick Start

1. **Understand the current state**: Critical bugs have been fixed with architectural solutions including operational weapon system
2. **Follow component architecture**: Don't make systems monolithic  
3. **Use proper inheritance**: Minigames use clean class_name hierarchy with automatic UI cleanup
4. **Apply critical thinking pattern**: Question assumptions, find the right abstraction level for new systems
5. **Use universal damage system**: All minigame types can handle damage with specialized implementations
6. **Control lives and victory**: Minigames have complete control over their own rules (lives, respawn, elimination)
7. **Follow lazy loading principles**: Load resources only when needed, minimal startup overhead
8. **Use modern syntax**: `super.method()`, Dictionary structures, direct static calls
9. **Use existing patterns**: Factory, configuration, pooling systems in place
10. **Check autoloads**: 9 global systems handle cross-cutting concerns
11. **Implement proper cleanup**: Always add `_exit_tree()` methods for resource management
12. **Prevent warnings**: Use type-safe ternary operators, descriptive variable names, proper static calls
13. **Test your changes**: Create temporary test scenes to validate specific changes, follow actual user interaction paths, then delete them
14. **Test regularly**: Use system health commands to verify overall stability
15. **Know the weapon system**: Proper pooling, signal management, holder preservation patterns
16. **Know the UI lifecycle**: BaseMinigame automatically handles HUD cleanup
17. **Know the lazy loading**: Pools, configs, sessions initialize only when needed
18. **Know the damage system**: Universal base handling with minigame-specific implementations
19. **Know the lives system**: Minigame-controlled lives, respawn blocking, victory conditions
20. **Know the syntax patterns**: 
   - `super.method_name()` for parent calls
   - Dictionary for complex data structures
   - Direct static method calls: `ClassName.static_method()`
   - Signal connection safety: `if not signal.is_connected(method):`
   - Object pooling state: `object.is_pooled = true`
   - Holder preservation: `temp_holder = holder` during reparenting
   - Universal damage: `EventBus.report_player_damage()` from sources, `_on_damage_reported()` in minigames
   - UI creation: `UIFactory.create_*()` → `UIManager.show_*()` for all UI elements
   - `Time.get_unix_time_from_system()` for timestamps
   - `_exit_tree()` for cleanup, signal disconnection, resource freeing
   - Type conversion in ternary: `str(node.name) if node else "Default"`
21. **Reference this document**: All critical information is here

**Remember**: This codebase has modern architecture with operational weapon system, universal damage handling across all minigame types, **complete UI consistency via Factory + Manager pattern**, and lazy loading architecture. The inheritance hierarchy is clean, type annotations are comprehensive, super() calls use correct syntax, weapon system is operational with proper pooling and signal management, **UI architecture enforces 100% consistency with no manual creation bypasses**, damage system is universal with specialized implementations, lazy loading provides minimal startup overhead, and the design maintains integrity. **Apply the critical thinking pattern** - question assumptions, find the right abstraction level, design for universal base functionality with specialized implementations. Focus on feature development using established patterns - the foundation is architecturally sound and ready for development with clean code quality and optimized performance through lazy loading.

### **Testing Commands**

#### **System Health Test (Headless)**
```bash
# Test for system health and initialization (macOS)
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3

# Look for these indicators:
# - No "E" (Error) messages
# - No "W" (Warning) messages  
# - No "RID allocations leaked" messages
# - All autoloads initialize successfully
# - Clean shutdown with "cleanup completed" messages
```

#### **Create Temporary Test Scene Pattern**
```bash
# 1. Create a temporary test scene to validate your changes
# Example: testing UIFactory changes
# File: scenes/temp_test.tscn (or any temporary name)

# 2. Create a simple script that tests your specific changes:
# extends Control
# func _ready():
#     # Test your specific changes here
#     var test_element = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, config)
#     print("Test passed: ", test_element != null)
#     get_tree().quit()  # Auto-exit after test

# 3. Run the test scene directly
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_test.tscn --headless

# 4. Clean up - delete the temporary test scene and script
rm scenes/temp_test.tscn scripts/temp_test.gd

# Benefits:
# - Self-contained testing of specific changes
# - No impact on main codebase
# - Quick validation before committing changes
# - Easy to create, test, and remove
```

#### **Direct Scene Testing Pattern**
```bash
# Run any existing scene directly for testing
/Applications/Godot.app/Contents/MacOS/Godot --path . path/to/your/scene.tscn
```