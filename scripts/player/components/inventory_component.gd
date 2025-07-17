class_name InventoryComponent
extends BaseComponent

## Inventory and item management component
## Handles item pickup, drop, use, and nearby item detection

# Item management signals
signal item_picked_up(item: BaseItem)
signal item_dropped(item: BaseItem)
signal item_used(item: BaseItem)
signal nearby_items_changed(nearby_items: Array[BaseItem])

# Item properties
@export var item_hold_offset: Vector2 = Vector2(30, -10)
@export var pickup_area_radius: float = 50.0

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
	pickup_area.name = "PickupArea"
	
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
	Logger.system("Created pickup area for " + player_name + " with radius " + str(pickup_area_radius), "InventoryComponent")
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(pickup_area, player_name + " pickup area")

## Attempt to pick up a specific item
func try_pickup_item(item: BaseItem) -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup("DEBUG: " + player_name + " attempting to pickup " + item.item_name, "InventoryComponent")
	Logger.pickup("DEBUG: can_pickup=" + str(can_pickup) + " held_item=" + str(held_item != null), "InventoryComponent")
	
	if not can_pickup or held_item != null:
		Logger.pickup("DEBUG: Pickup failed - cannot pickup or already holding item", "InventoryComponent")
		return false
	
	Logger.pickup("DEBUG: Calling item.pickup() for " + item.item_name, "InventoryComponent")
	if item and item.pickup(player):
		Logger.pickup("DEBUG: item.pickup() succeeded", "InventoryComponent")
		held_item = item
		item_picked_up.emit(item)
		
		# Remove from nearby items if it was there
		if item in nearby_items:
			nearby_items.erase(item)
			nearby_items_changed.emit(nearby_items)
		
		Logger.pickup(player_name + " picked up " + item.item_name, "InventoryComponent")
		Logger.pickup("DEBUG: held_item now = " + str(held_item), "InventoryComponent")
		return true
	else:
		Logger.pickup("DEBUG: item.pickup() failed for " + (item.item_name if item else "null item"), "InventoryComponent")
	
	return false

## Attempt to pick up the nearest available item
func try_pickup_nearest_item() -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " attempting pickup", "InventoryComponent")
	
	if not can_pickup or held_item != null:
		Logger.pickup("Cannot pickup: can_pickup=" + str(can_pickup) + " held_item=" + str(held_item != null), "InventoryComponent")
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
		Logger.pickup("Picking up nearest item: " + nearest_item.item_name + " (distance: " + str(nearest_distance) + ")", "InventoryComponent")
		return try_pickup_item(nearest_item)
	else:
		Logger.pickup("No pickupable items found", "InventoryComponent")
	
	return false

## Drop currently held item
func drop_item() -> bool:
	if held_item == null:
		return false
	
	var item: BaseItem = held_item
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.item(item.item_name, "being dropped by " + player_name, "InventoryComponent")
	
	# Calculate drop velocity based on player movement
	var drop_velocity: Vector2 = player.velocity * 0.5  # Inherit some player velocity
	drop_velocity.y -= 100.0  # Add upward force
	
	if item.drop(drop_velocity):
		held_item = null
		item_dropped.emit(item)
		Logger.debug(player_name + " dropped " + item.item_name, "InventoryComponent")
		return true
	else:
		Logger.warning(player_name + " failed to drop " + item.item_name, "InventoryComponent")
		return false

## Use currently held item
func use_held_item() -> bool:
	if held_item == null:
		return false
	
	var item: BaseItem = held_item
	var used_successfully: bool = item.use_item()
	
	if used_successfully:
		item_used.emit(item)
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.item(item.item_name, "used by " + player_name, "InventoryComponent")
	
	return used_successfully

## Get the position where held items should be positioned
func get_item_hold_position() -> Vector2:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	var offset: Vector2 = item_hold_offset
	offset.x *= facing_direction  # Flip based on facing direction
	
	var world_pos = player.global_position + offset
	Logger.debug("get_item_hold_position: player_pos=" + str(player.global_position) + " offset=" + str(offset) + " world_pos=" + str(world_pos), "InventoryComponent")
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

## Get array of nearby items
func get_nearby_items() -> Array[BaseItem]:
	return nearby_items.duplicate()

## Force drop held item (for ragdoll/death states)
func force_drop_item(impulse_velocity: Vector2 = Vector2.ZERO) -> void:
	if held_item == null:
		return
	
	var item: BaseItem = held_item
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.item(item.item_name, "force dropped by " + player_name, "InventoryComponent")
	
	if item.drop(impulse_velocity):
		held_item = null
		item_dropped.emit(item)

# Signal handlers for pickup area
func _on_pickup_area_entered(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " pickup area detected body: " + body.name + " (type: " + body.get_class() + ")", "InventoryComponent")
	
	if body is BaseItem:
		var item: BaseItem = body as BaseItem
		Logger.pickup(player_name + " detected item: " + item.item_name + " (can_pickup: " + str(item.can_be_picked_up) + ", is_held: " + str(item.is_held) + ")", "InventoryComponent")
		
		if item.can_be_picked_up and not item.is_held and item not in nearby_items:
			nearby_items.append(item)
			nearby_items_changed.emit(nearby_items)
			Logger.pickup(player_name + " can now pickup: " + item.item_name + " (total nearby: " + str(nearby_items.size()) + ")", "InventoryComponent")
		else:
			Logger.pickup(player_name + " cannot pickup " + item.item_name + " - already in nearby list or not available", "InventoryComponent")
	else:
		Logger.pickup(player_name + " detected non-item body: " + body.name, "InventoryComponent")

func _on_pickup_area_exited(body: Node2D) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup(player_name + " pickup area lost body: " + body.name + " (type: " + body.get_class() + ")", "InventoryComponent")
	
	if body is BaseItem:
		var item: BaseItem = body as BaseItem
		if item in nearby_items:
			nearby_items.erase(item)
			nearby_items_changed.emit(nearby_items)
			Logger.pickup(player_name + " lost pickup range for: " + item.item_name + " (total nearby: " + str(nearby_items.size()) + ")", "InventoryComponent")
		else:
			Logger.pickup(player_name + " lost " + item.item_name + " but it wasn't in nearby list", "InventoryComponent") 
