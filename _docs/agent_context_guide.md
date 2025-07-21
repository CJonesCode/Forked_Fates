# Forked Fates - AI Agent Context Guide

**Purpose**: Technical reference for LLMs working on this codebase. Provides concise information on where and how systems are implemented according to project standards. Not marketing copy - technical facts only.

## Project Overview

**Forked Fates** is a multiplayer party game combining:
- Ragdoll physics for chaotic combat
- Slay the Spire-style map progression for structured gameplay
- Mario Party-style minigames for varied experiences

**Current Status**: Godot 4.4, component-based architecture, circular dependency fix via ID-based architecture with PlayerManager singleton, .tres resource configs, object pooling, universal damage system, minigame-controlled lives/victory, UI Factory+Manager pattern, Steamworks networking via GDExtension, **complete Map System with voting**.

## Architecture Summary

### **Design Philosophy**
- Component-based architecture
- Signal-driven communication via EventBus
- Factory patterns for object creation
- Configuration-driven via .tres files
- ID-based architecture with manager lookups (eliminates circular dependencies)
- Lazy loading (resources loaded on-demand)
- Object pooling for performance
- Universal base functionality with specialized implementations

### **Core Systems Status**
- **Player System**: Component-based with 6 specialized components
- **Weapon System**: Configuration-driven with event-based positioning (pistols, bullets, melee weapons)
- **Universal Damage System**: All minigame types support damage with specialized handling
- **Minigame Framework**: Flexible with 3 specialization levels + automatic UI cleanup
- **Lives & Victory System**: Minigame-controlled for maximum flexibility (infinite lives, elimination, etc.)
- **Respawn Management**: Minigame-controllable blocking system for different game modes
- **UI Architecture**: Complete Factory + Manager pattern with 100% consistency across codebase
- **Data Persistence**: Versioned save/load with validation, extracted data structures
- **Map System**: Complete Slay the Spire implementation with generation, navigation, voting, persistence
- **Object Indicator System**: Universal visual indicators for players, items, NPCs (crowns, teams, buffs, etc.)
- **Performance Systems**: Object pooling and monitoring with optimized logging
- **Configuration**: Lazy-loaded configs with caching, extracted global config classes
- **Lazy Loading Architecture**: Complete implementation - minimal startup overhead, all resources on-demand
- **Memory Management**: Proper resource cleanup on shutdown
- **Code Quality**: Clean static analysis results

## Critical File Locations

### **Autoloads (Global Systems)**
```
autoloads/
├── event_bus.gd           # Global signal relay with connection management
├── game_manager.gd        # State machine-based game coordinator with map persistence
├── steam_manager.gd       # Steamworks integration and P2P networking
└── [5 additional autoloads listed in project.godot]

Additional Autoloads:
- UIManager: scripts/ui/core/ui_manager.gd
- PoolManager: scripts/core/pool_manager.gd  
- PerformanceDashboard: scripts/core/performance_dashboard.gd
- DataManager: scripts/core/data_manager.gd
- ConfigManager: scripts/core/config_manager.gd
- PlayerManager: scripts/core/player_manager.gd  # ID-based player lookups
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
│   ├── party_progress_data.gd # NEW: Party-wide progress with voting system
│   └── player_statistics.gd # Player performance data
├── collision_layers.gd    # Centralized collision management with TRIGGERS/DESTRUCTIBLES
├── logger.gd              # Structured logging system
├── game_config.gd         # Runtime configuration values
├── save_system.gd         # Save/load operations (uses preload pattern)
├── data_manager.gd        # Central data coordination
└── [performance & monitoring systems]
```

### **Map System (NEW - Complete Implementation)**
```
scripts/map/
├── core/
│   ├── map_data.gd            # MapData resource class with validation
│   ├── map_node.gd            # MapNode resource class
│   ├── map_generator.gd       # Slay the Spire-style generation algorithm
│   └── map_generation_config.gd # Configuration for map generation
├── navigation/
│   ├── map_navigation.gd             # Core navigation logic with voting
│   └── map_navigation_controller.gd  # UI bridge controller
├── config/
│   ├── map_visual_config.gd          # Visual styling configuration
│   └── minigame_display_names.gd     # Node type display names
└── visualization/
    ├── map_renderer.gd        # Visual display with UIFactory integration
    └── line_drawer.gd         # Connection line rendering

scenes/ui/
├── map_view.tscn         # Map UI scene structure
└── map_view.gd          # Map coordinator with voting UI
```

### **Player Architecture**
```
scripts/player/
├── base_player.gd         # Component coordinator (NOT monolithic)
└── components/            # 7 specialized components
    ├── base_component.gd                # Abstract base with lifecycle
    ├── movement_component.gd            # Physics, jumping, facing
    ├── health_component.gd              # Health, damage, death
    ├── item_component.gd                # Universal held objects (weapons, consumables, tools)
    ├── input_component.gd               # Input processing
    ├── ragdoll_component.gd             # Ragdoll physics
    └── object_indicator_manager.gd      # NEW: Universal object indicators (crown, team, buffs, etc.)
```

### **Weapon System (Operational)**
```
scripts/items/
├── base_item.gd           # Core item behavior with proper holder management
├── pistol.gd              # Ranged weapon with bullet spawning
├── bullet.gd              # Projectile with collision detection and pooling
├── bat.gd                 # Melee weapon with swing mechanics
└── trigger_item.gd        # NEW: Environmental triggers (hazards, boosts, etc.)

Key Features:
- Object pooling for bullets and items
- Proper signal connection management
- Collision layer configuration with TRIGGERS layer
- Holder attachment system
- ItemFactory integration
```

### **Minigame Framework (Proper Inheritance + UI Management)**
```
scripts/minigames/core/
├── base_minigame.gd              # class_name BaseMinigame - Automatic UI cleanup
├── physics_minigame.gd           # class_name PhysicsMinigame - For physics-based games
├── ui_minigame.gd                # class_name UIMinigame - For UI-only games  
├── turn_based_minigame.gd        # class_name TurnBasedMinigame - For strategy games
├── minigame_context.gd           # class_name MinigameContext - System control interface
├── minigame_registry.gd          # class_name MinigameRegistry - Dynamic loading
├── minigame_result.gd            # class_name MinigameResult - Result data structure
├── map_state_interface.gd        # NEW: Bridge to persistent overworld state
└── standard_managers/            # Optional tools with proper class_name declarations
    ├── player_spawner.gd         # Player spawning and management
    ├── item_spawner.gd           # Item/weapon spawning
    ├── respawn_manager.gd        # Respawn timing and positioning
    └── victory_condition_manager.gd # Victory tracking and evaluation
```

## Key Architecture Patterns

### **1. Component System (Player)**
```gdscript
# BasePlayer is a COORDINATOR, not a monolith
class_name BasePlayer extends CharacterBody2D

@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var item: ItemComponent = $ItemComponent  # Universal held objects
@onready var input: InputComponent = $InputComponent
@onready var ragdoll: RagdollComponent = $RagdollComponent
@onready var object_indicators: ObjectIndicatorManager = $ObjectIndicatorManager

# Components communicate via signals
health.died.connect(_on_health_died)
```

### **2. ID-Based Architecture (Circular Dependency Fix)**

Use `var player_id: int` + `PlayerManager.get_player(id)` for cross-system references.

```gdscript
# BaseWeapon.gd
var holder_id: int = -1  # Not var holder: BasePlayer

func pickup_by_id(player_id: int) -> bool:
    var player: BasePlayer = PlayerManager.get_player(player_id)
    holder_id = player_id
    return true

# PlayerManager.gd (autoload)
var players: Dictionary = {}
func register_player(player_id: int, player: BasePlayer) -> void:
    players[player_id] = player
func get_player(player_id: int) -> BasePlayer:
    return players.get(player_id, null)

# BasePlayer.gd
func _ready() -> void:
    PlayerManager.register_player(player_data.player_id, self)
```

### **3. Map System (NEW - Complete Slay the Spire Implementation)**

**Map Generation**:
```gdscript
# MapGenerator.gd - generates 4-layer tree structure
class_name MapGenerator
static func generate(config: MapGenerationConfig = null) -> MapData:
    var generator: MapGenerator = MapGenerator.new()
    return generator._generate_with_config(config)

# Layer structure: Start -> 2-5 nodes -> 2-5 nodes -> 2-5 nodes -> Boss
# Total nodes: 10-14 per map with proper connectivity validation
```

**Map Navigation with Voting**:
```gdscript
# MapNavigation.gd - Slay the Spire rules + democratic voting
class_name MapNavigation extends RefCounted

func move_to_node(target_node: String) -> bool:
    # Rule 1: Cannot move to already visited nodes (no backtracking)
    # Rule 2: Can only move to directly connected nodes  
    # Rule 3: Target node must be available (unlocked)
    # Rule 4: Must complete current node before moving

func start_node_voting(deadline_seconds: int = 30) -> int:
    # Start democratic voting when multiple paths available
    var available_moves: Array[String] = get_available_moves()
    if available_moves.size() > 1:
        return party_progress.add_node_voting(available_moves, deadline_seconds)
    return -1

func resolve_node_voting(decision_index: int) -> bool:
    # Execute the democratically chosen move
    var chosen_node: String = _get_voting_winner(decision_index)
    return move_to_node(chosen_node)
```

**Map Persistence**:
```gdscript
# GameManager.gd - map state persistence across sessions
var persistent_map_data = null  # MapData object
var persistent_map_navigation_data: Dictionary = {}

func store_map_data(map_data: MapData, navigation_data: Dictionary) -> void:
    persistent_map_data = map_data
    persistent_map_navigation_data = navigation_data

func has_persistent_map() -> bool:
    return persistent_map_data != null
```

**Map UI Integration**:
```gdscript
# MapView.gd - coordinator using new map architecture  
func _initialize_map_system() -> void:
    map_generator = MapGenerator.new()
    map_renderer = MapRenderer.new()
    map_navigation = MapNavigation.new(party_progress)
    _initialize_or_load_map()  # Load existing or generate new

func _start_movement_voting(available_moves: Array[String]) -> void:
    # Create voting UI using UIFactory patterns
    _create_voting_ui(available_moves)
    _start_voting_monitor()
```

### **4. Voting System (NEW - Democratic Decision Making)**

**Party Progress Data with Voting**:
```gdscript
# PartyProgressData.gd - democratic voting for party decisions
class_name PartyProgressData extends Resource

func add_node_voting(available_node_ids: Array[int], deadline_seconds: int = 30) -> int:
    var options: Array[String] = []
    for node_id in available_node_ids:
        options.append("Node " + str(node_id))
    add_pending_decision("node_selection", options, deadline_seconds)
    return pending_decisions.size() - 1

func vote_for_node(decision_index: int, player_id: int, node_index: int) -> bool:
    return vote_on_decision(decision_index, player_id, node_index)

func get_voting_results(decision_index: int) -> Dictionary:
    # Count votes, find winners, handle ties
    var results = {
        "vote_counts": vote_counts,
        "winning_options": winning_options,
        "is_tie": winning_options.size() > 1
    }
    return results
```

**Voting UI Integration**:
```gdscript
# MapView.gd - voting UI using UIFactory patterns
func _create_voting_ui(available_moves: Array[String]) -> void:
    # Create voting panel using UIFactory
    var panel_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
    voting_ui_panel = UIFactory.create_ui_element(UIFactory.UIElementType.PANEL, panel_config)
    
    # Create voting buttons for each option
    for i in range(available_moves.size()):
        var button_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
        var vote_button: Button = UIFactory.create_ui_element(UIFactory.UIElementType.BUTTON, button_config)
        vote_button.pressed.connect(_on_vote_button_pressed.bind(node_id))
```

### **5. Object Indicator System (NEW - Universal Visual Indicators)**

**Generalized from StatusIndicator to ObjectIndicator**:
```gdscript
# ObjectIndicatorManager.gd - works with any object, not just players
class_name ObjectIndicatorManager extends BaseComponent

func add_object_indicator(indicator_id: String, icon: String, color: Color = Color.WHITE) -> void:
    var indicator_data: ObjectIndicatorData = ObjectIndicatorData.new()
    indicator_data.configure(indicator_id, icon, color, false)
    _create_and_add_indicator(indicator_data)

func add_leadership_indicator(icon: String = "👑", color: Color = Color.GOLD) -> void:
    # Crown system with proper centering and tie detection
    add_object_indicator("leadership", icon, color)

func add_team_indicator(team_color: Color) -> void:
    # Team markers for multiplayer coordination
    add_object_indicator("team", "●", team_color)

func add_collection_indicator(collection_id: String, items: Array[ObjectIndicatorData]) -> void:
    # Collection system with automatic priority-based sorting
    # Perfect for debuffs, status effects, ammo displays
```

**Crown Leadership with Proper Tie Detection**:
```gdscript
# SuddenDeathMinigame.gd - crown logic requires performance gaps
func _get_elimination_leader() -> Array[PlayerData]:
    # Two-pass algorithm to find all players at top performance
    # Primary metric: lives, Tiebreaker1: kills, Tiebreaker2: damage_dealt
    # Returns null when players tied - crown only shows with clear performance gap
```

### **6. Enhanced Collision Layers (NEW - Expanded Physics)**

**Additional Collision Layers**:
```gdscript
# CollisionLayers.gd - centralized collision management
enum Layer {
    NONE = 0,
    ENVIRONMENT = 1,    # Static world geometry  
    PLAYERS = 2,        # Player characters
    ITEMS = 4,          # Pickup items
    PROJECTILES = 8,    # Bullets, grenades
    TRIGGERS = 16,      # NEW: Area2D triggers for events, pickups, damage zones
    DESTRUCTIBLES = 32, # NEW: Breakable objects in the environment
}

# Setup methods for new layers
static func setup_trigger(trigger: Area2D) -> void:
    set_layer(trigger, Layer.TRIGGERS)
    set_mask(trigger, Mask.PLAYER_DETECTION)

static func setup_destructible(destructible: RigidBody2D) -> void:
    set_layer(destructible, Layer.DESTRUCTIBLES)
    set_mask(destructible, Mask.PROJECTILE_TARGETS)
```

**Trigger Item System**:
```gdscript
# TriggerItem.gd - environmental interactions
class_name TriggerItem extends BaseItem

@export var trigger_type: String = "speed_boost"  # "hazard", "checkpoint", "bounce_pad", "healing_zone"
@export var effect_strength: float = 1.0
@export var affected_teams: Array[String] = []  # Team restrictions

func _activate_trigger(player: BasePlayer) -> void:
    match trigger_type:
        "speed_boost": _apply_speed_boost(player)
        "hazard": _apply_hazard_damage(player) 
        "checkpoint": _activate_checkpoint(player)
        "bounce_pad": _apply_bounce_effect(player)
        "healing_zone": _apply_healing(player)
```

### **7. Weapon System (Configuration-Driven + Event-Based Architecture)**

**Configuration-Driven Weapon Properties**:
```gdscript
# BaseWeapon loads properties from ItemConfig .tres files
func _ready() -> void:
    super()
    _load_weapon_config()  # Load from .tres files, not hard-coded @export

func _apply_weapon_config(config: ItemConfig) -> void:
    # Properties loaded from configuration files
    base_damage = config.damage_amount
    fire_rate = config.fire_rate
    ammo_capacity = config.ammo_capacity
    throw_damage_multiplier = config.throw_damage_multiplier
    # Weapon-specific overrides in subclasses

# Pistol-specific configuration loading
func _apply_weapon_config(config: ItemConfig) -> void:
    super._apply_weapon_config(config)
    bullet_speed = config.bullet_speed
    bullets_per_shot = config.bullets_per_shot
    recoil_force = config.recoil_force
```

**Event-Driven Weapon Positioning**:
```gdscript
# BaseWeapon requests position via EventBus (no direct component access)
func _physics_process(delta: float) -> void:
    if is_held and holder:
        _request_position_update()

func _request_position_update() -> void:
    var weapon_id: String = item_name
    var holder_id: int = holder.player_data.player_id
    EventBus.weapon_position_requested.emit(weapon_id, holder_id)
    EventBus.weapon_facing_requested.emit(weapon_id, holder_id)

# WeaponComponent responds to position requests
func _on_weapon_position_requested(weapon_id: String, holder_id: int) -> void:
    if player.player_data.player_id == holder_id and held_weapon.item_name == weapon_id:
        var position: Vector2 = get_weapon_hold_position()
        EventBus.weapon_position_provided.emit(weapon_id, position, 0.0)
```

**Item Lifecycle with Proper Pooling**:
```gdscript
# Pistol shooting with pooled bullets
func _shoot() -> bool:
    var bullet: Node = PoolManager.get_item("bullet")
    var bullet_obj: Bullet = bullet as Bullet
    bullet_obj.is_pooled = true  # Critical for pool return
    
    # Proper scene attachment
    get_tree().current_scene.add_child(bullet_obj)
    bullet_obj.initialize(shoot_direction, global_position, holder_id)  # Use ID

# ItemFactory with proper config classes
static func create_item(item_id: String) -> BaseItem:
    var config: ItemConfig = load("res://configs/item_configs/" + item_id + ".tres")
    return config.item_scene.instantiate()
```

### **8. Unified Damage System**

All damage uses a single method with sensible defaults for any source type.

```gdscript
# UNIFIED: Single damage method for all sources (weapons, items, environmental)
func take_damage(damage: int, source: Node = null, attacker_id: int = -1, source_name: String = "Environmental") -> void:
    # Always preserves attribution with sensible defaults
    # attacker_id = -1: environmental damage
    # source_name = "Environmental": default for unknown sources

# Apply damage with attribution (bullets, bats, thrown objects)
target_player.health.take_damage(damage, self, attacker_id, "Bat")
target_player.health.take_damage(damage, self, shooter_id, "Bullet") 
target_player.health.take_damage(damage, self, thrower_id, "Thrown Crate")

# Environmental damage (lava, poison, traps)
player.health.take_damage(damage, self, -1, "Lava")
player.health.take_damage(damage, self, -1, "Poison")

# Minigame damage handling preserves attribution
func _on_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String, victim_data: PlayerData) -> void:
    var victim_player: BasePlayer = player_spawner.get_player(victim_id)
    victim_player.health.take_damage(damage, null, attacker_id, source_name)  # Preserves attribution
```

### **9. UI Architecture (Factory + Manager Pattern)**

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

### **10. Minigame Inheritance Hierarchy (Clean Architecture + UI Management)**

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

### **11. Universal Damage System**

All minigame types handle damage via BaseMinigame, specialized by subclass.

```gdscript
# BaseMinigame - Universal damage handling
func initialize_minigame(context: MinigameContext) -> void:
    EventBus.player_damage_reported.connect(_on_player_damage_reported)

# Virtual method - override in subclasses
func _on_damage_reported(victim_id, attacker_id, damage, source_name, victim_data) -> void:
    pass  # Subclasses implement

# PhysicsMinigame - Health damage
func _on_damage_reported(...) -> void:
    player_spawner.get_player(victim_id).take_damage(damage)

# Other minigame types implement differently
```

### **12. Minigame-Controlled Lives & Victory**

Minigames control their own lives/respawn rules. No automatic global decrementation.

```gdscript
# Tools available to minigames:
respawn_manager.block_player_respawn(player_id)
victory_condition_manager.eliminate_player(player_id)
EventBus.emit_player_lives_changed(player_id, new_lives)

# SuddenDeathMinigame - Traditional 3 lives
func _on_player_died(player_id: int) -> void:
    player_data.current_lives -= 1
    if player_data.is_out_of_lives():
        respawn_manager.block_player_respawn(player_id)

# Other minigames implement different rules
```

### **13. Modern Godot 4.x Syntax Patterns**
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

### **14. Factory Pattern Usage**
```gdscript
# Create players with configuration
var player: BasePlayer = PlayerFactory.create_player("standard", player_data)

# Create items with pooling integration (restored functionality)
var bullet: Bullet = ItemFactory.create_item("bullet") as Bullet

# Create minigames with context
var minigame: BaseMinigame = MinigameFactory.create_minigame("sudden_death", context)
```

### **15. Lazy Loading Architecture**
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

### **16. Configuration System** (Lazy Loading Architecture)
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
# [ext_resource type="Script" path="res://configs/item_configs/item_config.gd" id="item_config_script"]
# [ext_resource type="PackedScene" path="res://scenes/weapons/pistol.tscn" id="pistol_scene"]
# [resource]
# script = ExtResource("item_config_script")
# item_scene = ExtResource("pistol_scene")
```

### **17. ExtResource Best Practices** (Robust Resource References)
```gdscript
# WRONG: Brittle numeric IDs
[ext_resource type="Script" path="res://configs/item_configs/item_config.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/weapons/pistol.tscn" id="2_scene"]
[ext_resource type="Texture2D" path="res://assets/icons/pistol_icon.png" id="3_icon"]

[resource]
script = ExtResource("1_script")        # What's "1_script"? Hard to read
item_scene = ExtResource("2_scene")     # Adding resources requires renumbering
icon_texture = ExtResource("3_icon")    # Copy-paste errors common

# RIGHT: Descriptive IDs that are self-documenting and extensible
[ext_resource type="Script" path="res://configs/item_configs/item_config.gd" id="item_config_script"]
[ext_resource type="PackedScene" path="res://scenes/weapons/pistol.tscn" id="pistol_scene"]
[ext_resource type="Texture2D" path="res://assets/icons/pistol_icon.png" id="pistol_icon"]
[ext_resource type="AudioStream" path="res://assets/sounds/pistol_fire.ogg" id="pistol_sound"]

[resource]
script = ExtResource("item_config_script")  # Clear purpose
item_scene = ExtResource("pistol_scene")    # Self-documenting
icon_texture = ExtResource("pistol_icon")   # Easy to add new resources
fire_sound = ExtResource("pistol_sound")    # No renumbering cascade

# ExtResource Guidelines:
# - Use descriptive names: "player_scene" not "2_scene"
# - Follow naming patterns: "weapon_icon", "weapon_sound", "weapon_animation"
# - Be consistent across similar configs
# - Avoid special characters: letters_numbers_underscores only
# - IDs are arbitrary - they just need to be unique within each file
```

### **18. Universal Damage System Patterns**
```gdscript
# Reporting damage from ANY source (items, hazards, mechanics)
EventBus.report_player_damage(victim_id, attacker_id, damage_amount, "Bullet")
EventBus.report_player_damage(victim_id, -1, damage_amount, "Lava")  # Environmental
EventBus.report_player_damage(victim_id, other_player_id, 1, "Jump")  # Player action

# Implementing damage handling in minigames (override virtual method)
func _on_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String, victim_data: PlayerData) -> void:
    # Physics games: Apply to health with proper attribution
    var player = player_spawner.get_player(victim_id)
    player.health.take_damage(damage, null, attacker_id, source_name)  # Preserves kill tracking
    
    # Collection games: Drop items/points
    var collection_player = get_collection_player(victim_id) 
    collection_player.lose_collected_items(damage)
    
    # Vehicle games: Reduce performance
    var vehicle = get_player_vehicle(victim_id)
    vehicle.apply_damage_slowdown(damage)
    
    # Turn-based games: Queue for later
    damage_queue.append({"victim": victim_id, "damage": damage, "attacker": attacker_id, "source": source_name})

# BaseMinigame automatically handles: Signal connection, player lookup, cleanup
# Each minigame type only implements: Damage effect specific to their game
```

### **19. Minigame-Controlled Lives System Patterns**
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

### **Collection Indicator System - Predictable Sizing and Organization** 
**Problem**: ObjectIndicator system lacked organization for multiple indicators with predictable sizing requirements
**Solution**: Added collection-based indicator management with automatic width constraints
- **Collection API**: `add_collection_indicator()`, `remove_collection_indicator()`, `clear_collection()` with automatic priority-based sorting
- **Width Constraint System**: `set_width_constraints(max_width, enable_scaling, keep_aspect_ratio)` for predictable sizing
- **Automatic Scaling**: Real-time scaling to fit within constraints, maintains aspect ratio or horizontal-only compression
- **Priority-Based Sorting**: Items automatically sorted by priority within collections
- **Perfect Use Cases**: Status effects, ammo displays, team indicators, buff/debuff collections
- **Real-Time Updates**: Scaling recalculation on add/remove/sort operations

**Usage Example**:
```gdscript
# Set up ammo collection with width constraint (half pistol width)
weapon.object_indicators.set_width_constraints(weapon.size.x / 2, true, true)
weapon.object_indicators.add_collection_indicator("ammo", "bullet_1", bullet_data, 10.0)
weapon.object_indicators.add_collection_indicator("ammo", "bullet_2", bullet_data, 9.0)
# Automatically scales to fit within constraint, sorted by priority
```

**Result**: **Production-ready indicator collections** - perfect for any UI requiring predictable sizing and automatic organization

### **Enhanced Ragdoll Physics - Mario Party-Style Dramatic Chaos**
**Problem**: Ragdoll physics were too subtle and didn't create enough dramatic moments
**Solution**: Dramatically enhanced ragdoll forces across all systems for Mario Party-style chaos
- **Head Collision Ragdolls**: `enter_head_collision_ragdoll()` with Vector2(0, -200) base force + random chaos up to 150 horizontal and 100 vertical
- **Enhanced Force Multipliers**: Head collisions apply 2.4x more force than regular ragdolls (344 vs 144 magnitude)
- **Doubled Base Forces**: All ragdoll systems doubled - base tipping force to -120, movement-based forces to 60, impact forces to 100
- **Random Chaos Addition**: All ragdolls get random horizontal/vertical chaos for unpredictability
- **No Velocity Requirement**: Head collisions trigger ragdolls regardless of speed (Mario Party-style)
- **Impact Direction Calculation**: Uses player positions and velocity for realistic physics
- **Multiple Force Points**: Apply forces at different offsets for enhanced spinning

**Head Collision Trigger**:
```gdscript
# MovementComponent._check_immediate_head_collision() - no velocity requirement
func _check_immediate_head_collision(other_player: BasePlayer) -> void:
    # Head collisions always trigger ragdolls regardless of velocity for Mario Party-style chaos
    _trigger_head_collision(other_player)
```

**Result**: **Dramatically more exciting ragdoll physics** - creates Mario Party-style chaos moments while maintaining proper collision detection and sync

### **Enhanced Item Throwing Physics - Momentum-Based Weaponization**
**Problem**: Item throwing was binary and didn't reflect player momentum or create interesting physics interactions
**Solution**: Comprehensive momentum-based throwing system with enhanced physics and attribution
- **Momentum Calculation**: `_calculate_throw_force_from_momentum()` based on player velocity and input
- **Force-Based Weaponization**: >200.0 force = projectile mode with damage, <200.0 force = gentle drop
- **Enhanced Item Physics**: Reduced damping (linear_damp=0.2, angular_damp=0.5) and low-friction materials (friction=0.3, bounce=0.1)
- **Weaponized Throw Physics**: Extremely low damping (0.05 linear, 0.1 angular) and projectile materials (friction=0.1, bounce=0.3)
- **Attribution Preservation**: Store attacker info BEFORE damage operations to prevent holder clearing issues
- **Enhanced Collision**: Proper kill attribution for bat hits and weapon throws
- **Physics State Management**: Proper restoration for gentle drops and projectile→normal transitions

**Momentum Force Calculation**:
```gdscript
func _calculate_throw_force_from_momentum() -> float:
    var current_velocity = velocity.length()
    var movement_input = movement.input_vector if movement else Vector2.ZERO
    
    if current_velocity < 50.0 and movement_input.length() < 0.1:
        return 50.0  # Standing still = gentle drop
    else:
        # Moving = throw with momentum-based force (50-500 range)
        var momentum_factor = max(velocity_factor, input_factor * 0.8)
        return 50.0 + (momentum_factor * 450.0)
```

**Enhanced Physics Materials**:
```gdscript
# BaseItem physics - 5x less linear damping, 2x less angular damping, 3x less friction
# BaseWeapon projectile physics - 10x less damping for dramatic throwing
```

**Result**: **Dramatically improved throwing physics** - items slide naturally, weapons have projectile-quality throws, proper kill attribution maintained

### **Player Capsule Collision and Visuals - Better Physics Foundation**
**Problem**: Rectangular collision and visuals caused awkward movement and collision behavior
**Solution**: Complete conversion to capsule-based collision and visual system
- **Collision Update**: Changed from RectangleShape2D to CapsuleShape2D (radius=10.0, height=40.0)
- **Visual Structure**: Node2D containing CapsuleBody (20x20 rectangle), TopCap (14x7 narrower cap), BottomCap (14x7 narrower cap)
- **Improved Physics**: Smoother movement, natural collision behavior, better wall sliding
- **Visual-Collision Consistency**: Visual appearance matches collision shape
- **Color System Update**: PlayerSpawner updated to handle capsule component coloring
- **Component Compatibility**: All systems work with capsule structure (ragdoll, indicators, etc.)

**Scene Structure Update**:
```gdscript
# scenes/player/base_player.tscn
[node name="PlayerSprite" type="Node2D" parent="Sprite2D"]
[node name="CapsuleBody" type="ColorRect" parent="Sprite2D/PlayerSprite"]  # 20x20 main body
[node name="TopCap" type="ColorRect" parent="Sprite2D/PlayerSprite"]       # 14x7 top cap  
[node name="BottomCap" type="ColorRect" parent="Sprite2D/PlayerSprite"]    # 14x7 bottom cap

[sub_resource type="CapsuleShape2D" id="CapsuleShape2D_1"]
radius = 10.0
height = 40.0
```

**Result**: **Superior player physics and visuals** - players both look and behave like capsules, smoother movement, better collision behavior

### **Enhanced Head Collision Detection - Mario Party Chaos**
**Problem**: Head collision detection required minimum velocity, preventing ragdolls when players landed on each other while stationary
**Solution**: Removed velocity requirement for instant Mario Party-style chaos
- **No Velocity Requirement**: `_check_immediate_head_collision()` removed minimum_impact_velocity requirement entirely
- **Immediate Trigger**: Head collisions trigger ragdolls regardless of speed or movement state
- **Perfect for Respawn Scenarios**: Players landing on top of each other while stationary successfully trigger ragdolls
- **Collision Area Positioning**: CircleShape2D (radius=5.0) positioned at Vector2(0, -19.5) to extend above player model
- **Instant Detection**: Collision triggers immediately when entering head area
- **Impact Direction Calculation**: Proper physics direction calculation for realistic dramatic effects

**Head Area Setup**:
```gdscript
# MovementComponent._create_head_collision_area()
var head_shape = CircleShape2D.new()
head_shape.radius = 5.0  # Half character width
head_collision.position = Vector2(0, -19.5)  # Extends above TopCap
CollisionLayers.set_mask(head_area, CollisionLayers.Mask.PLAYER_DETECTION)
```

**No Velocity Check**:
```gdscript
func _check_immediate_head_collision(other_player: BasePlayer) -> void:
    # Head collisions always trigger ragdolls regardless of velocity for Mario Party-style chaos
    # This ensures players ragdoll when landing on each other, even when standing still
    _trigger_head_collision(other_player)
```

**Result**: **Mario Party-style head collision chaos** - any contact between players causes dramatic ragdolls, perfect for respawn scenarios and stationary interactions

### **Complete Map System Implementation - Slay the Spire Foundation**
**Problem**: Placeholder map system with no actual functionality
**Solution**: Complete implementation with generation, navigation, voting, and persistence
- **Map Generation**: 4-layer tree structure (10-14 nodes) with proper connectivity validation
- **Slay the Spire Navigation**: Connection-based movement, no backtracking, progressive unlocking  
- **Democratic Voting**: PartyProgressData integration for multiple path decisions
- **Map Persistence**: GameManager stores map data across sessions
- **UI Integration**: MapView coordinates all systems with UIFactory patterns
- **Testing Framework**: Comprehensive tests for generation and navigation

**Result**: **Complete Slay the Spire-style map progression** - players make strategic decisions about paths, vote democratically on choices, maintain progress across sessions

### **Object Indicator System Generalization - Universal Visual Indicators**
**Problem**: StatusIndicator system was player-specific and had crown alignment issues
```
PlayerStatusIndicator system - only worked for players
StatusIndicatorManager - player-centric design
Crown emoji not properly centered above player's head
```

**Solution**: Complete generalization to universal ObjectIndicator system
- **System Rename**: StatusIndicator → ObjectIndicator (works with any object)
- **File Rename**: All component files renamed with proper class updates
- **BasePlayer Update**: Uses ObjectIndicatorManager instead of StatusIndicatorManager
- **Crown Alignment Fix**: Improved centering logic and container setup
- **Scene Updates**: base_player.tscn references new object_indicator_manager.gd
- **Example Updates**: New object_indicator_example.gd and object_indicator_demo.gd

**Crown Leadership Fix**: Fixed bug where crown appeared immediately when all players tied
- **Problem**: `PhysicsMinigame._get_elimination_leader()` returned first player when stats tied
- **Solution**: Modified leadership logic to require clear performance gap
- **Returns null** when multiple players tied at top performance  
- **Crown only appears** when there's actual performance difference, never at round start

**Result**: **Universal indicator system** - works for players, items, NPCs, any object + properly centered crowns + correct tie handling

### **Enhanced Collision System - Environmental Interactions**
**Problem**: Limited collision layers prevented environmental interactions
**Solution**: Added TRIGGERS and DESTRUCTIBLES layers with supporting systems
- **TRIGGERS Layer**: Area2D triggers for environmental interactions (speed boosts, hazards, checkpoints)
- **DESTRUCTIBLES Layer**: Breakable objects that projectiles can damage
- **TriggerItem System**: Environmental triggers with team restrictions and effect types
- **CollisionLayers Enhancement**: New setup methods for environmental objects
- **Integration**: Proper collision mask combinations for complex interactions

**Result**: **Rich environmental interactions** - speed zones, hazards, destructible cover, team-specific triggers

### **Voting System Implementation - Democratic Gameplay**
**Problem**: No mechanism for multiplayer decision making
**Solution**: PartyProgressData-based voting system with UI integration
- **Party-Wide Decisions**: Democratic voting for map path selection
- **Voting Session Management**: Timeout handling, vote tracking, result calculation
- **UI Integration**: MapView creates voting interfaces using UIFactory patterns
- **Tie Breaking**: Random selection with clear voting results display
- **Vote Validation**: Player eligibility, duplicate prevention, timeout protection

**Result**: **Democratic multiplayer decisions** - players vote on map paths, fair resolution of choices, prevents conflicts

### **Map State Persistence - Session Continuity**
**Problem**: Maps regenerated every time, losing player progress
**Solution**: GameManager-based map data persistence across sessions
- **Persistent Storage**: GameManager stores MapData and navigation state
- **Session Continuity**: Maps persist across minigame sessions
- **State Restoration**: Navigation resumes from exact previous state
- **Progress Tracking**: Visited nodes, available moves, current position maintained
- **Lazy Loading**: Maps only generated when no persistent data exists

**Result**: **Persistent map progression** - players maintain map progress across sessions, strategic decisions have lasting impact

### **Enhanced Leadership Tracking - Performance-Based Crowns**
**Problem**: Crown leadership logic was flawed with incorrect tie detection
**Solution**: Sophisticated leadership algorithm with proper performance evaluation
- **Multi-Metric Evaluation**: Primary (lives), secondary (kills), tertiary (damage) metrics
- **Proper Tie Detection**: Two-pass algorithm finds all players at top performance
- **Performance Gap Requirement**: Crown only appears when there's clear leader
- **Real Kill Tracking**: Actual score integration instead of hardcoded values
- **Crown Persistence**: Leadership maintains during tied states appropriately

**Result**: **Accurate performance-based leadership** - crown correctly identifies and displays current leader, handles ties properly

## Previous Architectural Changes

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

### **Architecture Refactor Completion - Mario Party Foundation Complete**
**Date**: Latest Implementation
**Scope**: Completed the 3 remaining architecture tasks for Mario Party-style minigame foundation

**Task 1 - Configuration-Driven Weapon Properties**:
- **Replaced hard-coded @export values** in BaseWeapon with ItemConfig loading
- **Extended ItemConfig** with melee properties (swing_range, swing_damage, knockback_force)
- **Added _load_weapon_config()** and **_apply_weapon_config()** methods
- **Updated pistol.tres and bat.tres** with complete weapon specifications
- **Pistol and Bat subclasses** override config application for specialized properties

**Task 2 - Event-Driven Weapon Positioning**:
- **Added EventBus positioning system** with weapon_position_requested/provided signals
- **BaseWeapon _physics_process()** requests position updates when held
- **WeaponComponent responds** to position requests with proper holder validation
- **Eliminates direct component access** - weapons position via EventBus communication only

**Task 3 - Complete Lazy Loading Implementation**:
- **HUDController** - Player HUD scene lazy loaded when creating HUD
- **Main.gd** - All scenes (menu, map, minigames) lazy loaded on first access
- **PlayerSpawner** - Player scene lazy loaded when first spawning
- **Faster startup times** - no resources loaded during application initialization

**Result**: **Mario Party Foundation Complete** - Data-driven weapons, event-driven positioning, complete lazy loading, ready for unlimited minigame variety with Duck Game combat mechanics.

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
- **Map system complete** - generation, navigation, voting, persistence functional
- **Object indicators generalized** - universal system for any object type
- **Collision system enhanced** - environmental interactions with TRIGGERS/DESTRUCTIBLES
- **Voting system implemented** - democratic decision making for multiplayer

## For AI Agents: Development Guidelines

### **1. Architecture Design Pattern**

When adding functionality, ask:
1. Where does this belong?
2. What other systems might need this?
3. What's the most general case?
4. How would different types implement this?

Find the right abstraction level. Design for universal base functionality with specialized implementations.

### **2. Map System Development**
```gdscript
# Map generation with configuration
var config: MapGenerationConfig = ConfigManager.get_map_generation_config("default_generation")
var map_data: MapData = MapGenerator.generate(config)

# Navigation with democratic voting
var navigation: MapNavigation = MapNavigation.new(party_progress)
navigation.initialize_map(map_data, "start")

# Handle multiple path decisions
var available_moves: Array[String] = navigation.get_available_moves()
if available_moves.size() > 1:
    var decision_index: int = navigation.start_node_voting(30)
    # UI creates voting interface, players vote, then resolve
    var success: bool = navigation.resolve_node_voting(decision_index)

# Map persistence across sessions
GameManager.store_map_data(map_data, navigation_data)
```

### **3. Minigame Lives & Victory Control**

Minigames control their own rules. No automatic behavior.

```gdscript
# Available tools:
respawn_manager.block_player_respawn(player_id)
victory_condition_manager.eliminate_player(player_id)
EventBus.emit_player_lives_changed(player_id, new_lives)

# Pattern: Connect to events YOU want to handle
func _on_physics_initialize() -> void:
    EventBus.player_died.connect(_on_my_minigame_player_died)

func _on_my_minigame_player_died(player_id: int) -> void:
    # Your minigame decides what happens
    pass
```

### **4. Object Indicator Development**
```gdscript
# Universal system - works with any object
func add_leadership_indicator_to_player(player: BasePlayer) -> void:
    player.object_indicators.add_leadership_indicator("👑", Color.GOLD)

func add_status_effect_to_item(item: BaseItem, effect_name: String) -> void:
    item.object_indicators.add_buff_indicator(effect_name, "⚡", Color.CYAN)

# Collection system for predictable sizing
func setup_ammo_display(weapon: BaseWeapon) -> void:
    var ammo_indicators: Array[ObjectIndicatorData] = []
    for i in range(weapon.ammo_capacity):
        var indicator: ObjectIndicatorData = ObjectIndicatorData.new()
        indicator.configure("ammo_" + str(i), "●", Color.GREEN)
        ammo_indicators.append(indicator)
    
    weapon.object_indicators.add_collection_indicator("ammo", ammo_indicators)
    weapon.object_indicators.set_width_constraints(weapon.size.x / 2, true, true)
```

### **5. Weapon System Development**
```gdscript
# Proper bullet pooling with state management
func _shoot() -> bool:
    var bullet: Node = PoolManager.get_item("bullet")
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

### **6. Collision System Development**
```gdscript
# Use CollisionLayers enum for all setup
CollisionLayers.setup_player(player)
CollisionLayers.setup_trigger(speed_boost_area)
CollisionLayers.setup_destructible(breakable_crate)

# Environmental trigger creation
var trigger: TriggerItem = TriggerItem.new()
trigger.trigger_type = "hazard"
trigger.effect_strength = 2.0
trigger.affected_teams = ["red"]  # Only affects red team
CollisionLayers.setup_trigger(trigger)

# Check collision capabilities  
if CollisionLayers.can_collide_with(projectile, CollisionLayers.Layer.DESTRUCTIBLES):
    # Handle destructible collision
```

### **7. Voting System Development**
```gdscript
# Start democratic voting
func start_path_voting(available_paths: Array[String]) -> int:
    var node_ids: Array[int] = []
    for path in available_paths:
        node_ids.append(_convert_path_to_id(path))
    
    return party_progress.add_node_voting(node_ids, 30)  # 30 second deadline

# Handle player votes
func on_player_vote(decision_index: int, player_id: int, choice_index: int) -> void:
    var success: bool = party_progress.vote_for_node(decision_index, player_id, choice_index)
    if success:
        _update_voting_ui()

# Check completion and resolve
func check_voting_completion(decision_index: int) -> void:
    if party_progress.is_voting_complete(decision_index):
        var winner: int = party_progress.resolve_voting(decision_index)
        var chosen_path: String = available_paths[winner]
        _execute_chosen_path(chosen_path)
        party_progress.remove_decision(decision_index)
```

### **8. UI Architecture Best Practices**
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

### **9. Object Pooling Best Practices**
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

### **10. Component System Patterns** 
```gdscript
# Use correct component names (InputComponent not InputController)
var input_component: InputComponent = player.get_component(InputComponent)
if input_component and input_component.has_method("setup_for_player"):
    input_component.setup_for_player(player_id)

# Health management per-minigame (not global defaults)
func _initialize_component() -> void:
    current_health = max_health  # Use export value, not game_config default
```

### **11. Modern Syntax Reminders**
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

### **11. Collection Indicator Development**
```gdscript
# Set up predictable sizing for indicator collections
func setup_ammo_display(weapon: BaseWeapon) -> void:
    # Set width constraint to half weapon width with aspect ratio maintained
    weapon.object_indicators.set_width_constraints(weapon.size.x / 2, true, true)
    
    # Add bullets to collection with priority-based sorting
    for i in range(weapon.ammo_capacity):
        var bullet_data: ObjectIndicatorData = ObjectIndicatorData.new()
        bullet_data.configure("bullet_" + str(i), "●", Color.GREEN)
        weapon.object_indicators.add_collection_indicator("ammo", "bullet_" + str(i), bullet_data, float(i))

# Status effect collections with automatic organization
func add_status_effects(player: BasePlayer, effects: Array[Dictionary]) -> void:
    for effect in effects:
        var effect_data: ObjectIndicatorData = ObjectIndicatorData.create_buff_indicator(effect.icon, effect.color)
        player.object_indicators.add_collection_indicator("buffs", effect.id, effect_data, effect.priority)
    
    # Real-time scaling applied automatically on each addition
```

### **12. Enhanced Ragdoll Development**
```gdscript
# Trigger dramatic ragdolls for Mario Party-style chaos
func apply_dramatic_ragdoll(player: BasePlayer, impact_direction: Vector2 = Vector2.ZERO) -> void:
    var ragdoll_component: RagdollComponent = player.get_component(RagdollComponent)
    if ragdoll_component:
        # Head collision ragdolls are 2.4x more dramatic than regular ragdolls
        ragdoll_component.enter_head_collision_ragdoll(impact_direction)

# Enhanced force application with multiple impact points
func apply_enhanced_ragdoll_force(ragdoll_body: RigidBody2D) -> void:
    # Doubled base tipping force for more dramatic effect
    var base_tipping_force: Vector2 = Vector2(0, -120)  # 2x stronger than original
    var random_chaos: Vector2 = Vector2(randf_range(-30.0, 30.0), randf_range(10.0, 30.0))
    
    # Apply forces at different points for enhanced spinning
    ragdoll_body.apply_impulse(base_tipping_force + random_chaos, Vector2(0, -20))  # Top offset
    ragdoll_body.apply_impulse(Vector2(randf_range(-75.0, 75.0), 0), Vector2(15, 0))  # Side spin

# No velocity requirement for head collisions - instant chaos
func check_head_collision(other_player: BasePlayer) -> void:
    # Always trigger regardless of speed for Mario Party-style chaos
    if other_player.current_state == BasePlayer.PlayerState.ALIVE:
        _trigger_head_collision(other_player)
```

### **13. Momentum-Based Throwing Development**
```gdscript
# Calculate throw force from player momentum for natural physics
func calculate_throw_force(player: BasePlayer) -> float:
    var velocity_magnitude = player.velocity.length()
    var input_magnitude = player.movement.input_vector.length() if player.movement else 0.0
    
    # Standing still = gentle drop (50.0), moving = weaponized throw (up to 500.0)
    if velocity_magnitude < 50.0 and input_magnitude < 0.1:
        return 50.0  # Gentle drop
    else:
        var velocity_factor = min(velocity_magnitude / 300.0, 1.0)
        var input_factor = min(input_magnitude, 1.0)
        var momentum_factor = max(velocity_factor, input_factor * 0.8)
        return 50.0 + (momentum_factor * 450.0)

# Force-based weaponization with enhanced physics
func throw_item_with_physics(item: BaseItem, direction: Vector2, force: float, thrower_id: int) -> bool:
    if force > 200.0:
        # Weaponized throw - projectile mode with enhanced physics
        item.linear_damp = 0.05  # 10x less damping for projectile flight
        item.angular_damp = 0.1
        var projectile_material = PhysicsMaterial.new()
        projectile_material.friction = 0.1  # 3x less friction
        projectile_material.bounce = 0.3
        item.physics_material_override = projectile_material
        item.is_thrown_projectile = true
        item.thrown_by_id = thrower_id
    else:
        # Gentle drop - normal item physics
        item.linear_damp = 0.2  # 5x less than Godot default
        item.angular_damp = 0.5  # 2x less than Godot default
    
    item.linear_velocity = direction.normalized() * force
    return true

# Attribution preservation for proper kill tracking
func apply_weapon_damage_with_attribution(weapon: BaseWeapon, target: BasePlayer) -> void:
    # Store attacker info BEFORE damage operations to prevent clearing
    var attacker_id: int = weapon.thrown_by_id if weapon.is_thrown_projectile else weapon.holder_id
    var source_name: String = "Thrown " + weapon.item_name if weapon.is_thrown_projectile else weapon.item_name
    
    target.health.take_damage(weapon.throw_damage, weapon, attacker_id, source_name)
```

### **14. Capsule Collision Development**
```gdscript
# Setup capsule collision for better physics
func setup_capsule_player(player: BasePlayer) -> void:
    var capsule_shape = CapsuleShape2D.new()
    capsule_shape.radius = 10.0
    capsule_shape.height = 40.0
    player.collision_shape.shape = capsule_shape
    
    # Benefits: smoother movement, natural collision behavior, better wall sliding
    CollisionLayers.setup_player(player)

# Create capsule visual structure matching collision
func create_capsule_visuals(player_sprite: Node2D, color: Color) -> void:
    # Main body (20x20 rectangle)
    var capsule_body = ColorRect.new()
    capsule_body.name = "CapsuleBody"
    capsule_body.size = Vector2(20, 20)
    capsule_body.position = Vector2(-10, -10)
    capsule_body.color = color
    player_sprite.add_child(capsule_body)
    
    # Top cap (14x7 narrower)
    var top_cap = ColorRect.new()
    top_cap.name = "TopCap"
    top_cap.size = Vector2(14, 7)
    top_cap.position = Vector2(-7, -17)
    top_cap.color = color
    player_sprite.add_child(top_cap)
    
    # Bottom cap (14x7 narrower)
    var bottom_cap = ColorRect.new()
    bottom_cap.name = "BottomCap"
    bottom_cap.size = Vector2(14, 7)
    bottom_cap.position = Vector2(-7, 10)
    bottom_cap.color = color
    player_sprite.add_child(bottom_cap)

# Color all capsule components
func apply_capsule_color(player_sprite: Node2D, color: Color) -> void:
    for child in player_sprite.get_children():
        if child is ColorRect:
            child.color = color
```

### **15. Head Collision Detection Development**
```gdscript
# Setup head collision area for Mario Party-style chaos
func setup_head_collision(player: BasePlayer) -> void:
    var head_area = Area2D.new()
    head_area.name = "HeadCollisionArea"
    player.add_child(head_area)
    
    var head_collision = CollisionShape2D.new()
    var head_shape = CircleShape2D.new()
    head_shape.radius = 5.0  # Half character width
    head_collision.shape = head_shape
    head_collision.position = Vector2(0, -19.5)  # Extends above TopCap
    head_area.add_child(head_collision)
    
    # Setup collision layers for player detection only
    CollisionLayers.set_layer(head_area, CollisionLayers.Layer.NONE)
    CollisionLayers.set_mask(head_area, CollisionLayers.Mask.PLAYER_DETECTION)
    
    head_area.body_entered.connect(_on_head_area_entered)

# Instant head collision trigger - no velocity checks
func _on_head_area_entered(body: Node2D) -> void:
    if body is BasePlayer and body != player:
        var other_player: BasePlayer = body as BasePlayer
        # Instant trigger regardless of velocity for Mario Party chaos
        if other_player.current_state == BasePlayer.PlayerState.ALIVE:
            trigger_head_collision(other_player)

# Calculate impact direction for realistic dramatic physics
func trigger_head_collision(other_player: BasePlayer) -> void:
    var impact_direction: Vector2 = player.global_position - other_player.global_position
    impact_direction = impact_direction.normalized()
    
    # Add velocity considerations for more dynamic impacts
    var relative_velocity: Vector2 = other_player.velocity - player.velocity
    if relative_velocity.length() > 50.0:
        impact_direction += relative_velocity.normalized() * 0.5
    
    var ragdoll_component: RagdollComponent = player.get_component(RagdollComponent)
    if ragdoll_component:
        ragdoll_component.enter_head_collision_ragdoll(impact_direction)
```

### **16. Object Pooling Best Practices**
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

### **17. Component System Patterns** 
```gdscript
# Use correct component names (InputComponent not InputController)
var input_component: InputComponent = player.get_component(InputComponent)
if input_component and input_component.has_method("setup_for_player"):
    input_component.setup_for_player(player_id)

# Health management per-minigame (not global defaults)
func _initialize_component() -> void:
    current_health = max_health  # Use export value, not game_config default
```

### **18. Modern Syntax Reminders**
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

1. **Understand the current state**: Critical bugs have been fixed with architectural solutions including operational weapon system and complete map system
2. **Follow component architecture**: Don't make systems monolithic  
3. **Use proper inheritance**: Minigames use clean class_name hierarchy with automatic UI cleanup
4. **Apply critical thinking pattern**: Question assumptions, find the right abstraction level for new systems
5. **Use universal damage system**: All minigame types can handle damage with specialized implementations
6. **Control lives and victory**: Minigames have complete control over their own rules (lives, respawn, elimination)
7. **Follow lazy loading principles**: Load resources only when needed, minimal startup overhead
8. **Use modern syntax**: `super.method()`, Dictionary structures, direct static calls
9. **Use existing patterns**: Factory, configuration, pooling systems in place
10. **Check autoloads**: 10 global systems handle cross-cutting concerns (including PlayerManager)
11. **Implement proper cleanup**: Always add `_exit_tree()` methods for resource management
12. **Prevent warnings**: Use type-safe ternary operators, descriptive variable names, proper static calls
13. **Test your changes**: Create temporary test scenes to validate specific changes, follow actual user interaction paths, then delete them
14. **Test regularly**: Use system health commands to verify overall stability
15. **Know the weapon system**: Proper pooling, signal management, holder preservation patterns
16. **Know the UI lifecycle**: BaseMinigame automatically handles HUD cleanup
17. **Know the lazy loading**: Pools, configs, sessions initialize only when needed
18. **Know the damage system**: Universal base handling with minigame-specific implementations
19. **Know the lives system**: Minigame-controlled lives, respawn blocking, victory conditions
20. **Know the map system**: Complete Slay the Spire implementation with generation, navigation, voting, persistence
21. **Know the object indicators**: Universal visual system for players, items, NPCs with collections and constraints
22. **Know the voting system**: Democratic decision making with PartyProgressData, timeout handling, tie resolution
23. **Know the collision system**: Enhanced layers for environmental interactions (TRIGGERS, DESTRUCTIBLES)
24. **Know the syntax patterns**: 
   - `super.method_name()` for parent calls
   - Dictionary for complex data structures
   - Direct static method calls: `ClassName.static_method()`
   - Signal connection safety: `if not signal.is_connected(method):`
   - Object pooling state: `object.is_pooled = true`
   - Holder preservation: `temp_holder = holder` during reparenting
   - **ID-based architecture**: `var player_id: int` + `PlayerManager.get_player(id)` for cross-system references
   - **Weapon pickup**: `weapon.pickup_by_id(player.player_data.player_id)` not `weapon.pickup(player)`
   - **Player registration**: `PlayerManager.register_player(player_data.player_id, self)` in `BasePlayer._ready()`
   - Unified damage: `player.health.take_damage(damage, source, attacker_id, source_name)` for all sources
   - UI creation: `UIFactory.create_*()` → `UIManager.show_*()` for all UI elements
   - **Map navigation**: `MapNavigation.move_to_node()` with validation and voting support
   - **Object indicators**: `object_indicators.add_leadership_indicator()` for universal visual feedback
   - **Collection indicators**: `object_indicators.add_collection_indicator(collection_id, item_id, data, priority)` with automatic scaling
   - **Width constraints**: `object_indicators.set_width_constraints(max_width, enable_scaling, keep_aspect_ratio)` for predictable sizing
   - **Voting integration**: `party_progress.add_node_voting()` for democratic decisions
   - **Collision setup**: `CollisionLayers.setup_trigger()` for environmental interactions
   - **Momentum throwing**: `_calculate_throw_force_from_momentum()` for physics-based throws
   - **Force weaponization**: `force > 200.0 = projectile mode, force < 200.0 = gentle drop`
   - **Capsule collision**: `CapsuleShape2D(radius=10.0, height=40.0)` for better player physics
   - **Head collision**: `_check_immediate_head_collision()` with no velocity requirement for Mario Party chaos
   - **Enhanced ragdolls**: `enter_head_collision_ragdoll()` with 2.4x dramatic forces
   - **Attribution preservation**: Store `attacker_id` BEFORE damage operations to prevent clearing
   - `Time.get_unix_time_from_system()` for timestamps
   - `_exit_tree()` for cleanup, signal disconnection, resource freeing
   - Type conversion in ternary: `str(node.name) if node else "Default"`
25. **Reference this document**: All critical information is here

## Summary

Architecture is stable with major new systems implemented. Use established patterns: components, factories, configs, ID-based references, lazy loading, object pooling, **map generation/navigation**, **democratic voting**, **universal object indicators**, **enhanced collision layers**. Follow existing conventions and leverage the complete map system for Slay the Spire-style progression.

### **Testing Commands**

**CRITICAL**: Always use `--quit-after 3` with `--headless` to prevent infinite hanging. The parameter specifies **iterations** (not seconds), forcing Godot to exit after 3 main loop cycles even if scripts fail to load or hang.

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

#### **Scene-Specific Testing (Recommended)**
```bash
# Test minigame system (~1.2s, validates full minigame pipeline)
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3 scenes/minigames/sudden_death_minigame.tscn

# Test UI system (~1.2s, validates menu and UI systems)
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3 scenes/ui/main_menu.tscn

# Test map system (~1.2s, validates map generation and navigation)  
/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3 scenes/ui/map_view.tscn

# Benefits:
# - 4x faster than default scene loading (~1.2s vs 5s)
# - Tests specific game systems and components
# - Better logging shows component initialization
# - Modular testing of different subsystems
```

#### **Create Temporary Test Scene Pattern**
```bash
# 1. Create a temporary test scene to validate your changes
# Example: testing map generation
# File: scenes/temp_map_test.tscn (or any temporary name)

# 2. Create a simple script that tests your specific changes:
# extends Control
# func _ready():
#     # Test map generation
#     var map_data: MapData = MapGenerator.generate()
#     print("Map generated: ", map_data.get_total_nodes(), " nodes")
#     var navigation: MapNavigation = MapNavigation.new(PartyProgressData.new())
#     navigation.initialize_map(map_data, "start")
#     print("Navigation initialized at: ", navigation.current_node_id)
#     get_tree().quit()  # Auto-exit after test

# 3. Run the test scene directly (ALWAYS include --quit-after 3)
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_map_test.tscn --headless --quit-after 3

# 4. Clean up - delete the temporary test scene and script
rm scenes/temp_map_test.tscn scripts/temp_map_test.gd

# Benefits:
# - Self-contained testing of specific changes
# - No impact on main codebase
# - Quick validation before committing changes
# - Easy to create, test, and remove
# - Safe from hanging with --quit-after 3
```

#### **Direct Scene Testing Pattern**
```bash
# Run any existing scene directly for testing (ALWAYS include --quit-after 3)
/Applications/Godot.app/Contents/MacOS/Godot --path . path/to/your/scene.tscn --headless --quit-after 3
```