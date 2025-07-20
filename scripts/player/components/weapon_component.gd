class_name WeaponComponent
extends BaseComponent

## Throwing-centric weapon management component  
## Handles weapon pickup, firing, throwing, and nearby weapon detection
## Pure projectile weapon system - BaseWeapon only

# Weapon management signals - throwing-centric style
signal weapon_picked_up(weapon: BaseWeapon)
signal weapon_thrown(weapon: BaseWeapon, throw_velocity: Vector2)
signal weapon_fired(weapon: BaseWeapon)
signal nearby_weapons_changed(nearby_weapons: Array[BaseWeapon])

# Weapon properties
@export var weapon_hold_offset: Vector2 = Vector2(30, -10)
@export var pickup_area_radius: float = 50.0
@export var default_throw_force: float = 400.0

# Weapon state
var held_weapon: BaseWeapon = null
var can_pickup: bool = true
var nearby_weapons: Array[BaseWeapon] = []

# Pickup area
var pickup_area: Area2D = null
var pickup_collision: CollisionShape2D = null

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		weapon_hold_offset = player.game_config.item_hold_offset  # Reuse existing config
		pickup_area_radius = player.game_config.pickup_area_radius
	
	# Connect to EventBus for weapon position requests
	if not EventBus.weapon_position_requested.is_connected(_on_weapon_position_requested):
		EventBus.weapon_position_requested.connect(_on_weapon_position_requested)
	if not EventBus.weapon_facing_requested.is_connected(_on_weapon_facing_requested):
		EventBus.weapon_facing_requested.connect(_on_weapon_facing_requested)
	
	# Create pickup area (async operation)
	_create_pickup_area()

func _cleanup_component() -> void:
	# Disconnect EventBus signals
	if EventBus.weapon_position_requested.is_connected(_on_weapon_position_requested):
		EventBus.weapon_position_requested.disconnect(_on_weapon_position_requested)
	if EventBus.weapon_facing_requested.is_connected(_on_weapon_facing_requested):
		EventBus.weapon_facing_requested.disconnect(_on_weapon_facing_requested)
	
	# Clean up pickup area properly to prevent RID leaks
	if pickup_area:
		# Disconnect signals to prevent callbacks during cleanup
		if pickup_area.body_entered.is_connected(_on_pickup_area_entered):
			pickup_area.body_entered.disconnect(_on_pickup_area_entered)
		if pickup_area.body_exited.is_connected(_on_pickup_area_exited):
			pickup_area.body_exited.disconnect(_on_pickup_area_exited)
		
		# Remove collision shape child first (deferred to avoid tree conflicts)
		if pickup_collision:
			pickup_area.remove_child.call_deferred(pickup_collision)
			pickup_collision.queue_free()
			pickup_collision = null
		
		# Remove from parent and free (deferred to avoid tree conflicts)
		if pickup_area.get_parent():
			pickup_area.get_parent().remove_child.call_deferred(pickup_area)
		pickup_area.queue_free()
		pickup_area = null
	
	# Clear nearby weapons array
	nearby_weapons.clear()

## Create pickup area for weapon detection
func _create_pickup_area() -> void:
	# Create pickup area
	pickup_area = Area2D.new()
	pickup_area.name = "WeaponPickupArea"
	
	# Wait for player to be ready before adding pickup area
	await player.get_tree().process_frame
	
	player.add_child(pickup_area)
	
	# Create collision shape for pickup area
	pickup_collision = CollisionShape2D.new()
	var pickup_shape = CircleShape2D.new()
	pickup_shape.radius = pickup_area_radius
	pickup_collision.shape = pickup_shape
	pickup_area.add_child(pickup_collision)
	
	# Setup collision layers - crucial for detection
	CollisionLayers.setup_pickup_area(pickup_area)
	
	# Wait another frame to ensure collision setup is complete
	await player.get_tree().process_frame
	
	# Connect signals
	pickup_area.body_entered.connect(_on_pickup_area_entered)
	pickup_area.body_exited.connect(_on_pickup_area_exited)
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.system("Created weapon pickup area for " + player_name + " with radius " + str(pickup_area_radius), "WeaponComponent")
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(pickup_area, player_name + " weapon pickup area")

## Fire currently held weapon (projectile system core action)
func fire_held_weapon() -> bool:
	if held_weapon == null:
		return false
	
	var weapon: BaseWeapon = held_weapon
	var fired_successfully: bool = weapon.fire_weapon()
	
	if fired_successfully:
		weapon_fired.emit(weapon)
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.combat(weapon.item_name + " fired by " + player_name, "WeaponComponent")
	
	return fired_successfully

## Throw currently held weapon (momentum-based force)
func throw_held_weapon(force: float = 0.0) -> bool:
	if held_weapon == null:
		return false
	
	var weapon: BaseWeapon = held_weapon
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	
	# Use provided force (calculated from momentum) or fallback to default
	var throw_force: float = force if force > 0.0 else default_throw_force
	
	# Calculate throw direction based on player movement and facing
	var throw_direction: Vector2 = _calculate_throw_direction()
	
	Logger.combat(weapon.item_name + " being thrown by " + player_name + " with force " + str(throw_force), "WeaponComponent")
	
	if weapon.throw_weapon(throw_direction, throw_force, player.player_data.player_id):
		held_weapon = null
		weapon_thrown.emit(weapon, throw_direction * throw_force)
		Logger.combat(player_name + " threw " + weapon.item_name, "WeaponComponent")
		return true
	else:
		Logger.warning(player_name + " failed to throw " + weapon.item_name, "WeaponComponent")
		return false

## Attempt to pick up the nearest available weapon (projectile system core action)
func pickup_nearest_weapon() -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " attempting weapon pickup", "WeaponComponent")
	
	if not can_pickup or held_weapon != null:
		Logger.pickup("Cannot pickup: can_pickup=" + str(can_pickup) + " held_weapon=" + str(held_weapon != null), "WeaponComponent")
		return false
	
	# Find the nearest pickupable weapon
	var nearest_weapon: BaseWeapon = null
	var nearest_distance: float = INF
	
	for weapon in nearby_weapons:
		if weapon and weapon.can_be_picked_up and not weapon.is_held:
			var distance: float = player.global_position.distance_to(weapon.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_weapon = weapon
	
	# Try to pick up the nearest weapon
	if nearest_weapon:
		Logger.pickup("Picking up nearest weapon: " + nearest_weapon.item_name + " (distance: " + str(nearest_distance) + ")", "WeaponComponent")
		return try_pickup_weapon(nearest_weapon)
	else:
		Logger.pickup("No pickupable weapons found", "WeaponComponent")
	
	return false

## Attempt to pick up a specific weapon
func try_pickup_weapon(weapon: BaseWeapon) -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " attempting to pickup " + weapon.item_name, "WeaponComponent")
	
	if not can_pickup or held_weapon != null:
		Logger.pickup("Pickup failed - cannot pickup or already holding weapon", "WeaponComponent")
		return false
	
	if weapon and weapon.pickup_by_id(player.player_data.player_id):
		held_weapon = weapon
		weapon_picked_up.emit(weapon)
		
		# Remove from nearby weapons if it was there
		if weapon in nearby_weapons:
			nearby_weapons.erase(weapon)
			nearby_weapons_changed.emit(nearby_weapons)
		
		Logger.pickup(player_name + " picked up " + weapon.item_name, "WeaponComponent")
		return true
	else:
		Logger.pickup("weapon.pickup_by_id() failed for " + (weapon.item_name if weapon else "null weapon"), "WeaponComponent")
	
	return false

## Calculate throw direction based on player state (physics-based projectile mechanics)
func _calculate_throw_direction() -> Vector2:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	if not movement_component:
		return Vector2.RIGHT  # Default throw direction
	
	var facing_direction: int = movement_component.facing_direction
	var base_direction: Vector2 = Vector2(facing_direction, 0)
	
	# Modify throw direction based on player movement for dynamic throws
	var current_movement: Vector2 = movement_component.input_vector
	if current_movement.length() > 0.1:
		# Blend facing direction with movement for more dynamic throws
		var movement_influence: float = 0.3
		base_direction = base_direction.lerp(current_movement.normalized(), movement_influence)
	
	# Add slight upward component for natural arc (physics-based style)
	base_direction.y -= 0.2
	
	return base_direction.normalized()

## Get the position where held weapons should be positioned
func get_weapon_hold_position() -> Vector2:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	var offset: Vector2 = weapon_hold_offset
	offset.x *= facing_direction  # Flip based on facing direction
	
	var world_pos = player.global_position + offset
	Logger.debug("get_weapon_hold_position: player_pos=" + str(player.global_position) + " offset=" + str(offset) + " world_pos=" + str(world_pos), "WeaponComponent")
	return world_pos

## Check if player can pick up weapons
func can_pickup_weapons() -> bool:
	return can_pickup and held_weapon == null

## Set pickup ability
func set_pickup_enabled(enabled: bool) -> void:
	can_pickup = enabled

## Get currently held weapon
func get_held_weapon() -> BaseWeapon:
	return held_weapon

## Get array of nearby weapons
func get_nearby_weapons() -> Array[BaseWeapon]:
	return nearby_weapons.duplicate()

## Force throw held weapon (for ragdoll/death states) - physics-based style
func force_throw_weapon(impulse_velocity: Vector2 = Vector2.ZERO) -> void:
	if held_weapon == null:
		return
	
	var weapon: BaseWeapon = held_weapon
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.combat(weapon.item_name + " force thrown by " + player_name, "WeaponComponent")
	
	# Calculate throw direction from impulse
	var throw_direction: Vector2 = impulse_velocity.normalized() if impulse_velocity.length() > 0.1 else Vector2.RIGHT
	var throw_force: float = impulse_velocity.length() if impulse_velocity.length() > 100.0 else default_throw_force
	
	if weapon.throw_weapon(throw_direction, throw_force, player.player_data.player_id):
		held_weapon = null
		weapon_thrown.emit(weapon, impulse_velocity)

# Signal handlers for pickup area
func _on_pickup_area_entered(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " weapon pickup area detected body: " + body.name + " (type: " + body.get_class() + ")", "WeaponComponent")
	
	if body is BaseWeapon:
		var weapon: BaseWeapon = body as BaseWeapon
		Logger.pickup(player_name + " detected weapon: " + weapon.item_name + " (can_pickup: " + str(weapon.can_be_picked_up) + ", is_held: " + str(weapon.is_held) + ")", "WeaponComponent")
		
		if weapon.can_be_picked_up and not weapon.is_held and weapon not in nearby_weapons:
			nearby_weapons.append(weapon)
			nearby_weapons_changed.emit(nearby_weapons)
			Logger.pickup(player_name + " can now pickup: " + weapon.item_name + " (total nearby: " + str(nearby_weapons.size()) + ")", "WeaponComponent")
		else:
			Logger.pickup(player_name + " cannot pickup " + weapon.item_name + " - already in nearby list or not available", "WeaponComponent")
	else:
		Logger.pickup(player_name + " detected non-weapon body: " + body.name + " (projectile weapons only)", "WeaponComponent")

func _on_pickup_area_exited(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " weapon pickup area lost body: " + body.name + " (type: " + body.get_class() + ")", "WeaponComponent")
	
	if body is BaseWeapon:
		var weapon: BaseWeapon = body as BaseWeapon
		if weapon in nearby_weapons:
			nearby_weapons.erase(weapon)
			nearby_weapons_changed.emit(nearby_weapons)
			Logger.pickup(player_name + " lost pickup range for: " + weapon.item_name + " (total nearby: " + str(nearby_weapons.size()) + ")", "WeaponComponent")
		else:
			Logger.pickup(player_name + " lost " + weapon.item_name + " but it wasn't in nearby list", "WeaponComponent")

## Event handler for weapon position requests from BaseWeapon
func _on_weapon_position_requested(weapon_id: String, holder_id: int) -> void:
	# Only respond if this request is for our player and we have a held weapon
	if not player.player_data or player.player_data.player_id != holder_id:
		return
	
	if held_weapon and held_weapon.item_name == weapon_id:
		var position: Vector2 = get_weapon_hold_position()
		var rotation_angle: float = 0.0  # Base rotation, facing will be applied separately
		EventBus.weapon_position_provided.emit(weapon_id, position, rotation_angle)

## Event handler for weapon facing requests from BaseWeapon
func _on_weapon_facing_requested(weapon_id: String, holder_id: int) -> void:
	# Only respond if this request is for our player and we have a held weapon
	if not player.player_data or player.player_data.player_id != holder_id:
		return
	
	if held_weapon and held_weapon.item_name == weapon_id:
		var movement_component: MovementComponent = player.get_component(MovementComponent)
		var facing_direction: int = movement_component.facing_direction if movement_component else 1
		EventBus.weapon_facing_provided.emit(weapon_id, facing_direction) 