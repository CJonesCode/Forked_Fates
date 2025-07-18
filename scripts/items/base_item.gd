class_name BaseItem
extends RigidBody2D

## Base item class for all interactive objects
## Handles pickup/drop mechanics, physics, and basic interactions

# Item configuration
@export var item_name: String = "Item"
@export var item_description: String = "A mysterious item"
@export var can_be_picked_up: bool = true
@export var can_be_dropped: bool = true
@export var use_cooldown: float = 0.5

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_collision: CollisionShape2D = $PickupArea/CollisionShape2D

# State
var is_held: bool = false
var holder: BasePlayer = null
var last_use_time: float = 0.0

# Configuration reference
var game_config: GameConfig

signal item_picked_up(by_player: BasePlayer)
signal item_dropped(by_player: BasePlayer)
signal item_used(by_player: BasePlayer)

func _ready() -> void:
	# Load game configuration
	game_config = GameConfig.get_instance()
	
	# Setup physics
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 10
	
	# Setup collision layers
	CollisionLayers.setup_item(self)
	
	# Setup pickup area collision
	if pickup_area:
		CollisionLayers.setup_pickup_area(pickup_area)
		# Check before connecting to prevent duplicate connections (standards compliance)
		if not pickup_area.body_entered.is_connected(_on_pickup_area_entered):
			pickup_area.body_entered.connect(_on_pickup_area_entered)
		if not pickup_area.body_exited.is_connected(_on_pickup_area_exited):
			pickup_area.body_exited.connect(_on_pickup_area_exited)
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(self, item_name + " item body")
	if pickup_area:
		CollisionLayers.debug_collision_setup(pickup_area, item_name + " pickup area")
	
	Logger.item(item_name, "initialized", "BaseItem")

## Cleanup item properly to prevent RID leaks
func _exit_tree() -> void:
	# Disconnect pickup area signals
	if pickup_area:
		if pickup_area.body_entered.is_connected(_on_pickup_area_entered):
			pickup_area.body_entered.disconnect(_on_pickup_area_entered)
		if pickup_area.body_exited.is_connected(_on_pickup_area_exited):
			pickup_area.body_exited.disconnect(_on_pickup_area_exited)
	
	# Only clear holder reference if we're actually being destroyed, not just reparenting
	# Check if we're being held - if so, don't clear the holder reference during reparenting
	if holder and not is_held:
		holder = null
	
	Logger.debug("BaseItem " + item_name + " cleanup completed", "BaseItem")

# Note: Position updates are now handled immediately when player facing changes
# in the player's set_input function, so no _process needed

## Attempt to pick up this item
func pickup(player: BasePlayer) -> bool:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.pickup("DEBUG: " + item_name + ".pickup() called by " + player_name, "BaseItem")
	Logger.pickup("DEBUG: can_be_picked_up=" + str(can_be_picked_up) + " is_held=" + str(is_held) + " player=" + str(player != null), "BaseItem")
	
	if not can_be_picked_up or is_held or not player:
		Logger.pickup("DEBUG: " + item_name + " pickup failed initial checks", "BaseItem")
		return false
	
	# Check if enough time has passed since last drop
	var time_since_drop = Time.get_unix_time_from_system() - last_use_time
	var required_time = game_config.item_pickup_disable_time
	Logger.pickup("DEBUG: " + item_name + " time check: " + str(time_since_drop) + " >= " + str(required_time), "BaseItem")
	
	if time_since_drop < required_time:
		Logger.pickup("DEBUG: " + item_name + " pickup failed - too soon since last drop", "BaseItem")
		return false
	
	Logger.pickup("DEBUG: " + item_name + " setting held state", "BaseItem")
	
	# Set as held
	is_held = true
	holder = player
	
	# Disable physics while held
	freeze = true
	Logger.pickup("DEBUG: " + item_name + " removing from collision layers", "BaseItem")
	CollisionLayers.remove_layer(self, CollisionLayers.Layer.ITEMS)
	CollisionLayers.remove_mask(self, CollisionLayers.Mask.ITEMS_INTERACTION)
	
	# Attach to player
	Logger.pickup("DEBUG: " + item_name + " calling _attach_to_player", "BaseItem")
	_attach_to_player(player)
	
	# Emit signals
	item_picked_up.emit(player)
	var player_id = player.player_data.player_id if player.player_data else -1
	EventBus.emit_item_picked_up(player_id, item_name)
	
	Logger.pickup(player_name + " picked up " + item_name, "BaseItem")
	Logger.pickup("DEBUG: " + item_name + " pickup complete - is_held=" + str(is_held) + " visible=" + str(visible), "BaseItem")
	return true

## Drop this item
func drop(drop_velocity: Vector2 = Vector2.ZERO) -> bool:
	if not is_held or not holder:
		return false
	
	var dropping_player = holder
	
	# Detach from player BEFORE resetting holder
	var dropping_player_name: String = dropping_player.player_data.player_name if dropping_player.player_data else "Unknown Player"
	Logger.pickup("Dropping " + item_name + " from " + dropping_player_name, "BaseItem")
	_detach_from_player()
	
	# Reset state
	is_held = false
	holder = null
	last_use_time = Time.get_unix_time_from_system()
	
	# Reset visual orientation to default (facing right)
	scale.x = abs(scale.x)
	rotation = 0.0  # Reset rotation when dropped to be upright
	
	# Re-enable physics
	freeze = false
	CollisionLayers.add_layer(self, CollisionLayers.Layer.ITEMS)
	CollisionLayers.add_mask(self, CollisionLayers.Mask.ITEMS_INTERACTION)
	
	# Apply drop velocity
	linear_velocity = drop_velocity
	
	# Emit signals
	item_dropped.emit(dropping_player)
	var dropping_player_id = dropping_player.player_data.player_id if dropping_player.player_data else -1
	EventBus.emit_item_dropped(dropping_player_id, item_name)
	
	# Use the same variable we defined earlier
	Logger.pickup(dropping_player_name + " dropped " + item_name, "BaseItem")
	return true

## Use this item
func use_item() -> bool:
	if not is_held or not holder:
		return false
	
	# Check cooldown
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_use_time < use_cooldown:
		return false
	
	last_use_time = current_time
	
	# Call the specific use implementation
	if _use_implementation():
		item_used.emit(holder)
		var holder_id = holder.player_data.player_id if holder.player_data else -1
		EventBus.emit_item_used(holder_id, item_name)
		return true
	
	return false

## Override this in derived classes for specific use behavior
func _use_implementation() -> bool:
	var holder_name = holder.player_data.player_name if holder.player_data else "Unknown Player"
	Logger.item(item_name, "used by " + holder_name, "BaseItem")
	return true

## Override this in derived classes to define weapon-specific aiming behavior
## Examples:
##   - Pistol: get facing from MovementComponent  # Follow player facing
##   - Shotgun: might use player facing with spread
##   - Homing weapon: might track nearest enemy
##   - Consumables: return Vector2.ZERO (no aiming needed)
func _get_aim_direction() -> Vector2:
	# Default implementation: no aiming (items that don't need aiming)
	return Vector2.ZERO

## Attach item to player (visually and spatially)
func _attach_to_player(player: BasePlayer) -> void:
	# Get facing direction from player's MovementComponent for debug log
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.debug("Attaching " + item_name + " to " + player_name + " (facing: " + str(facing_direction) + ")", "BaseItem")
	
	# Store the holder reference to preserve it during reparenting
	var temp_holder: BasePlayer = holder
	var temp_is_held: bool = is_held
	
	# Store current world position to avoid visual jump
	var current_world_pos: Vector2 = global_position
	Logger.debug(item_name + " world position before attach: " + str(current_world_pos), "BaseItem")
	
	# Remove from current parent
	if get_parent():
		get_parent().remove_child(self)
		Logger.debug("Removed " + item_name + " from parent", "BaseItem")
	
	# Restore holder state after potential _exit_tree() call during reparenting
	holder = temp_holder
	is_held = temp_is_held
	
	# Add to player as child
	player.add_child(self)
	Logger.debug("Added " + item_name + " as child of " + player_name, "BaseItem")
	
	# Verify holder is still valid after reparenting
	if not holder:
		Logger.warning("Holder was lost during reparenting, restoring...", "BaseItem")
		holder = player
		is_held = true
	
	# Reset physics properties for held state
	freeze = true
	visible = true  # Ensure item remains visible
	
	# Reset rotation to 0 when picked up (fix rotation issue)
	rotation = 0.0
	
	# Update position and visual orientation immediately
	Logger.debug("Calling _update_held_position from attach", "BaseItem")
	_update_held_position()
	
	Logger.debug(item_name + " final relative position: " + str(position), "BaseItem")
	Logger.debug(item_name + " final world position: " + str(global_position), "BaseItem")

## Update held item position and orientation based on player facing
func _update_held_position() -> void:
	if not is_held or not holder:
		Logger.warning(item_name + " _update_held_position called but not properly held (is_held=" + str(is_held) + " holder=" + str(holder) + ")", "BaseItem")
		return
	
	# Additional safety check: make sure we're actually a child of the holder
	if get_parent() != holder:
		Logger.warning(item_name + " _update_held_position called but not child of holder (parent=" + str(get_parent()) + " holder=" + str(holder) + ")", "BaseItem")
		return
	
	# Get facing direction from player's MovementComponent
	var movement_component: MovementComponent = holder.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	# Use inventory component's hold position method if available
	var inventory_component: InventoryComponent = holder.get_component(InventoryComponent)
	if inventory_component:
		# Get the proper hold position in world coordinates
		var world_hold_pos: Vector2 = inventory_component.get_item_hold_position()
		# Convert to local coordinates relative to the player
		position = holder.to_local(world_hold_pos)
		Logger.debug(item_name + " positioned using InventoryComponent: world=" + str(world_hold_pos) + " local=" + str(position), "BaseItem")
	else:
		# Fallback: use game config offset directly
		var hold_offset = game_config.item_hold_offset
		hold_offset.x = abs(hold_offset.x) * facing_direction  # Flip X based on facing direction
		position = hold_offset
		Logger.debug(item_name + " positioned using fallback offset: " + str(position), "BaseItem")
	
	# Update visual orientation to match player facing
	# Scale the entire item node to flip it visually
	var old_scale = scale.x
	scale.x = abs(scale.x) * facing_direction
	Logger.debug(item_name + " item flip: facing=" + str(facing_direction) + " old_scale=" + str(old_scale) + " new_scale=" + str(scale.x), "BaseItem")

## Detach item from player
func _detach_from_player() -> void:
	if not holder:
		Logger.warning("Cannot detach " + item_name + " - no holder", "BaseItem")
		return
	
	Logger.debug("Detaching " + item_name + " from " + holder.player_data.player_name, "BaseItem")
	
	# Store references before reparenting (holder might become null during _exit_tree())
	var temp_holder: BasePlayer = holder
	var scene_tree = temp_holder.get_tree()
	
	# Get world position before reparenting
	var world_pos = global_position
	Logger.debug("World position before detach: " + str(world_pos), "BaseItem")
	
	# Remove from player
	temp_holder.remove_child(self)
	Logger.debug("Removed from player", "BaseItem")
	
	# Add back to scene tree using stored reference
	var scene_root = scene_tree.current_scene
	scene_root.add_child(self)
	Logger.debug("Added to scene root: " + scene_root.name, "BaseItem")
	
	# Restore world position
	global_position = world_pos
	Logger.debug("Final world position: " + str(global_position), "BaseItem")

## Get item info for UI display
func get_item_info() -> Dictionary:
	return {
		"name": item_name,
		"description": item_description,
		"can_pickup": can_be_picked_up and not is_held,
		"is_held": is_held
	}

# Signal handlers
func _on_pickup_area_entered(body: Node2D) -> void:
	if body is BasePlayer and can_be_picked_up and not is_held:
		var player = body as BasePlayer
		# The player can attempt pickup when they press the use button
		# For now, just notify the player that an item is nearby
		pass

func _on_pickup_area_exited(body: Node2D) -> void:
	if body is BasePlayer:
		# Player moved away from item
		pass 
