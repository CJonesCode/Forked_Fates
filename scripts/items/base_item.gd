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
		pickup_area.body_entered.connect(_on_pickup_area_entered)
		pickup_area.body_exited.connect(_on_pickup_area_exited)
	
	# Debug collision setup
	CollisionLayers.debug_collision_setup(self, item_name + " item body")
	if pickup_area:
		CollisionLayers.debug_collision_setup(pickup_area, item_name + " pickup area")
	
	print("Item initialized: ", item_name)

# Note: Position updates are now handled immediately when player facing changes
# in the player's set_input function, so no _process needed

## Attempt to pick up this item
func pickup(player: BasePlayer) -> bool:
	if not can_be_picked_up or is_held or not player:
		return false
	
	# Check if enough time has passed since last drop
	if Time.get_unix_time_from_system() - last_use_time < game_config.item_pickup_disable_time:
		return false
	
	# Set as held
	is_held = true
	holder = player
	
	# Disable physics while held
	freeze = true
	CollisionLayers.remove_layer(self, CollisionLayers.Layer.ITEMS)
	CollisionLayers.remove_mask(self, CollisionLayers.Mask.ITEMS_INTERACTION)
	
	# Attach to player
	_attach_to_player(player)
	
	# Emit signals
	item_picked_up.emit(player)
	EventBus.emit_item_picked_up(player.player_data.player_id, item_name)
	
	print(player.player_data.player_name, " picked up ", item_name)
	return true

## Drop this item
func drop(drop_velocity: Vector2 = Vector2.ZERO) -> bool:
	if not is_held or not holder:
		return false
	
	var dropping_player = holder
	
	# Detach from player BEFORE resetting holder
	print("🎯 Dropping ", item_name, " from ", dropping_player.player_data.player_name)
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
	EventBus.emit_item_dropped(dropping_player.player_data.player_id, item_name)
	
	print(dropping_player.player_data.player_name, " dropped ", item_name)
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
		EventBus.emit_item_used(holder.player_data.player_id, item_name)
		return true
	
	return false

## Override this in derived classes for specific use behavior
func _use_implementation() -> bool:
	print(holder.player_data.player_name, " used ", item_name)
	return true

## Override this in derived classes to define weapon-specific aiming behavior
## Examples:
##   - Pistol: return Vector2(holder.facing_direction, 0)  # Follow player facing
##   - Shotgun: might use player facing with spread
##   - Homing weapon: might track nearest enemy
##   - Consumables: return Vector2.ZERO (no aiming needed)
func _get_aim_direction() -> Vector2:
	# Default implementation: no aiming (items that don't need aiming)
	return Vector2.ZERO

## Attach item to player (visually and spatially)
func _attach_to_player(player: BasePlayer) -> void:
	print("🔗 Attaching ", item_name, " to ", player.player_data.player_name, " (facing: ", player.facing_direction, ")")
	
	# Remove from current parent
	if get_parent():
		get_parent().remove_child(self)
	
	# Add to player as child
	player.add_child(self)
	
	# Reset rotation to 0 when picked up (fix rotation issue)
	rotation = 0.0
	
	# Update position and visual orientation
	print("🔄 Calling _update_held_position from attach...")
	_update_held_position()

## Update held item position and orientation based on player facing
func _update_held_position() -> void:
	if not is_held or not holder:
		print("⚠️ ", item_name, " _update_held_position called but not properly held (is_held=", is_held, " holder=", holder, ")")
		return
	
	# Additional safety check: make sure we're actually a child of the holder
	if get_parent() != holder:
		print("⚠️ ", item_name, " _update_held_position called but not child of holder (parent=", get_parent(), " holder=", holder, ")")
		return
	
	# Position relative to player using config offset (adjusted for facing direction)
	var hold_offset = game_config.item_hold_offset
	var original_x = hold_offset.x
	hold_offset.x = abs(hold_offset.x) * holder.facing_direction  # Flip X based on facing direction
	position = hold_offset
	
	# Debug positioning
	print("📍 ", item_name, " position update: facing=", holder.facing_direction, " original_x=", original_x, " new_x=", hold_offset.x, " final_pos=", position)
	
	# Update visual orientation to match player facing
	# Scale the entire item node to flip it visually
	var old_scale = scale.x
	scale.x = abs(scale.x) * holder.facing_direction
	print("🔄 ", item_name, " item flip: old_scale=", old_scale, " new_scale=", scale.x)

## Detach item from player
func _detach_from_player() -> void:
	if not holder:
		print("❌ Cannot detach ", item_name, " - no holder")
		return
	
	print("🔗 Detaching ", item_name, " from ", holder.player_data.player_name)
	
	# Get world position before reparenting
	var world_pos = global_position
	print("   World position before detach: ", world_pos)
	
	# Remove from player
	holder.remove_child(self)
	print("   Removed from player")
	
	# Add back to scene tree (find appropriate parent)
	var scene_root = holder.get_tree().current_scene
	scene_root.add_child(self)
	print("   Added to scene root: ", scene_root.name)
	
	# Restore world position
	global_position = world_pos
	print("   Final world position: ", global_position)

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
