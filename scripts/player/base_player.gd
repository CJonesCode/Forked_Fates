class_name BasePlayer
extends CharacterBody2D

## Base player class using component architecture
## Acts as coordinator for player components: movement, health, weapon, input, ragdoll
## Pure projectile-based weapon system

# Player states
enum PlayerState {
	ALIVE,
	RAGDOLLED,
	DEAD,
	SPECTATING
}

# Configuration reference
var game_config: GameConfig

# Core components with strict typing - projectile weapon system
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var weapon = $WeaponComponent  # WeaponComponent - avoid circular dependency
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
	
	# Projectile weapon component signals
	if weapon:
		weapon.weapon_picked_up.connect(_on_weapon_picked_up)
		weapon.weapon_thrown.connect(_on_weapon_thrown)
		weapon.weapon_fired.connect(_on_weapon_fired)
		weapon.nearby_weapons_changed.connect(_on_nearby_weapons_changed)
		Logger.system("Connected projectile weapon signals for " + player_data.player_name, "BasePlayer")
	
	# Throwing-centric input component signals
	if input:
		input.movement_input_changed.connect(_on_input_movement_changed)
		input.jump_input_pressed.connect(_on_input_jump_pressed)
		input.fire_input_pressed.connect(_on_input_fire_pressed)
		input.throw_input_pressed.connect(_on_input_throw_pressed)
		input.pickup_input_pressed.connect(_on_input_pickup_pressed)
		Logger.system("Connected throwing-centric input signals for " + player_data.player_name, "BasePlayer")
	
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
	if weapon:
		weapon.set_pickup_enabled(true)

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
	if weapon:
		weapon.set_pickup_enabled(false)

## Enter spectating state
func _enter_spectating_state() -> void:
	if input:
		input.set_input_enabled(false)
	if weapon:
		weapon.set_pickup_enabled(false)

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

## Get component by type (utility method) - projectile weapons only
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
		_:
			# Handle WeaponComponent case without typed reference
			if str(component_type).ends_with("WeaponComponent"):
				return weapon
			Logger.warning("Unknown component type requested: " + str(component_type), "BasePlayer")
			return null

## Projectile weapon system methods

## Fire currently held weapon
func fire_weapon() -> bool:
	if weapon:
		return weapon.fire_held_weapon()
	return false

## Throw currently held weapon as projectile
func throw_weapon(force: float = 0.0) -> bool:
	if weapon:
		return weapon.throw_held_weapon(force)
	return false

## Pick up nearest weapon
func pickup_weapon() -> bool:
	if weapon:
		return weapon.pickup_nearest_weapon()
	return false

## Get currently held weapon
func get_held_weapon() -> BaseWeapon:
	if weapon:
		return weapon.get_held_weapon()
	return null

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
	# Update held weapon position when facing changes
	if weapon and weapon.get_held_weapon():
		var held_weapon: BaseWeapon = weapon.get_held_weapon()
		if held_weapon.has_method("_update_held_position"):
			held_weapon._update_held_position()

func _on_movement_landed() -> void:
	Logger.debug(player_data.player_name + " landed", "BasePlayer")

func _on_movement_jumped() -> void:
	Logger.debug(player_data.player_name + " jumped", "BasePlayer")

## Projectile weapon component signal handlers
func _on_weapon_picked_up(weapon_obj: BaseWeapon) -> void:
	Logger.pickup(player_data.player_name + " picked up " + weapon_obj.weapon_name, "BasePlayer")

func _on_weapon_thrown(weapon_obj: BaseWeapon, throw_velocity: Vector2) -> void:
	Logger.combat(weapon_obj.weapon_name + " thrown by " + player_data.player_name, "BasePlayer")

func _on_weapon_fired(weapon_obj: BaseWeapon) -> void:
	Logger.combat(weapon_obj.weapon_name + " fired by " + player_data.player_name, "BasePlayer")

func _on_nearby_weapons_changed(nearby_weapons: Array[BaseWeapon]) -> void:
	Logger.debug(player_data.player_name + " nearby weapons: " + str(nearby_weapons.size()), "BasePlayer")

## Throwing-centric input signal handlers
func _on_input_movement_changed(movement_input: Vector2) -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement_input, false)  # Jump handled separately

func _on_input_jump_pressed() -> void:
	if movement and current_state == PlayerState.ALIVE:
		movement.set_input(movement.input_vector, true)

func _on_input_fire_pressed() -> void:
	if current_state != PlayerState.ALIVE:
		return
	
	# Projectile system: Fire held weapon, or pick up weapon if unarmed
	if not fire_weapon():
		pickup_weapon()

func _on_input_throw_pressed() -> void:
	if current_state == PlayerState.ALIVE:
		# Projectile system: Throw held weapon as projectile
		throw_weapon()

func _on_input_pickup_pressed() -> void:
	if current_state == PlayerState.ALIVE:
		# Projectile system: Pick up nearby weapon
		pickup_weapon()

## Ragdoll component signal handlers
func _on_ragdoll_entered() -> void:
	current_state = PlayerState.RAGDOLLED
	EventBus.player_ragdolled.emit(player_data.player_id)

func _on_ragdoll_exited() -> void:
	if current_state == PlayerState.RAGDOLLED:
		current_state = PlayerState.ALIVE
		EventBus.player_recovered.emit(player_data.player_id) 
