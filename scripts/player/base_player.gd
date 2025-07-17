class_name BasePlayer
extends CharacterBody2D

## Base player class with movement, health, and ragdoll physics
## Extensible for both human players and AI

# Player states
enum PlayerState {
	ALIVE,
	RAGDOLLED,
	DEAD,
	SPECTATING
}

# Player configuration
@export var max_health: int = 3
@export var move_speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var ragdoll_force_threshold: float = 500.0
@export var ragdoll_recovery_time: float = 2.0
@export var item_hold_offset: Vector2 = Vector2(30, -10)

# Configuration reference
var game_config: GameConfig

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# Removed individual UI components - now using centralized HUD
# @onready var health_bar: ProgressBar = $UI/HealthBar
# @onready var player_label: Label = $UI/PlayerLabel

# Pickup area (created dynamically if not in scene)
var pickup_area: Area2D = null
var pickup_collision: CollisionShape2D = null

# Physics and state
var current_state: PlayerState = PlayerState.ALIVE
var current_health: int
var player_data: PlayerData
var gravity: float = 980.0

# Input handling (can be overridden for AI)
var input_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var use_pressed: bool = false
var facing_direction: int = 1  # 1 for right, -1 for left

# Ragdoll system
var ragdoll_body: RigidBody2D = null
var ragdoll_timer: float = 0.0
var pre_ragdoll_position: Vector2 = Vector2.ZERO

# Spawn position (for external respawn)
var spawn_position: Vector2 = Vector2.ZERO

# Item system
var held_item: Node = null
var can_pickup: bool = true
var nearby_items: Array[BaseItem] = []

signal player_state_changed(new_state: PlayerState)
signal health_changed(new_health: int)
signal item_pickup_attempted(item: Node)

func _ready() -> void:
	# Load game configuration
	game_config = GameConfig.get_instance()
	
	# Initialize default values from config if not overridden
	if move_speed == 300.0:  # Default value, use config
		move_speed = game_config.default_move_speed
	if jump_velocity == -400.0:  # Default value, use config
		jump_velocity = game_config.default_jump_velocity
	if ragdoll_force_threshold == 500.0:  # Default value, use config
		ragdoll_force_threshold = game_config.ragdoll_force_threshold
	if ragdoll_recovery_time == 2.0:  # Default value, use config
		ragdoll_recovery_time = game_config.ragdoll_recovery_time
	if item_hold_offset == Vector2(30, -10):  # Default value, use config
		item_hold_offset = game_config.item_hold_offset
	
	# Initialize player data
	if not player_data:
		player_data = PlayerData.new(0, "Player")
		Logger.warning("BasePlayer created default PlayerData - this should only happen in standalone testing", "BasePlayer")
	else:
		Logger.system("BasePlayer using assigned PlayerData: " + player_data.player_name + " (ID: " + str(player_data.player_id) + ")", "BasePlayer")
	
	# Set collision layers for player
	CollisionLayers.setup_player(self)
	
	# Create pickup area dynamically
	_create_pickup_area()
	
	current_health = max_health
	_update_ui()
	
	# Connect signals
	health_changed.connect(_on_health_changed)
	player_state_changed.connect(_on_state_changed)
	
	Logger.system("BasePlayer initialized: " + player_data.player_name, "BasePlayer")

func _physics_process(delta: float) -> void:
	match current_state:
		PlayerState.ALIVE:
			_handle_alive_physics(delta)
		PlayerState.RAGDOLLED:
			_handle_ragdoll_physics(delta)
		PlayerState.DEAD:
			_handle_dead_physics(delta)
		PlayerState.SPECTATING:
			_handle_spectating_physics(delta)

func _handle_alive_physics(delta: float) -> void:
	# Handle gravity
	if not is_on_floor():
		velocity.y += game_config.default_gravity * delta
	
	# Handle jump
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
		jump_pressed = false
	
	# Handle horizontal movement
	if input_vector.x != 0:
		velocity.x = input_vector.x * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 3)
	
	# Move and check for collisions
	move_and_slide()
	
	# Check for ragdoll conditions (high velocity impacts)
	if velocity.length() > ragdoll_force_threshold:
		_enter_ragdoll_state()

func _handle_ragdoll_physics(delta: float) -> void:
	ragdoll_timer += delta
	
	# Duck Game style ragdoll - the RigidBody2D handles the physics
	# We just track the ragdoll body position and check for recovery
	if ragdoll_body:
		# Sync our position with ragdoll body for consistency
		global_position = ragdoll_body.global_position
	
	# Check for recovery (but not if dead - death ragdolls persist until respawn)
	if current_state != PlayerState.DEAD and ragdoll_timer >= ragdoll_recovery_time:
		_exit_ragdoll_state()

func _handle_dead_physics(_delta: float) -> void:
	# If ragdolled, let the ragdoll body handle physics
	if ragdoll_body:
		# Sync position with ragdoll body
		global_position = ragdoll_body.global_position
		return
	
	# Otherwise, dead players don't move
	velocity = Vector2.ZERO
	move_and_slide()

func _handle_spectating_physics(_delta: float) -> void:
	# Spectating players can move freely (for camera following)
	pass

## Set input for the player (can be called by input controller or AI)
func set_input(movement: Vector2, jump: bool, use: bool) -> void:
	# Don't process input during ragdoll state (input controller should prevent this, but double-check)
	if current_state == PlayerState.RAGDOLLED:
		return
	
	input_vector = movement
	jump_pressed = jump
	use_pressed = use
	
	# Update facing direction based on movement (Duck Game style)
	var old_facing: int = facing_direction
	if movement.x > 0:
		facing_direction = 1  # Right
		sprite.scale.x = abs(sprite.scale.x)  # Face right
	elif movement.x < 0:
		facing_direction = -1  # Left
		sprite.scale.x = -abs(sprite.scale.x)  # Face left
	# If no horizontal movement, keep current facing direction
	
	# Debug facing direction changes and update held item
	if old_facing != facing_direction:
		Logger.debug(player_data.player_name + " facing changed: " + str(old_facing) + " -> " + str(facing_direction), "BasePlayer")
		# Update held item position immediately when facing changes
		if held_item and held_item is BaseItem:
			var item: BaseItem = held_item as BaseItem
			# Safety check: only update if item is actually held
			if item.is_held and item.holder == self and item.has_method("_update_held_position"):
				item._update_held_position()

## Set health (called by minigame)
func set_health(new_health: int) -> void:
	current_health = new_health
	player_data.current_health = new_health
	Logger.player(player_data.player_name, "health set to: " + str(current_health), "BasePlayer")
	
	# Show damage feedback if health decreased
	if current_health < max_health:
		_show_damage_feedback()

## Die (called by minigame)
func die() -> void:
	Logger.player(player_data.player_name, "dying on minigame command", "BasePlayer")
	current_state = PlayerState.DEAD
	player_state_changed.emit(current_state)
	
	# Enter ragdoll state for death (this handles weapon dropping with dramatic velocity)
	_enter_death_ragdoll()

## Enter ragdoll state specifically for death (doesn't auto-recover)
func _enter_death_ragdoll() -> void:
	# Drop held item before entering ragdoll state
	if held_item and held_item is BaseItem:
		var item: BaseItem = held_item as BaseItem
		Logger.item(item.item_name, "dropped by " + player_data.player_name + " due to death", "BasePlayer")
		
		# Create dramatic drop velocity based on current movement
		var drop_velocity: Vector2 = velocity * game_config.item_velocity_inheritance
		drop_velocity.y -= game_config.item_drop_upward_force * 1.5  # Extra upward force
		
		# Add some random horizontal spread for chaos
		drop_velocity.x += randf_range(-100.0, 100.0)
		
		if item.drop(drop_velocity):
			held_item = null
			Logger.debug(player_data.player_name + " death drop successful", "BasePlayer")
		else:
			Logger.warning(player_data.player_name + " death drop failed", "BasePlayer")
	
	# Create death ragdoll effect (don't change state - already DEAD)
	ragdoll_timer = 0.0
	_create_ragdoll_body()
	
	# Make death ragdoll visually distinct (darker/redder)
	if ragdoll_body:
		ragdoll_body.modulate = Color(0.8, 0.3, 0.3, 1.0)  # Reddish tint for death
	
	Logger.player(player_data.player_name, "entered death ragdoll state", "BasePlayer")

## Take damage and update health (DEPRECATED - kept for compatibility)
func take_damage(damage: int, source: Node = null) -> void:
	Logger.warning("DEPRECATED: take_damage called on " + player_data.player_name + " - should use minigame damage system", "BasePlayer")
	if current_state == PlayerState.DEAD:
		return
	
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health)
	
	if current_health <= 0:
		_die()
	else:
		# Flash effect or other damage feedback
		_show_damage_feedback()

## Heal the player (DEPRECATED - kept for compatibility)
func heal(amount: int) -> void:
	Logger.warning("DEPRECATED: heal called on " + player_data.player_name + " - should use minigame healing system", "BasePlayer")
	if current_state == PlayerState.DEAD:
		return
		
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

## Enter ragdoll state
func _enter_ragdoll_state() -> void:
	if current_state == PlayerState.DEAD:
		return
	
	# Drop held item before entering ragdoll state
	if held_item and held_item is BaseItem:
		var item: BaseItem = held_item as BaseItem
		Logger.item(item.item_name, "dropped by " + player_data.player_name + " due to ragdoll", "BasePlayer")
		
		# Create dramatic drop velocity based on current movement
		var drop_velocity: Vector2 = velocity * game_config.item_velocity_inheritance
		drop_velocity.y -= game_config.item_drop_upward_force * 1.5  # Extra upward force for ragdoll drops
		
		# Add some random horizontal spread for chaos
		drop_velocity.x += randf_range(-100.0, 100.0)
		
		if item.drop(drop_velocity):
			held_item = null
			Logger.debug(player_data.player_name + " ragdoll drop successful", "BasePlayer")
		else:
			Logger.warning(player_data.player_name + " ragdoll drop failed", "BasePlayer")
		
	current_state = PlayerState.RAGDOLLED
	ragdoll_timer = 0.0
	player_state_changed.emit(current_state)
	
	# Create simple ragdoll effect
	_create_ragdoll_body()
	Logger.player(player_data.player_name, "entered ragdoll state", "BasePlayer")

## Exit ragdoll state
func _exit_ragdoll_state() -> void:
	if current_state != PlayerState.RAGDOLLED:
		return
		
	current_state = PlayerState.ALIVE
	player_state_changed.emit(current_state)
	
	# Remove ragdoll body
	_remove_ragdoll_body()
	Logger.player(player_data.player_name, "recovered from ragdoll", "BasePlayer")

## Create Duck Game style ragdoll physics body
func _create_ragdoll_body() -> void:
	if ragdoll_body:
		return
	
	# Store position for recovery
	pre_ragdoll_position = global_position
	
	# Create a RigidBody2D with tipping-friendly physics
	ragdoll_body = RigidBody2D.new()
	ragdoll_body.gravity_scale = game_config.ragdoll_gravity_scale
	ragdoll_body.mass = 2.0  # Lighter mass for easier tipping
	ragdoll_body.linear_damp = 3.0  # Moderate damping - not too high so it can still tip
	ragdoll_body.angular_damp = 2.0  # Lower angular damping to allow more rotation
	
	# Disable continuous collision detection - it might be causing bouncing issues
	ragdoll_body.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	ragdoll_body.can_sleep = true  # Allow sleeping to stabilize physics
	
	# Create physics material for reduced friction to help tipping
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.0  # NO bouncing at all
	physics_material.friction = 0.8  # Reduced friction to allow easier sliding/tipping
	ragdoll_body.physics_material_override = physics_material
	
	# Set collision layers for ragdoll
	CollisionLayers.setup_ragdoll(ragdoll_body)
	
	# Store reference to owner player for damage detection
	ragdoll_body.set_meta("owner_player", self)
	
	# Copy collision shape - keep original for system consistency
	var ragdoll_collision = CollisionShape2D.new()
	ragdoll_collision.shape = collision_shape.shape
	# Offset collision shape upward to raise center of mass and encourage tipping
	ragdoll_collision.position.y = -5  # Move collision up 5 pixels for higher center of gravity
	ragdoll_body.add_child(ragdoll_collision)
	
	# Copy sprite appearance - keep original size for consistency
	var ragdoll_sprite = Sprite2D.new()
	var ragdoll_rect = ColorRect.new()
	ragdoll_rect.size = Vector2(20, 40)  # Back to original size
	ragdoll_rect.position = Vector2(-10, -20)  # Centered on ragdoll body
	ragdoll_rect.color = Color(1.0, 0.6, 0.6, 1.0)  # Reddish tint to show ragdoll state
	ragdoll_sprite.add_child(ragdoll_rect)
	ragdoll_body.add_child(ragdoll_sprite)
	
	# Add to scene
	get_parent().add_child(ragdoll_body)
	ragdoll_body.global_position = global_position
	
	# Clamp velocity transfer to prevent excessive bouncing
	var clamped_velocity = velocity
	var max_ragdoll_velocity = 50.0  # Very low initial velocity to test
	if clamped_velocity.length() > max_ragdoll_velocity:
		clamped_velocity = clamped_velocity.normalized() * max_ragdoll_velocity
	
	# Further reduce the initial velocity to prevent amplification
	clamped_velocity *= 0.2  # Cut velocity to 20% of already clamped amount
	
	ragdoll_body.linear_velocity = clamped_velocity
	
	# Apply tipping force at the top of the sprite for realistic physics
	# Wait one frame to ensure ragdoll body is properly in the scene
	await get_tree().process_frame
	
	# Calculate tipping force based on movement and impacts
	var base_tipping_force = Vector2(0, -50)  # Small upward force at top
	
	# Add directional tipping based on player movement
	if input_vector.x != 0:
		base_tipping_force.x += input_vector.x * 30.0  # Horizontal force for directional tip
	
	# Add impact-based tipping if moving fast
	if velocity.length() > 200.0:
		base_tipping_force.x += randf_range(-50.0, 50.0)  # Extra random horizontal force
		base_tipping_force.y -= randf_range(20.0, 40.0)   # Extra upward force for impacts
	
	# Apply the force at the top of the sprite (20 pixels up from center)
	var top_offset = Vector2(0, -20)
	ragdoll_body.apply_impulse(base_tipping_force, top_offset)
	
	Logger.debug("Applied tipping force " + str(base_tipping_force) + " at offset " + str(top_offset), "BasePlayer")
	
	# Disable item interactions during ragdoll
	can_pickup = false
	
	# Hide original body but KEEP physics processing enabled for recovery timer
	visible = false
	# DON'T disable physics processing - we need it for the recovery timer!
	# set_physics_process(false)  # <- This was preventing recovery!
	
	Logger.player(player_data.player_name, "entered Duck Game style ragdoll", "BasePlayer")

## Remove ragdoll body and restore normal physics
func _remove_ragdoll_body() -> void:
	if not ragdoll_body:
		return
	
	# Restore position from ragdoll (but not too much velocity)
	global_position = ragdoll_body.global_position
	velocity = ragdoll_body.linear_velocity * 0.3  # Dampen the velocity on recovery
	
	# Clean up ragdoll body
	ragdoll_body.queue_free()
	ragdoll_body = null
	
	# Ensure held items are visible (in case of bugs)
	if held_item and held_item is BaseItem:
		var item = held_item as BaseItem
		item.visible = true
		Logger.debug("Ensured held item " + item.item_name + " is visible after ragdoll recovery", "BasePlayer")
	
	# Re-enable item interactions
	can_pickup = true
	
	# Reset visual state
	rotation = 0.0
	modulate = Color.WHITE
	visible = true
	set_physics_process(true)
	
	Logger.player(player_data.player_name, "recovered from ragdoll", "BasePlayer")

## Player death (DEPRECATED - use die() instead)
func _die() -> void:
	Logger.warning("DEPRECATED: _die called - using new die() method", "BasePlayer")
	die()

## Respawn the player (called by minigame)
func respawn() -> void:
	Logger.player(player_data.player_name, "respawning at " + str(spawn_position), "BasePlayer")
	
	# Clean up any death ragdoll state first
	_cleanup_ragdoll_state()
	
	# Reset state
	current_state = PlayerState.ALIVE
	
	# Restore health (minigame should have already updated player_data)
	current_health = player_data.current_health
	
	# Reset position
	global_position = spawn_position
	velocity = Vector2.ZERO
	
	# Restore visual state
	visible = true
	modulate = Color.WHITE
	rotation = 0.0
	
	# Update UI - just emit state change, health already handled by minigame
	player_state_changed.emit(current_state)
	
	# Emit respawn event
	EventBus.emit_player_respawned(player_data.player_id)
	
	Logger.player(player_data.player_name, "respawned successfully!", "BasePlayer")

## Set spawn position (called by minigame)
func set_spawn_position(position: Vector2) -> void:
	spawn_position = position
	Logger.system("Set spawn position for " + player_data.player_name + " to " + str(spawn_position), "BasePlayer")

## Clean up ragdoll state variables and body
func _cleanup_ragdoll_state() -> void:
	ragdoll_timer = 0.0
	pre_ragdoll_position = Vector2.ZERO
	
	# Clean up ragdoll body if it exists
	if ragdoll_body:
		ragdoll_body.queue_free()
		ragdoll_body = null
	
	# Re-enable item interactions
	can_pickup = true
	
	# Ensure we're visible and processing (physics should already be enabled)
	visible = true
	set_physics_process(true)

## Update UI elements (now handled by centralized HUD)
func _update_ui() -> void:
	# Individual UI elements removed - health/status now shown in centralized HUD
	# The EventBus signals will notify the HUD of any changes
	pass

## Show damage feedback
func _show_damage_feedback() -> void:
	# TODO: Add visual/audio feedback for taking damage
	Logger.combat(player_data.player_name + " took damage! Health: " + str(current_health), "BasePlayer")

## Attempt to pick up an item (specific item)
func try_pickup_item(item: BaseItem) -> bool:
	if not can_pickup or held_item != null or current_state != PlayerState.ALIVE:
		return false
	
	if item and item.pickup(self):
		held_item = item
		item_pickup_attempted.emit(item)
		# Remove from nearby items if it was there
		if item in nearby_items:
			nearby_items.erase(item)
		return true
	
	return false

## Attempt to pick up the nearest available item
func try_pickup_nearest_item() -> bool:
	Logger.pickup(player_data.player_name + " attempting pickup", "BasePlayer")
	
	if not can_pickup or held_item != null or current_state != PlayerState.ALIVE:
		Logger.pickup("Cannot pickup: can_pickup=" + str(can_pickup) + " held_item=" + str(held_item) + " state=" + str(current_state), "BasePlayer")
		return false
	
	Logger.pickup("Nearby items: " + str(nearby_items.size()), "BasePlayer")
	for i in range(nearby_items.size()):
		var item = nearby_items[i]
		if item:
			Logger.pickup("[" + str(i) + "] " + item.item_name + " at " + str(item.global_position) + " can_pickup=" + str(item.can_be_picked_up) + " is_held=" + str(item.is_held), "BasePlayer")
		else:
			Logger.pickup("[" + str(i) + "] null item (stale reference)", "BasePlayer")
	
	# Find the nearest pickupable item
	var nearest_item: BaseItem = null
	var nearest_distance: float = INF
	
	for item in nearby_items:
		if item and item.can_be_picked_up and not item.is_held:
			var distance = global_position.distance_to(item.global_position)
			Logger.pickup("Distance to " + item.item_name + ": " + str(distance), "BasePlayer")
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_item = item
	
	# Try to pick up the nearest item
	if nearest_item:
		Logger.pickup("Picking up nearest item: " + nearest_item.item_name + " (distance: " + str(nearest_distance) + ")", "BasePlayer")
		return try_pickup_item(nearest_item)
	else:
		Logger.pickup("No pickupable items found", "BasePlayer")
	
	return false

## Drop currently held item
func drop_item() -> void:
	if current_state != PlayerState.ALIVE:
		return
	
	if held_item and held_item is BaseItem:
		var item = held_item as BaseItem
		Logger.item(item.item_name, "being dropped by " + player_data.player_name, "BasePlayer")
		
		var drop_velocity = velocity * game_config.item_velocity_inheritance
		drop_velocity.y -= game_config.item_drop_upward_force
		
		if item.drop(drop_velocity):
			held_item = null
			Logger.debug(player_data.player_name + " held_item set to null", "BasePlayer")
		else:
			Logger.warning(player_data.player_name + " failed to drop " + item.item_name, "BasePlayer")

## Use currently held item
func use_held_item() -> bool:
	if current_state != PlayerState.ALIVE:
		return false
	
	if held_item and held_item is BaseItem:
		var item = held_item as BaseItem
		return item.use_item()
	return false

# Signal handlers
func _on_health_changed(new_health: int) -> void:
	# DEPRECATED: Health changes are now managed by minigame
	Logger.warning("DEPRECATED: _on_health_changed called - health now managed by minigame", "BasePlayer")
	
	# Still update local player data for consistency
	player_data.current_health = new_health
	Logger.debug("PlayerData synced: " + str(player_data.current_health) + "/" + str(player_data.max_health) + " = " + str(player_data.get_health_percentage()) + "%", "BasePlayer")

func _on_state_changed(new_state: PlayerState) -> void:
	# Individual UI removed, but still handle state changes
	Logger.player(player_data.player_name, "state changed to: " + PlayerState.keys()[new_state], "BasePlayer")
	
	match new_state:
		PlayerState.RAGDOLLED:
			EventBus.player_ragdolled.emit(player_data.player_id)
		PlayerState.ALIVE:
			# Check if we were previously ragdolled by looking at the previous state
			if ragdoll_body != null or ragdoll_timer > 0:
				EventBus.player_recovered.emit(player_data.player_id)

# Pickup area signal handlers
func _on_pickup_area_entered(body: Node2D) -> void:
	Logger.pickup(player_data.player_name + " pickup area detected body: " + body.name + " type: " + body.get_class(), "BasePlayer")
	if body is BaseItem:
		var item = body as BaseItem
		Logger.pickup("Found BaseItem: " + item.item_name + " can_pickup=" + str(item.can_be_picked_up) + " is_held=" + str(item.is_held), "BasePlayer")
		if item.can_be_picked_up and not item.is_held and item not in nearby_items:
			nearby_items.append(item)
			Logger.pickup(player_data.player_name + " can now pickup: " + item.item_name + " (total nearby: " + str(nearby_items.size()) + ")", "BasePlayer")
		else:
			Logger.pickup("Cannot pickup " + item.item_name + " - already in list or not available", "BasePlayer")
	else:
		Logger.pickup("Not a BaseItem, ignoring", "BasePlayer")

func _on_pickup_area_exited(body: Node2D) -> void:
	Logger.pickup(player_data.player_name + " pickup area lost body: " + body.name, "BasePlayer")
	if body is BaseItem:
		var item = body as BaseItem
		if item in nearby_items:
			nearby_items.erase(item)
			Logger.pickup(player_data.player_name + " lost pickup range for: " + item.item_name + " (remaining: " + str(nearby_items.size()) + ")", "BasePlayer")
		else:
			Logger.pickup("Item " + item.item_name + " was not in nearby list", "BasePlayer")

## Create pickup area for item detection
func _create_pickup_area() -> void:
	# Create pickup area
	pickup_area = Area2D.new()
	pickup_area.name = "PickupArea"
	add_child(pickup_area)
	
	# Create collision shape for pickup area
	pickup_collision = CollisionShape2D.new()
	var pickup_shape = CircleShape2D.new()
	pickup_shape.radius = game_config.pickup_area_radius
	pickup_collision.shape = pickup_shape
	pickup_area.add_child(pickup_collision)
	
	# Setup collision layers
	CollisionLayers.setup_pickup_area(pickup_area)
	
	# Connect signals
	pickup_area.body_entered.connect(_on_pickup_area_entered)
	pickup_area.body_exited.connect(_on_pickup_area_exited)
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(pickup_area, player_data.player_name + " pickup area")
	Logger.system("Created pickup area for " + player_data.player_name, "BasePlayer") 
