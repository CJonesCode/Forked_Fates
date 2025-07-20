class_name ItemComponent
extends BaseComponent

## Universal held object management component  
## Handles pickup, firing, using, throwing, and nearby object detection
## Works with all BaseItem types: weapons, consumables, tools, etc.

# Item management signals - universal held object system
signal item_picked_up(item: BaseItem)
signal item_thrown(item: BaseItem, throw_velocity: Vector2)
signal item_fired(item: BaseItem)  # For weapons
signal item_used(item: BaseItem)   # For consumables/tools
signal nearby_items_changed(nearby_items: Array[BaseItem])

# Item properties
@export var item_hold_offset: Vector2 = Vector2(30, -10)
@export var pickup_area_radius: float = 50.0
@export var default_throw_force: float = 400.0

# Item state
var held_item: BaseItem = null
var can_pickup: bool = true
var nearby_items: Array[BaseItem] = []

# Pickup area
var pickup_area: Area2D = null
var pickup_collision: CollisionShape2D = null

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		item_hold_offset = player.game_config.item_hold_offset
		pickup_area_radius = player.game_config.pickup_area_radius
	
	# Connect to EventBus for weapon position requests
	if not EventBus.weapon_position_requested.is_connected(_on_weapon_position_requested):
		EventBus.weapon_position_requested.connect(_on_weapon_position_requested)
	if not EventBus.weapon_facing_requested.is_connected(_on_weapon_facing_requested):
		EventBus.weapon_facing_requested.connect(_on_weapon_facing_requested)
	
	# Create pickup area (async operation)
	_create_pickup_area()

func _cleanup_component() -> void:
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
	
	# Clear nearby items array
	nearby_items.clear()

## Create pickup area for item detection
func _create_pickup_area() -> void:
	# Create pickup area
	pickup_area = Area2D.new()
	pickup_area.name = "ItemPickupArea"
	
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
	Logger.system("Created item pickup area for " + player_name + " with radius " + str(pickup_area_radius), "ItemComponent")
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(pickup_area, player_name + " item pickup area")

## Fire currently held weapon (if held item is a weapon)
func fire_held_item() -> bool:
	if held_item == null:
		return false
	
	# Check if held item is a weapon
	var weapon: BaseWeapon = held_item as BaseWeapon
	if weapon:
		var fired_successfully: bool = weapon.fire_weapon()
		
		if fired_successfully:
			item_fired.emit(weapon)
			var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
			Logger.combat(weapon.item_name + " fired by " + player_name, "ItemComponent")
		
		return fired_successfully
	
	return false

## Use currently held item (consumables, tools, etc.)
func use_held_item() -> bool:
	if held_item == null:
		return false
	
	var item: BaseItem = held_item
	var used_successfully: bool = item.use_item()
	
	if used_successfully:
		item_used.emit(item)
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.item(item.item_name, "used by " + player_name, "ItemComponent")
	
	return used_successfully

## Throw currently held item (momentum-based force)
func throw_held_item(force: float = 0.0) -> bool:
	if held_item == null:
		return false
	
	var item: BaseItem = held_item
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	
	# Use provided force (calculated from momentum) or fallback to default
	var throw_force: float = force if force > 0.0 else default_throw_force
	
	# Calculate throw direction based on player movement and facing
	var throw_direction: Vector2 = _calculate_throw_direction()
	
	Logger.combat(item.item_name + " being thrown by " + player_name + " with force " + str(throw_force), "ItemComponent")
	
	# For weapons, use throw_weapon method; for other items, use drop method with force
	var thrown_successfully: bool = false
	var weapon: BaseWeapon = item as BaseWeapon
	if weapon:
		thrown_successfully = weapon.throw_weapon(throw_direction, throw_force, player.player_data.player_id)
	else:
		# For non-weapons, use drop with velocity
		var throw_velocity: Vector2 = throw_direction * throw_force
		thrown_successfully = item.drop(throw_velocity)
	
	if thrown_successfully:
		held_item = null
		item_thrown.emit(item, throw_direction * throw_force)
		Logger.combat(player_name + " threw " + item.item_name, "ItemComponent")
		return true
	else:
		Logger.warning(player_name + " failed to throw " + item.item_name, "ItemComponent")
		return false

## Attempt to pick up the nearest available item
func pickup_nearest_item() -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " attempting item pickup", "ItemComponent")
	
	if not can_pickup or held_item != null:
		Logger.pickup("Cannot pickup: can_pickup=" + str(can_pickup) + " held_item=" + str(held_item != null), "ItemComponent")
		return false
	
	# Find the nearest pickupable item
	var nearest_item: BaseItem = null
	var nearest_distance: float = INF
	
	for item in nearby_items:
		if item and item.can_be_picked_up and not item.is_held:
			var distance: float = player.global_position.distance_to(item.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_item = item
	
	# Try to pick up the nearest item
	if nearest_item:
		Logger.pickup("Picking up nearest item: " + nearest_item.item_name + " (distance: " + str(nearest_distance) + ")", "ItemComponent")
		return try_pickup_item(nearest_item)
	else:
		Logger.pickup("No pickupable items found", "ItemComponent")
	
	return false

## Attempt to pick up a specific item
func try_pickup_item(item: BaseItem) -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " attempting to pickup " + item.item_name, "ItemComponent")
	
	if not can_pickup or held_item != null:
		Logger.pickup("Pickup failed - cannot pickup or already holding item", "ItemComponent")
		return false
	
	# Use ID-based pickup for weapons, traditional pickup for other items
	var pickup_successful: bool = false
	var weapon: BaseWeapon = item as BaseWeapon
	if weapon:
		pickup_successful = weapon.pickup_by_id(player.player_data.player_id)
	else:
		pickup_successful = item.pickup(player)
	
	if pickup_successful:
		held_item = item
		item_picked_up.emit(item)
		
		# Remove from nearby items if it was there
		if item in nearby_items:
			nearby_items.erase(item)
			nearby_items_changed.emit(nearby_items)
		
		Logger.pickup(player_name + " picked up " + item.item_name, "ItemComponent")
		return true
	else:
		Logger.pickup("pickup failed for " + (item.item_name if item else "null item"), "ItemComponent")
	
	return false

## Calculate throw direction based on player state (physics-based mechanics)
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

## Get the position where held items should be positioned
func get_item_hold_position() -> Vector2:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	var offset: Vector2 = item_hold_offset
	offset.x *= facing_direction  # Flip based on facing direction
	
	var world_pos = player.global_position + offset
	return world_pos

## Check if player can pick up items
func can_pickup_items() -> bool:
	return can_pickup and held_item == null

## Set pickup ability
func set_pickup_enabled(enabled: bool) -> void:
	can_pickup = enabled

## Get currently held item
func get_held_item() -> BaseItem:
	return held_item

## Get currently held weapon (convenience method for weapon-specific code)
func get_held_weapon() -> BaseWeapon:
	return held_item as BaseWeapon

## Get array of nearby items
func get_nearby_items() -> Array[BaseItem]:
	return nearby_items.duplicate()

## Force throw held item (for ragdoll/death states)
func force_throw_item(impulse_velocity: Vector2 = Vector2.ZERO) -> void:
	if held_item == null:
		return
	
	var item: BaseItem = held_item
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.combat(item.item_name + " force thrown by " + player_name, "ItemComponent")
	
	# Calculate throw direction from impulse
	var throw_direction: Vector2 = impulse_velocity.normalized() if impulse_velocity.length() > 0.1 else Vector2.RIGHT
	var throw_force: float = impulse_velocity.length() if impulse_velocity.length() > 100.0 else default_throw_force
	
	# Use appropriate throwing method based on item type
	var thrown_successfully: bool = false
	var weapon: BaseWeapon = item as BaseWeapon
	if weapon:
		thrown_successfully = weapon.throw_weapon(throw_direction, throw_force, player.player_data.player_id)
	else:
		thrown_successfully = item.drop(impulse_velocity)
	
	if thrown_successfully:
		held_item = null
		item_thrown.emit(item, impulse_velocity)

# Signal handlers for pickup area
func _on_pickup_area_entered(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " item pickup area detected body: " + body.name + " (type: " + body.get_class() + ")", "ItemComponent")
	
	if body is BaseItem:
		var item: BaseItem = body as BaseItem
		Logger.pickup(player_name + " detected item: " + item.item_name + " (can_pickup: " + str(item.can_be_picked_up) + ", is_held: " + str(item.is_held) + ")", "ItemComponent")
		
		if item.can_be_picked_up and not item.is_held and item not in nearby_items:
			nearby_items.append(item)
			nearby_items_changed.emit(nearby_items)
			Logger.pickup(player_name + " can now pickup: " + item.item_name + " (total nearby: " + str(nearby_items.size()) + ")", "ItemComponent")
		else:
			Logger.pickup(player_name + " cannot pickup " + item.item_name + " - already in nearby list or not available", "ItemComponent")
	else:
		Logger.pickup(player_name + " detected non-item body: " + body.name + " (universal item system)", "ItemComponent")

func _on_pickup_area_exited(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " item pickup area lost body: " + body.name + " (type: " + body.get_class() + ")", "ItemComponent")
	
	if body is BaseItem:
		var item: BaseItem = body as BaseItem
		if item in nearby_items:
			nearby_items.erase(item)
			nearby_items_changed.emit(nearby_items)
			Logger.pickup(player_name + " lost pickup range for: " + item.item_name + " (total nearby: " + str(nearby_items.size()) + ")", "ItemComponent")
		else:
			Logger.pickup(player_name + " lost " + item.item_name + " but it wasn't in nearby list", "ItemComponent")

## Event handler for weapon position requests from BaseWeapon (legacy compatibility)
func _on_weapon_position_requested(weapon_id: String, holder_id: int) -> void:
	# Only respond if this request is for our player and we have a held weapon
	if not player.player_data or player.player_data.player_id != holder_id:
		return
	
	# Check if held item is the requested weapon
	var weapon: BaseWeapon = held_item as BaseWeapon
	if weapon and weapon.item_name == weapon_id:
		var position: Vector2 = get_item_hold_position()
		var rotation_angle: float = 0.0  # Base rotation, facing will be applied separately
		EventBus.weapon_position_provided.emit(weapon_id, position, rotation_angle)

## Event handler for weapon facing requests from BaseWeapon (legacy compatibility)
func _on_weapon_facing_requested(weapon_id: String, holder_id: int) -> void:
	# Only respond if this request is for our player and we have a held weapon
	if not player.player_data or player.player_data.player_id != holder_id:
		return
	
	# Check if held item is the requested weapon
	var weapon: BaseWeapon = held_item as BaseWeapon
	if weapon and weapon.item_name == weapon_id:
		var movement_component: MovementComponent = player.get_component(MovementComponent)
		var facing_direction: int = movement_component.facing_direction if movement_component else 1
		EventBus.weapon_facing_provided.emit(weapon_id, facing_direction) 