class_name BasePlayer
extends CharacterBody2D

## Base player class using component architecture
## Acts as coordinator for player components: movement, health, inventory, input, ragdoll

# Player states
enum PlayerState {
	ALIVE,
	RAGDOLLED,
	DEAD,
	SPECTATING
}

# Configuration reference
var game_config: GameConfig

# Core components with strict typing
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var input: InputComponent = $InputComponent
@onready var ragdoll: RagdollComponent = $RagdollComponent

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
	
	# Initialize default player data if not assigned
	if not player_data:
		player_data = PlayerData.new(0, "Player")
		Logger.warning("BasePlayer created default PlayerData - this should only happen in standalone testing", "BasePlayer")
	else:
		Logger.system("BasePlayer using assigned PlayerData: " + player_data.player_name + " (ID: " + str(player_data.player_id) + ")", "BasePlayer")
	
	# Set collision layers for player
	CollisionLayers.setup_player(self)
	
	# Setup components
	_setup_components()
	_connect_component_signals()
	
	Logger.system("BasePlayer initialized: " + player_data.player_name, "BasePlayer")

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

## Connect component signals for communication
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
	
	# Inventory component signals
	if inventory:
		inventory.item_picked_up.connect(_on_item_picked_up)
		inventory.item_dropped.connect(_on_item_dropped)
		inventory.item_used.connect(_on_item_used)
	
	# Input component signals
	if input:
		input.movement_input_changed.connect(_on_input_movement_changed)
		input.jump_input_pressed.connect(_on_input_jump_pressed)
		input.use_input_pressed.connect(_on_input_use_pressed)
		input.drop_input_pressed.connect(_on_input_drop_pressed)
	
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
	Logger.player(player_data.player_name, "state changed: " + PlayerState.keys()[old_state] + " -> " + PlayerState.keys()[new_state], "BasePlayer")

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
	if inventory:
		inventory.set_pickup_enabled(true)

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
	if inventory:
		inventory.set_pickup_enabled(false)

## Enter spectating state
func _enter_spectating_state() -> void:
	if input:
		input.set_input_enabled(false)
	if inventory:
		inventory.set_pickup_enabled(false)

## Set health (called by minigame systems)
func set_health(new_health: int) -> void:
	if health:
		health.set_health(new_health)

## Take damage
func take_damage(damage: int, source: Node = null) -> void:
	if health:
		health.take_damage(damage, source)

## Heal the player
func heal(amount: int) -> void:
	if health:
		health.heal(amount)

## Die (called by minigame)
func die() -> void:
	current_state = PlayerState.DEAD

## Respawn the player
func respawn() -> void:
	Logger.player(player_data.player_name, "respawning at " + str(spawn_position), "BasePlayer")
	
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
	
	# Restore visual state
	visible = true
	modulate = Color.WHITE
	rotation = 0.0
	
	# Emit respawn events
	player_respawned.emit()
	EventBus.emit_player_respawned(player_data.player_id)
	
	Logger.player(player_data.player_name, "respawned successfully!", "BasePlayer")

## Set spawn position
func set_spawn_position(spawn_pos: Vector2) -> void:
	spawn_position = spawn_pos
	Logger.system("Set spawn position for " + player_data.player_name + " to " + str(spawn_position), "BasePlayer")

## Get component by type (utility method)
func get_component(component_type) -> BaseComponent:
	match component_type:
		MovementComponent:
			return movement
		HealthComponent:
			return health
		InventoryComponent:
			return inventory
		InputComponent:
			return input
		RagdollComponent:
			return ragdoll
		_:
			Logger.warning("Unknown component type requested: " + str(component_type), "BasePlayer")
			return null

## Legacy compatibility methods (REMOVED - use components directly)
func set_input(movement_input: Vector2, jump: bool, use: bool) -> void:
	Logger.warning("DEPRECATED: set_input called - use InputComponent directly", "BasePlayer")
	if movement:
		movement.set_input(movement_input, jump)

func try_pickup_nearest_item() -> bool:
	if inventory:
		return inventory.try_pickup_nearest_item()
	return false

func drop_item() -> void:
	if inventory:
		inventory.drop_item()

func use_held_item() -> bool:
	if inventory:
		return inventory.use_held_item()
	return false

# Component signal handlers
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

func _on_facing_changed(new_direction: int) -> void:
	# Update held item position when facing changes
	if inventory and inventory.get_held_item():
		var item: BaseItem = inventory.get_held_item()
		if item.has_method("_update_held_position"):
			item._update_held_position()

func _on_movement_landed() -> void:
	Logger.debug(player_data.player_name + " landed", "BasePlayer")

func _on_movement_jumped() -> void:
	Logger.debug(player_data.player_name + " jumped", "BasePlayer")

func _on_item_picked_up(item: BaseItem) -> void:
	Logger.pickup(player_data.player_name + " picked up " + item.item_name, "BasePlayer")

func _on_item_dropped(item: BaseItem) -> void:
	Logger.item(item.item_name, "dropped by " + player_data.player_name, "BasePlayer")

func _on_item_used(item: BaseItem) -> void:
	Logger.item(item.item_name, "used by " + player_data.player_name, "BasePlayer")

func _on_input_movement_changed(movement_input: Vector2) -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement_input, false)  # Jump handled separately

func _on_input_jump_pressed() -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement.input_vector, true)

func _on_input_use_pressed() -> void:
	if current_state != PlayerState.ALIVE:
		return
		
	# Try to use held item first
	if not use_held_item():
		# If no item or item couldn't be used, try to pick up nearest item
		try_pickup_nearest_item()

func _on_input_drop_pressed() -> void:
	if current_state == PlayerState.ALIVE:
		drop_item()

func _on_ragdoll_entered() -> void:
	current_state = PlayerState.RAGDOLLED
	EventBus.player_ragdolled.emit(player_data.player_id)

func _on_ragdoll_exited() -> void:
	if current_state == PlayerState.RAGDOLLED:
		current_state = PlayerState.ALIVE
		EventBus.player_recovered.emit(player_data.player_id) 
