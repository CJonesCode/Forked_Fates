class_name RagdollComponent
extends BaseComponent

## Ragdoll physics and transitions component
## Handles ragdoll state, physics body creation, and recovery

# Ragdoll signals
signal ragdoll_entered()
signal ragdoll_exited()
signal ragdoll_impact(force: Vector2)

# Ragdoll properties
@export var ragdoll_force_threshold: float = 500.0
@export var ragdoll_recovery_time: float = 2.0
@export var ragdoll_gravity_scale: float = 1.0
@export var ragdoll_mass: float = 2.0
@export var ragdoll_linear_damp: float = 3.0
@export var ragdoll_angular_damp: float = 2.0

# Ragdoll state
var is_ragdolled: bool = false
var ragdoll_body: RigidBody2D = null
var ragdoll_timer: float = 0.0
var pre_ragdoll_position: Vector2 = Vector2.ZERO
var auto_recovery_enabled: bool = true

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		ragdoll_force_threshold = player.game_config.ragdoll_force_threshold
		ragdoll_recovery_time = player.game_config.ragdoll_recovery_time
		ragdoll_gravity_scale = player.game_config.ragdoll_gravity_scale

func _physics_process(delta: float) -> void:
	if not is_ragdolled:
		_check_for_ragdoll_conditions()
	else:
		_handle_ragdoll_physics(delta)

## Check if conditions are met for entering ragdoll state
func _check_for_ragdoll_conditions() -> void:
	if player.velocity.length() > ragdoll_force_threshold:
		enter_ragdoll_state()

## Handle ragdoll physics updates
func _handle_ragdoll_physics(delta: float) -> void:
	ragdoll_timer += delta
	
	# Sync position with ragdoll body
	if ragdoll_body:
		player.global_position = ragdoll_body.global_position
	
	# Check for auto recovery
	if auto_recovery_enabled and ragdoll_timer >= ragdoll_recovery_time:
		exit_ragdoll_state()

## Enter ragdoll state
func enter_ragdoll_state(disable_auto_recovery: bool = false) -> void:
	if is_ragdolled:
		return
	
	is_ragdolled = true
	ragdoll_timer = 0.0
	auto_recovery_enabled = not disable_auto_recovery
	
	# Store position for recovery
	pre_ragdoll_position = player.global_position
	
	# Disable player input and pickup
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(false)
	
	var inventory_component: InventoryComponent = player.get_component(InventoryComponent)
	if inventory_component:
		inventory_component.set_pickup_enabled(false)
		# Force drop held item with dramatic velocity
		var drop_velocity: Vector2 = player.velocity * 0.8
		drop_velocity.y -= 150.0  # Extra upward force for ragdoll drops
		drop_velocity.x += randf_range(-100.0, 100.0)  # Random horizontal spread
		inventory_component.force_drop_item(drop_velocity)
	
	# Create ragdoll physics body (deferred to avoid physics conflicts)
	call_deferred("_create_ragdoll_body")
	
	# Hide original player body
	player.visible = false
	
	ragdoll_entered.emit()
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "entered ragdoll state", "RagdollComponent")

## Exit ragdoll state
func exit_ragdoll_state() -> void:
	if not is_ragdolled:
		return
	
	is_ragdolled = false
	
	# Restore position from ragdoll (but dampen velocity)
	if ragdoll_body:
		player.global_position = ragdoll_body.global_position
		player.velocity = ragdoll_body.linear_velocity * 0.3  # Dampen velocity on recovery
	
	# Re-enable player systems
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(true)
	
	var inventory_component: InventoryComponent = player.get_component(InventoryComponent)
	if inventory_component:
		inventory_component.set_pickup_enabled(true)
	
	# Clean up ragdoll body
	_remove_ragdoll_body()
	
	# Restore visual state
	player.visible = true
	player.rotation = 0.0
	player.modulate = Color.WHITE
	
	ragdoll_exited.emit()
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "recovered from ragdoll", "RagdollComponent")

## Create ragdoll physics body
func _create_ragdoll_body() -> void:
	if ragdoll_body:
		return
	
	# Create a RigidBody2D with tipping-friendly physics
	ragdoll_body = RigidBody2D.new()
	ragdoll_body.gravity_scale = ragdoll_gravity_scale
	ragdoll_body.mass = ragdoll_mass
	ragdoll_body.linear_damp = ragdoll_linear_damp
	ragdoll_body.angular_damp = ragdoll_angular_damp
	
	# Disable continuous collision detection to prevent bouncing
	ragdoll_body.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	ragdoll_body.can_sleep = true  # Allow sleeping to stabilize physics
	
	# Create physics material for reduced friction
	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.bounce = 0.0  # No bouncing
	physics_material.friction = 0.8  # Reduced friction for easier sliding/tipping
	ragdoll_body.physics_material_override = physics_material
	
	# Set collision layers
	CollisionLayers.setup_ragdoll(ragdoll_body)
	
	# Store reference to owner player for damage detection
	ragdoll_body.set_meta("owner_player", player)
	
	# Copy collision shape from player
	var ragdoll_collision: CollisionShape2D = CollisionShape2D.new()
	ragdoll_collision.shape = player.collision_shape.shape
	# Offset collision shape upward to raise center of mass and encourage tipping
	ragdoll_collision.position.y = -5  # Move collision up for higher center of gravity
	ragdoll_body.add_child(ragdoll_collision)
	
	# Copy sprite appearance
	var ragdoll_sprite: Sprite2D = Sprite2D.new()
	var ragdoll_rect: ColorRect = ColorRect.new()
	ragdoll_rect.size = Vector2(20, 40)
	ragdoll_rect.position = Vector2(-10, -20)  # Centered on ragdoll body
	ragdoll_rect.color = Color(1.0, 0.6, 0.6, 1.0)  # Reddish tint for ragdoll state
	ragdoll_sprite.add_child(ragdoll_rect)
	ragdoll_body.add_child(ragdoll_sprite)
	
	# Add to scene
	player.get_parent().add_child(ragdoll_body)
	ragdoll_body.global_position = player.global_position
	
	# Apply initial velocity with clamping to prevent excessive bouncing
	var clamped_velocity: Vector2 = player.velocity
	var max_ragdoll_velocity: float = 300.0
	if clamped_velocity.length() > max_ragdoll_velocity:
		clamped_velocity = clamped_velocity.normalized() * max_ragdoll_velocity
	
	# Reduce initial velocity to prevent amplification
	clamped_velocity *= 0.5
	ragdoll_body.linear_velocity = clamped_velocity
	
	# Wait one frame to ensure ragdoll body is properly in the scene
	await player.get_tree().process_frame
	
	# Apply tipping force for realistic physics
	_apply_tipping_force()
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.debug("Created ragdoll body for " + player_name, "RagdollComponent")

## Apply tipping force to ragdoll body
func _apply_tipping_force() -> void:
	if not ragdoll_body:
		return
	
	# Calculate tipping force based on movement and impacts
	var base_tipping_force: Vector2 = Vector2(0, -50)  # Small upward force at top
	
	# Add directional tipping based on player movement
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	if movement_component and movement_component.input_vector.x != 0:
		base_tipping_force.x += movement_component.input_vector.x * 30.0
	
	# Add impact-based tipping if moving fast
	if player.velocity.length() > 200.0:
		base_tipping_force.x += randf_range(-50.0, 50.0)  # Extra random horizontal force
		base_tipping_force.y -= randf_range(20.0, 40.0)   # Extra upward force for impacts
	
	# Apply the force at the top of the sprite (20 pixels up from center)
	var top_offset: Vector2 = Vector2(0, -20)
	ragdoll_body.apply_impulse(base_tipping_force, top_offset)
	
	ragdoll_impact.emit(base_tipping_force)
	Logger.debug("Applied tipping force " + str(base_tipping_force) + " at offset " + str(top_offset), "RagdollComponent")

## Remove ragdoll physics body
func _remove_ragdoll_body() -> void:
	if not ragdoll_body:
		return
	
	ragdoll_body.queue_free()
	ragdoll_body = null

## Force enter ragdoll for death (doesn't auto-recover)
func enter_death_ragdoll() -> void:
	enter_ragdoll_state(true)  # Disable auto recovery
	
	# Make death ragdoll visually distinct
	if ragdoll_body:
		ragdoll_body.modulate = Color(0.8, 0.3, 0.3, 1.0)  # Reddish tint for death
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "entered death ragdoll state", "RagdollComponent")

## Cleanup ragdoll state completely
func cleanup_ragdoll_state() -> void:
	ragdoll_timer = 0.0
	pre_ragdoll_position = Vector2.ZERO
	auto_recovery_enabled = true
	
	# Clean up ragdoll body if it exists - proper cleanup to prevent RID leaks
	if ragdoll_body:
		# Remove meta reference to prevent circular references
		ragdoll_body.remove_meta("owner_player")
		
		# Disable physics to prevent further processing
		ragdoll_body.freeze = true
		ragdoll_body.set_gravity_scale(0)
		
		# Remove from parent to break scene tree references
		if ragdoll_body.get_parent():
			ragdoll_body.get_parent().remove_child(ragdoll_body)
		
		# Free the ragdoll body immediately
		ragdoll_body.queue_free()
		ragdoll_body = null
	
	# Re-enable systems
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(true)
	
	var inventory_component: InventoryComponent = player.get_component(InventoryComponent)
	if inventory_component:
		inventory_component.set_pickup_enabled(true)
	
	# Ensure player is visible
	player.visible = true
	
	is_ragdolled = false

## Check if currently in ragdoll state
func is_in_ragdoll_state() -> bool:
	return is_ragdolled

## Set ragdoll force threshold
func set_force_threshold(threshold: float) -> void:
	ragdoll_force_threshold = threshold

## Set ragdoll recovery time
func set_recovery_time(time: float) -> void:
	ragdoll_recovery_time = time

## Get ragdoll body for external manipulation
func get_ragdoll_body() -> RigidBody2D:
	return ragdoll_body 
