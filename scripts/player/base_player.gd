class_name BasePlayer
extends CharacterBody2D

## Base player class using component architecture
## Acts as coordinator for player components: movement, health, weapon, input, ragdoll
## Pure projectile-based weapon system
## Implements IWeaponHolder interface for weapon management

# Player states
enum PlayerState {
	ALIVE,
	RAGDOLLED,
	DEAD,
	SPECTATING
}

# Configuration reference
var game_config: GameConfig

# Core components with strict typing - universal held object system
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var item: ItemComponent = $ItemComponent  # ItemComponent - universal held objects
@onready var input: InputComponent = $InputComponent
@onready var ragdoll: RagdollComponent = $RagdollComponent
@onready var object_indicators: ObjectIndicatorManager = $ObjectIndicatorManager

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Player state and data
var current_state: PlayerState = PlayerState.ALIVE : set = _set_current_state
var player_data: PlayerData
var spawn_position: Vector2 = Vector2.ZERO

# Player lifecycle signals
signal player_state_changed(new_state: PlayerState)
signal player_spawned()
signal player_respawned()

func _ready() -> void:
	# Wait one frame for children to be ready
	await get_tree().process_frame
	
	# Load game configuration
	game_config = GameConfig.get_instance()
	
	# Set collision layers for player (always run this regardless of player_data)
	CollisionLayers.setup_player(self)
	
	# Initialize default player data if not assigned
	if not player_data:
		player_data = PlayerData.new(0, "Player")
		Logger.warning("BasePlayer created default PlayerData - this should only happen in standalone testing", "BasePlayer")
		return
	else:
		Logger.system("BasePlayer using assigned PlayerData: " + player_data.player_name + " (ID: " + str(player_data.player_id) + ")", "BasePlayer")
	
	# Setup components
	_setup_components()
	_connect_component_signals()
	
	# Register with PlayerManager for ID-based lookups
	PlayerManager.register_player(player_data.player_id, self)
	
	Logger.system("BasePlayer initialized: " + player_data.player_name + " with projectile weapon system", "BasePlayer")

func _physics_process(_delta: float) -> void:
	# Components handle their own physics processing
	# BasePlayer just coordinates state changes
	match current_state:
		PlayerState.ALIVE:
			# Normal physics handled by components
			pass
		PlayerState.RAGDOLLED:
			# Ragdoll physics handled by RagdollComponent
			pass
		PlayerState.DEAD:
			# Dead state - minimal processing
			velocity = Vector2.ZERO
		PlayerState.SPECTATING:
			# Spectating state - free movement could be implemented here
			pass

## Setup component configuration and initialization
func _setup_components() -> void:
	# Wait for components to be ready
	await get_tree().process_frame
	
	# Configure input component for this player
	if input and player_data:
		input.setup_for_player(player_data.player_id)

## Connect component signals for communication - throwing-centric style
func _connect_component_signals() -> void:
	# Health component signals
	if health:
		health.health_changed.connect(_on_health_changed)
		health.died.connect(_on_health_died)
		health.respawned.connect(_on_health_respawned)
	
	# Movement component signals
	if movement:
		movement.facing_changed.connect(_on_facing_changed)
		movement.landed.connect(_on_movement_landed)
		movement.jumped.connect(_on_movement_jumped)
		movement.player_hit_in_head.connect(_on_movement_player_hit_in_head)
	
	# Universal item component signals
	if item:
		item.item_picked_up.connect(_on_item_picked_up)
		item.item_thrown.connect(_on_item_thrown)
		item.item_fired.connect(_on_item_fired)
		item.item_used.connect(_on_item_used)
		item.nearby_items_changed.connect(_on_nearby_items_changed)
		Logger.system("Connected universal item signals for " + player_data.player_name, "BasePlayer")
	
	# Momentum-based input component signals  
	if input:
		input.movement_input_changed.connect(_on_input_movement_changed)
		input.jump_input_pressed.connect(_on_input_jump_pressed)
		input.fire_input_pressed.connect(_on_input_fire_pressed)
		input.throw_input_pressed.connect(_on_input_throw_pressed)
		input.pickup_input_pressed.connect(_on_input_pickup_pressed)
		Logger.system("Connected momentum-based input signals for " + player_data.player_name, "BasePlayer")
	
	# Ragdoll component signals
	if ragdoll:
		ragdoll.ragdoll_entered.connect(_on_ragdoll_entered)
		ragdoll.ragdoll_exited.connect(_on_ragdoll_exited)

## Set player state with validation
func _set_current_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
		
	var old_state: PlayerState = current_state
	current_state = new_state
	
	_handle_state_transition(old_state, new_state)
	player_state_changed.emit(new_state)
	
	var player_display: String = ""
	if player_data:
		player_display = player_data.player_name + " (Player " + str(player_data.player_id) + ")"
	else:
		player_display = "Unknown Player"
	Logger.player(player_display + ": state changed: " + PlayerState.keys()[old_state] + " -> " + PlayerState.keys()[new_state], "BasePlayer")

## Handle state transitions between different player states
func _handle_state_transition(old_state: PlayerState, new_state: PlayerState) -> void:
	match new_state:
		PlayerState.ALIVE:
			_enter_alive_state()
		PlayerState.RAGDOLLED:
			_enter_ragdoll_state()
		PlayerState.DEAD:
			_enter_dead_state()
		PlayerState.SPECTATING:
			_enter_spectating_state()

## Enter alive state
func _enter_alive_state() -> void:
	if input:
		input.set_input_enabled(true)
	if item:
		item.set_pickup_enabled(true)

## Enter ragdoll state
func _enter_ragdoll_state() -> void:
	if ragdoll and not ragdoll.is_in_ragdoll_state():
		ragdoll.enter_ragdoll_state()

## Enter dead state
func _enter_dead_state() -> void:
	if ragdoll and not ragdoll.is_in_ragdoll_state():
		ragdoll.enter_death_ragdoll()
	if input:
		input.set_input_enabled(false)
	if item:
		item.set_pickup_enabled(false)

## Enter spectating state
func _enter_spectating_state() -> void:
	if input:
		input.set_input_enabled(false)
	if item:
		item.set_pickup_enabled(false)

## Set health (called by minigame systems)
func set_health(new_health: int) -> void:
	if health:
		health.set_health(new_health)

## Take damage
func take_damage(damage: int, source: Node = null, attacker_id: int = -1, source_name: String = "Environmental") -> void:
	if health:
		health.take_damage(damage, source, attacker_id, source_name)

## Heal the player
func heal(amount: int) -> void:
	if health:
		health.heal(amount)

## Die (called by minigame)
func die() -> void:
	current_state = PlayerState.DEAD

## Respawn the player
func respawn() -> void:
	var player_display: String = ""
	if player_data:
		player_display = player_data.player_name + " (Player " + str(player_data.player_id) + ")"
	else:
		player_display = "Unknown Player"
	
	Logger.player(player_display + ": respawning at " + str(spawn_position), "BasePlayer")
	
	# Clean up any ragdoll state
	if ragdoll:
		ragdoll.cleanup_ragdoll_state()
	
	# Reset state to alive
	current_state = PlayerState.ALIVE
	
	# Restore health
	if health:
		health.respawn()
	
	# Reset position
	global_position = spawn_position
	velocity = Vector2.ZERO
	
	# Restore visual state - full transparency, white color, no rotation
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full white with full transparency
	rotation = 0.0
	
	# Emit respawn events
	player_respawned.emit()
	EventBus.emit_player_respawned(player_data.player_id)
	
	Logger.player(player_display + ": respawned successfully!", "BasePlayer")

## Set spawn position
func set_spawn_position(spawn_pos: Vector2) -> void:
	spawn_position = spawn_pos
	var player_display: String = ""
	if player_data:
		player_display = player_data.player_name + " (Player " + str(player_data.player_id) + ")"
	else:
		player_display = "Unknown Player"
	Logger.system("Set spawn position for " + player_display + " to " + str(spawn_position), "BasePlayer")

## Get component by type (utility method) - universal held objects
func get_component(component_type) -> BaseComponent:
	match component_type:
		MovementComponent:
			return movement
		HealthComponent:
			return health
		InputComponent:
			return input
		RagdollComponent:
			return ragdoll
		ItemComponent:
			return item
		_:
			Logger.warning("Unknown component type requested: " + str(component_type), "BasePlayer")
			return null

## Universal held object system methods

## Fire currently held item (if it's a weapon)
func fire_weapon() -> bool:
	if item:
		return item.fire_held_item()
	return false

## Use currently held item (consumables, tools, etc.)
func use_item() -> bool:
	if item:
		return item.use_held_item()
	return false

## Throw currently held item with specified force (unified system)
func throw_item(force: float = 0.0) -> bool:
	if item:
		return item.throw_held_item(force)
	return false

## Legacy method for compatibility
func throw_weapon(force: float = 0.0) -> bool:
	return throw_item(force)

## Calculate throw force based on player momentum
func _calculate_throw_force_from_momentum() -> float:
	# Get player velocity and movement input
	var current_velocity = velocity.length()
	var movement_input = movement.input_vector if movement else Vector2.ZERO
	var input_magnitude = movement_input.length()
	
	# Base force ranges
	var gentle_drop_force = 50.0     # Standing still
	var max_throw_force = 500.0      # Full speed movement
	
	# Check if player is effectively stationary
	var velocity_threshold = 50.0    # Below this = considered stationary
	var input_threshold = 0.1        # Below this = no input
	
	if current_velocity < velocity_threshold and input_magnitude < input_threshold:
		# Standing still = gentle drop
		return gentle_drop_force
	else:
		# Moving = throw with momentum-based force
		var velocity_factor = min(current_velocity / 300.0, 1.0)  # Normalize to 0-1
		var input_factor = min(input_magnitude, 1.0)              # Already 0-1
		
		# Combine velocity and input for final force
		var momentum_factor = max(velocity_factor, input_factor * 0.8)  # Input slightly less influential
		var throw_force = gentle_drop_force + (momentum_factor * (max_throw_force - gentle_drop_force))
		
		return throw_force

## Pick up nearest item
func pickup_item() -> bool:
	if item:
		return item.pickup_nearest_item()
	return false

## Legacy method for compatibility
func pickup_weapon() -> bool:
	return pickup_item()

## Get currently held item
func get_held_item() -> BaseItem:
	if item:
		return item.get_held_item()
	return null

## Get currently held weapon (convenience method)
func get_held_weapon() -> BaseWeapon:
	if item:
		return item.get_held_weapon()
	return null

# Note: drop_held_item() removed - use throw_weapon() with low force instead

# Component signal handlers

## Health component signal handlers
func _on_health_changed(new_health: int, max_health: int) -> void:
	# Update player data
	if player_data:
		player_data.current_health = new_health
		player_data.max_health = max_health
	
	# Emit to EventBus for UI updates
	EventBus.player_health_changed.emit(player_data.player_id, new_health, max_health)

func _on_health_died() -> void:
	current_state = PlayerState.DEAD

func _on_health_respawned() -> void:
	if current_state == PlayerState.DEAD:
		current_state = PlayerState.ALIVE

## Movement component signal handlers
func _on_facing_changed(new_direction: int) -> void:
	# Update held item position when facing changes
	if item and item.get_held_item():
		var held_item_obj: BaseItem = item.get_held_item()
		if held_item_obj.has_method("_update_held_position"):
			held_item_obj._update_held_position()

func _on_movement_landed() -> void:
	Logger.debug(player_data.player_name + " landed", "BasePlayer")

func _on_movement_jumped() -> void:
	Logger.debug(player_data.player_name + " jumped", "BasePlayer")

func _on_movement_player_hit_in_head(other_player: BasePlayer) -> void:
	var other_name: String = other_player.player_data.player_name if other_player.player_data else "Unknown Player"
	Logger.debug(player_data.player_name + " was hit in the head by " + other_name, "BasePlayer")

## Universal item component signal handlers
func _on_item_picked_up(item_obj: BaseItem) -> void:
	Logger.pickup(player_data.player_name + " picked up " + item_obj.item_name, "BasePlayer")

func _on_item_thrown(item_obj: BaseItem, throw_velocity: Vector2) -> void:
	Logger.combat(item_obj.item_name + " thrown by " + player_data.player_name, "BasePlayer")

func _on_item_fired(item_obj: BaseItem) -> void:
	var weapon: BaseWeapon = item_obj as BaseWeapon
	if weapon:
		Logger.combat(weapon.item_name + " fired by " + player_data.player_name, "BasePlayer")

func _on_item_used(item_obj: BaseItem) -> void:
	Logger.item(item_obj.item_name, "used by " + player_data.player_name, "BasePlayer")

func _on_nearby_items_changed(nearby_items: Array[BaseItem]) -> void:
	Logger.debug(player_data.player_name + " nearby items: " + str(nearby_items.size()), "BasePlayer")

## Momentum-based input signal handlers
func _on_input_movement_changed(movement_input: Vector2) -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement_input, false)  # Jump handled separately

func _on_input_jump_pressed() -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement.input_vector, true)

func _on_input_fire_pressed() -> void:
	if current_state != PlayerState.ALIVE:
		return
	
	# Universal item system: Fire held weapon, or pick up item if unarmed
	if not fire_weapon():
		pickup_item()

func _on_input_throw_pressed() -> void:
	if current_state == PlayerState.ALIVE:
		# Calculate force from player momentum
		var momentum_force = _calculate_throw_force_from_momentum()
		throw_item(momentum_force)

func _on_input_pickup_pressed() -> void:
	if current_state == PlayerState.ALIVE:
		# Universal item system: Pick up nearby item
		pickup_item()

## Ragdoll component signal handlers
func _on_ragdoll_entered() -> void:
	current_state = PlayerState.RAGDOLLED
	EventBus.player_ragdolled.emit(player_data.player_id)

func _on_ragdoll_exited() -> void:
	if current_state == PlayerState.RAGDOLLED:
		current_state = PlayerState.ALIVE
		EventBus.player_recovered.emit(player_data.player_id)

# IWeaponHolder interface implementation

## Get item hold position from item component  
func get_weapon_hold_position() -> Vector2:
	if item and item.has_method("get_item_hold_position"):
		return item.get_item_hold_position()
	return global_position

## Get facing direction from movement component
func get_facing_direction() -> int:
	if movement:
		return movement.facing_direction
	return 1

## Get player ID from player data
func get_player_id() -> int:
	if player_data:
		return player_data.player_id
	return -1

## Get player data reference
func get_player_data() -> PlayerData:
	return player_data

## Get current velocity for weapon interfaces
func get_current_velocity() -> Vector2:
	return velocity

## Check if player can hold weapons based on state
func can_hold_weapons() -> bool:
	return current_state == PlayerState.ALIVE

## Add an indicator above the player
func add_indicator(indicator_id: String, indicator_data: ObjectIndicatorData) -> bool:
	if not object_indicators:
		Logger.warning("ObjectIndicatorManager not available on player", "BasePlayer")
		return false
	return object_indicators.add_indicator(indicator_id, indicator_data)

## Remove an indicator from the player
func remove_indicator(indicator_id: String, animate: bool = true) -> bool:
	if not object_indicators:
		return false
	return await object_indicators.remove_indicator(indicator_id, animate)

## Update an existing indicator
func update_indicator(indicator_id: String, new_data: ObjectIndicatorData) -> bool:
	if not object_indicators:
		return false
	return object_indicators.update_indicator(indicator_id, new_data)

## Check if player has a specific indicator
func has_indicator(indicator_id: String) -> bool:
	if not object_indicators:
		return false
	return object_indicators.has_indicator(indicator_id)

## Get all active indicators
func get_active_indicators() -> Array[String]:
	if not object_indicators:
		return []
	return object_indicators.get_active_indicators()

## Clear all indicators
func clear_indicators(animate: bool = true) -> void:
	if object_indicators:
		await object_indicators.clear_indicators(animate)

## Add leadership indicator (crown, lead, etc.)
func add_leadership_indicator(indicator_text: String = "👑", color: Color = Color.GOLD) -> bool:
	var data := ObjectIndicatorData.create_leadership_indicator(indicator_text, color)
	return add_indicator("leadership", data)

## Remove leadership indicator
func remove_leadership_indicator(animate: bool = true) -> bool:
	return await remove_indicator("leadership", animate)

## Add team indicator
func add_team_indicator(team_color: Color) -> bool:
	var data := ObjectIndicatorData.create_team_indicator(team_color)
	return add_indicator("team", data)

## Add buff indicator
func add_buff_indicator(buff_id: String, buff_text: String, color: Color = Color.GREEN) -> bool:
	var data := ObjectIndicatorData.create_buff_indicator(buff_text, color)
	return add_indicator("buff_" + buff_id, data)

## Add debuff indicator
func add_debuff_indicator(debuff_id: String, debuff_text: String, color: Color = Color.RED) -> bool:
	var data := ObjectIndicatorData.create_debuff_indicator(debuff_text, color)
	return add_indicator("debuff_" + debuff_id, data)

## Add temporary indicator that auto-removes
func add_temporary_indicator(indicator_id: String, text: String, color: Color = Color.YELLOW, duration: float = 3.0) -> bool:
	var data := ObjectIndicatorData.create_temporary_indicator(text, color, duration)
	return add_indicator(indicator_id, data)

func _exit_tree() -> void:
	# Unregister from PlayerManager for proper cleanup
	if player_data:
		PlayerManager.unregister_player(player_data.player_id)
