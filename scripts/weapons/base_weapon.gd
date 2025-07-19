class_name BaseWeapon
extends BaseItem

## Base weapon class for all combat items - ID-based architecture
## Eliminates circular dependency with PlayerManager lookups

# Configuration-loaded weapon properties (replaces hard-coded @export values)
var base_damage: int = 1
var fire_rate: float = 1.0
var ammo_capacity: int = -1  # -1 for infinite ammo
var throw_damage_multiplier: float = 1.5
var max_throw_force: float = 600.0
var projectile_lifetime: float = 10.0
var can_ricochet: bool = false
var max_ricochets: int = 2

# ID-based weapon state (no circular dependency)
var is_thrown_projectile: bool = false
var ammo_current: int = 0
var thrown_by_id: int = -1  # ID instead of object reference
var throw_damage: int = 0
var ricochet_count: int = 0

# Original collision settings
var original_collision_layer: int = 0
var original_collision_mask: int = 0

# ID-based signals (no circular dependency)
signal weapon_fired()
signal weapon_thrown(thrower_id: int)
signal weapon_hit_target(target: Node, damage: int)
signal ammo_depleted()

func _ready() -> void:
	# Call parent BaseItem initialization
	super()
	
	# Load weapon configuration
	_load_weapon_config()
	
	# Initialize weapon
	item_name = item_name if item_name != "Item" else "Base Weapon"
	
	# Store original collision settings
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	# Initialize ammo based on loaded config
	if ammo_capacity > 0:
		ammo_current = ammo_capacity
	
	# Connect to EventBus weapon positioning signals
	_connect_positioning_signals()
	
	Logger.system("BaseWeapon initialized: " + item_name, "BaseWeapon")

## Update weapon position via EventBus when held
func _physics_process(delta: float) -> void:
	if is_held and holder:
		_request_position_update()

## ID-based pickup - no circular dependency (new method to avoid override conflict)
func pickup_by_id(player_id: int) -> bool:
	if is_held or player_id == -1:
		return false
	
	# Lookup player when needed - no circular dependency
	var player: BasePlayer = PlayerManager.get_player(player_id)
	if not player:
		Logger.error("Cannot pickup weapon - player not found: ID=" + str(player_id), "BaseWeapon")
		return false
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	
	# Replicate BaseItem pickup logic without calling super
	if not can_be_picked_up or is_held or not player:
		return false
	
	# Check cooldown
	var time_since_drop = Time.get_unix_time_from_system() - last_use_time
	var required_time = game_config.item_pickup_disable_time if game_config else 0.0
	
	if time_since_drop < required_time:
		return false
	
	# Set as held
	is_held = true
	holder = player
	
	# Disable physics
	freeze = true
	CollisionLayers.remove_layer(self, CollisionLayers.Layer.ITEMS)
	CollisionLayers.remove_mask(self, CollisionLayers.Mask.ITEMS_INTERACTION)
	
	# Attach to player
	_attach_to_player(player)
	
	# Weapon-specific setup
	is_thrown_projectile = false
	CollisionLayers.setup_weapon(self)
	
	# Emit signals
	item_picked_up.emit(player)
	var p_id = player.player_data.player_id if player.player_data else -1
	EventBus.emit_item_picked_up(p_id, item_name)
	weapon_hit_target.emit(player, 0)
	
	Logger.pickup("Weapon " + item_name + " picked up by " + player_name, "BaseWeapon")
	return true

# Duplicate throw_weapon method removed - using the more complete implementation below

## Compatibility wrapper for traditional pickup method
func pickup(player: BasePlayer) -> bool:
	if not player or not player.player_data:
		return false
	return pickup_by_id(player.player_data.player_id)

## Fire weapon (implemented by subclasses)
func fire_weapon() -> bool:
	Logger.warning("fire_weapon() not implemented for " + item_name, "BaseWeapon")
	return false

## Get thrower player object (type-safe lookup)
func get_thrower() -> BasePlayer:
	if thrown_by_id == -1:
		return null
	return PlayerManager.get_player(thrown_by_id)

## Detach weapon from player (internal helper method)
func _detach_weapon_from_player(player: BasePlayer) -> void:
	if player and player.weapon:
		if player.weapon.held_weapon == self:
			player.weapon.held_weapon = null

## Enable projectile mode
func _enable_projectile_mode() -> void:
	is_thrown_projectile = true
	CollisionLayers.setup_projectile(self)

## Load weapon configuration from ItemConfig .tres files
func _load_weapon_config() -> void:
	var weapon_id: String = _get_weapon_id()
	var config: ItemConfig = ConfigManager.get_item_config(weapon_id)
	
	if config:
		Logger.system("Loading weapon config for: " + weapon_id, "BaseWeapon")
		_apply_weapon_config(config)
	else:
		Logger.warning("No weapon config found for: " + weapon_id + " - using defaults", "BaseWeapon")

## Apply configuration values to weapon properties
func _apply_weapon_config(config: ItemConfig) -> void:
	# Apply basic properties
	base_damage = config.damage_amount
	item_name = config.item_name
	
	# Apply weapon-specific properties
	fire_rate = config.fire_rate
	ammo_capacity = config.ammo_capacity
	throw_damage_multiplier = config.throw_damage_multiplier
	max_throw_force = config.max_throw_force
	can_ricochet = config.can_ricochet
	max_ricochets = config.max_ricochets
	
	# Initialize ammo based on config
	if ammo_capacity > 0:
		ammo_current = ammo_capacity
	
	Logger.system("Applied weapon config: damage=" + str(base_damage) + ", fire_rate=" + str(fire_rate), "BaseWeapon")

## Extract weapon ID from scene name or class name
func _get_weapon_id() -> String:
	# Extract weapon ID from scene name
	var scene_file: String = get_scene_file_path()
	if not scene_file.is_empty():
		var file_name: String = scene_file.get_file().get_basename()
		return file_name.to_lower()
	
	# Fallback to script filename
	var script_path: String = get_script().resource_path
	if not script_path.is_empty():
		var script_name: String = script_path.get_file().get_basename()
		if script_name.to_lower().ends_with("_weapon"):
			return script_name.to_lower().replace("_weapon", "")
		return script_name.to_lower()
	
	# Final fallback
	return "base_weapon"

## Check if weapon has ammo available
func has_ammo() -> bool:
	# Infinite ammo weapons (-1) always have ammo
	if ammo_capacity == -1:
		return true
	
	# Limited ammo weapons check current ammo
	return ammo_current > 0

## Consume one unit of ammo
func consume_ammo() -> bool:
	# Infinite ammo weapons don't consume
	if ammo_capacity == -1:
		return true
	
	# Check if we have ammo to consume
	if ammo_current <= 0:
		ammo_depleted.emit()
		return false
	
	# Consume ammo
	ammo_current -= 1
	
	# Check if depleted after consumption
	if ammo_current <= 0:
		ammo_depleted.emit()
	
	return true

## Reset weapon for object pooling
func reset_for_pool() -> void:
	# Reset weapon state
	is_thrown_projectile = false
	thrown_by_id = -1
	throw_damage = 0
	ricochet_count = 0
	
	# Reset physics state
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# Reset position and rotation
	global_position = Vector2.ZERO
	rotation = 0.0
	
	# Reset collision settings to original
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	
	# Reset held state
	is_held = false
	holder = null
	
	# Reset ammo to full if not infinite
	if ammo_capacity > 0:
		ammo_current = ammo_capacity

## Get weapon information for UI and debugging
func get_weapon_info() -> Dictionary:
	var holder_id: int = -1
	if holder and holder.player_data:
		holder_id = holder.player_data.player_id
	
	return {
		"weapon_name": item_name,
		"base_damage": base_damage,
		"fire_rate": fire_rate,
		"is_held": is_held,
		"holder_id": holder_id,
		"is_thrown_projectile": is_thrown_projectile,
		"thrown_by_id": thrown_by_id,
		"throw_damage": throw_damage,
		"can_ricochet": can_ricochet,
		"ricochet_count": ricochet_count,
		"max_ricochets": max_ricochets
	}

## Throw weapon as projectile (Duck Game style mechanics)
func throw_weapon(direction: Vector2, force: float, thrower_id: int) -> bool:
	if not is_held or not holder:
		return false
	
	# Calculate throw damage based on base damage and multiplier
	throw_damage = int(base_damage * throw_damage_multiplier)
	
	# Set projectile state
	is_thrown_projectile = true
	thrown_by_id = thrower_id
	ricochet_count = 0
	
	# Enable projectile collision mode
	_enable_projectile_mode()
	
	# Apply throw force
	var clamped_force = min(force, max_throw_force)
	linear_velocity = direction.normalized() * clamped_force
	
	# Release from holder
	is_held = false
	holder = null
	
	# Re-enable physics
	freeze = false
	
	# Emit throw signal
	weapon_thrown.emit(thrower_id)
	
	Logger.combat("Weapon " + item_name + " thrown with force " + str(clamped_force) + " (damage: " + str(throw_damage) + ")", "BaseWeapon")
	return true

## Connect to EventBus weapon positioning signals
func _connect_positioning_signals() -> void:
	# Connect to weapon position provided signal
	if not EventBus.weapon_position_provided.is_connected(_on_weapon_position_provided):
		EventBus.weapon_position_provided.connect(_on_weapon_position_provided)
	
	# Connect to weapon facing provided signal  
	if not EventBus.weapon_facing_provided.is_connected(_on_weapon_facing_provided):
		EventBus.weapon_facing_provided.connect(_on_weapon_facing_provided)

## Disconnect from EventBus weapon positioning signals
func _disconnect_positioning_signals() -> void:
	if EventBus.weapon_position_provided.is_connected(_on_weapon_position_provided):
		EventBus.weapon_position_provided.disconnect(_on_weapon_position_provided)
	
	if EventBus.weapon_facing_provided.is_connected(_on_weapon_facing_provided):
		EventBus.weapon_facing_provided.disconnect(_on_weapon_facing_provided)

## Request position update via EventBus when held
func _request_position_update() -> void:
	if not is_held or not holder:
		return
	
	var weapon_id: String = item_name
	var holder_id: int = holder.player_data.player_id if holder.player_data else -1
	
	if holder_id != -1:
		# Request position via EventBus
		EventBus.weapon_position_requested.emit(weapon_id, holder_id)
		EventBus.weapon_facing_requested.emit(weapon_id, holder_id)

## Handle weapon position provided via EventBus
func _on_weapon_position_provided(weapon_id: String, position: Vector2, rotation_angle: float) -> void:
	if weapon_id == item_name and is_held:
		global_position = position
		rotation = rotation_angle

## Handle weapon facing provided via EventBus  
func _on_weapon_facing_provided(weapon_id: String, facing: int) -> void:
	if weapon_id == item_name and is_held:
		# Apply facing-based rotation (1 for right, -1 for left)
		if facing > 0:
			scale.x = abs(scale.x)  # Face right
		else:
			scale.x = -abs(scale.x)  # Face left

## Cleanup on exit
func _exit_tree() -> void:
	# Disconnect positioning signals
	_disconnect_positioning_signals()
	# Basic cleanup
	super() 