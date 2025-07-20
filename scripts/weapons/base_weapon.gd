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

# Magazine-based ammo system properties
var auto_reload: bool = false
var infinite_total_ammo: bool = false
var magazine_size: int = -1
var reload_time: float = 1.0
var is_reloading: bool = false

# ID-based weapon state (no circular dependency)
var is_thrown_projectile: bool = false
var ammo_current: int = 0  # Current shots in magazine
var total_ammo: int = -1   # Total ammo remaining (-1 for infinite)
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
	
	# Connect collision signal for thrown weapon damage
	if not body_shape_entered.is_connected(_on_thrown_weapon_collision):
		body_shape_entered.connect(_on_thrown_weapon_collision)
	
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
	if player and player.item:
		if player.item.get_held_weapon() == self:
			player.item.held_item = null

## Enable projectile mode
func _enable_projectile_mode() -> void:
	is_thrown_projectile = true
	
	# Explicit collision setup for thrown weapons (ensure it works like bullets)
	collision_layer = CollisionLayers.Layer.PROJECTILES  # Layer 8
	collision_mask = CollisionLayers.Mask.PROJECTILE_TARGETS  # 35 (includes PLAYERS)
	
	# Force enable contact monitoring (critical for RigidBody2D collision detection)
	contact_monitor = true
	max_contacts_reported = 10
	
	# Ensure collision signal is connected for projectile mode
	if not body_shape_entered.is_connected(_on_thrown_weapon_collision):
		body_shape_entered.connect(_on_thrown_weapon_collision)
	
	Logger.combat("Weapon " + item_name + " enabled as projectile - ready for collision detection", "BaseWeapon")

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
	
	# Apply magazine-based ammo system properties
	auto_reload = config.auto_reload
	infinite_total_ammo = config.infinite_total_ammo
	magazine_size = config.magazine_size if config.magazine_size > 0 else config.ammo_capacity
	reload_time = config.reload_time
	
	# Initialize ammo system
	if magazine_size > 0:
		ammo_current = magazine_size
	elif ammo_capacity > 0:
		ammo_current = ammo_capacity
	
	# Initialize total ammo
	if infinite_total_ammo:
		total_ammo = -1  # Infinite
	else:
		total_ammo = ammo_capacity  # Limited to initial capacity
	
	Logger.system("Applied weapon config: damage=" + str(base_damage) + ", fire_rate=" + str(fire_rate) + ", auto_reload=" + str(auto_reload), "BaseWeapon")

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
	# Don't fire while reloading
	if is_reloading:
		return false
	
	# Infinite magazine weapons always have ammo
	if ammo_capacity == -1 and magazine_size == -1:
		return true
	
	# Check current magazine ammo
	return ammo_current > 0

## Consume one unit of ammo
func consume_ammo() -> bool:
	# Don't consume while reloading
	if is_reloading:
		return false
	
	# Infinite magazine weapons don't consume
	if ammo_capacity == -1 and magazine_size == -1:
		return true
	
	# Check if we have ammo to consume
	if ammo_current <= 0:
		ammo_depleted.emit()
		return false
	
	# Consume ammo from magazine
	ammo_current -= 1
	
	# Check if magazine is empty
	if ammo_current <= 0:
		ammo_depleted.emit()
		
		# Auto-reload if enabled and we have total ammo
		if auto_reload and _can_reload():
			_start_auto_reload()
	
	return true

## Reload weapon magazine
func reload() -> bool:
	if is_reloading:
		return false
	
	if not _can_reload():
		return false
	
	if _is_magazine_full():
		return false
	
	return _start_manual_reload()

## Check if weapon can reload
func _can_reload() -> bool:
	# Infinite magazine weapons don't need reload
	if ammo_capacity == -1 and magazine_size == -1:
		return false
	
	# Check if we have total ammo to reload from
	if infinite_total_ammo or total_ammo == -1:
		return true  # Always can reload with infinite total ammo
	
	return total_ammo > 0  # Can reload if we have total ammo

## Check if magazine is full
func _is_magazine_full() -> bool:
	var max_mag_size = magazine_size if magazine_size > 0 else ammo_capacity
	return ammo_current >= max_mag_size

## Start auto-reload process
func _start_auto_reload() -> void:
	is_reloading = true
	Logger.debug("Auto-reloading " + item_name + "...", "BaseWeapon")
	
	# Use a timer for reload delay
	var reload_timer = get_tree().create_timer(reload_time)
	reload_timer.timeout.connect(_complete_reload)

## Start manual reload process
func _start_manual_reload() -> bool:
	is_reloading = true
	Logger.debug("Manually reloading " + item_name + "...", "BaseWeapon")
	
	# Use a timer for reload delay
	var reload_timer = get_tree().create_timer(reload_time)
	reload_timer.timeout.connect(_complete_reload)
	
	return true

## Complete the reload process
func _complete_reload() -> void:
	is_reloading = false
	
	var max_mag_size = magazine_size if magazine_size > 0 else ammo_capacity
	var ammo_needed = max_mag_size - ammo_current
	
	if infinite_total_ammo or total_ammo == -1:
		# Infinite total ammo - just fill magazine
		ammo_current = max_mag_size
	else:
		# Limited total ammo - transfer from total to magazine
		var ammo_to_transfer = min(ammo_needed, total_ammo)
		ammo_current += ammo_to_transfer
		total_ammo -= ammo_to_transfer
	
	Logger.debug("Weapon reloaded: " + item_name + " (" + str(ammo_current) + "/" + str(max_mag_size) + ")", "BaseWeapon")

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
	
	# Reset magazine system state
	is_reloading = false
	
	# Reset ammo to full magazine
	var max_mag_size = magazine_size if magazine_size > 0 else ammo_capacity
	if max_mag_size > 0:
		ammo_current = max_mag_size
	
	# Reset total ammo
	if infinite_total_ammo:
		total_ammo = -1
	else:
		total_ammo = ammo_capacity

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

## Unified throw/drop system - force determines if weaponized or gentle drop
func throw_weapon(direction: Vector2, force: float, thrower_id: int) -> bool:
	if not is_held or not holder:
		Logger.debug("🚀 throw_weapon() failed - is_held=" + str(is_held) + " holder=" + str(holder != null), "BaseWeapon")
		return false
	
	Logger.combat("🚀 WEAPON THROW START: " + item_name + " thrown by player " + str(thrower_id) + " with force " + str(force), "BaseWeapon")
	Logger.debug("🚀 Throw details: direction=" + str(direction) + " force=" + str(force) + " thrower_id=" + str(thrower_id), "BaseWeapon")
	
	# CRITICAL: Detach weapon from player first (shared logic)
	_detach_from_player()
	
	# Force threshold for weaponization
	var weaponize_threshold: float = 200.0
	var clamped_force = min(force, max_throw_force)
	
	if clamped_force > weaponize_threshold:
		# HIGH FORCE: Weaponized projectile mode
		is_thrown_projectile = true
		thrown_by_id = thrower_id
		ricochet_count = 0
		throw_damage = int(base_damage * throw_damage_multiplier)
		
		Logger.combat("🚀 ✅ WEAPON WEAPONIZED: " + item_name + " set to projectile mode (thrown_by_id: " + str(thrown_by_id) + ", damage: " + str(throw_damage) + ")", "BaseWeapon")
		
		# Enable projectile collision mode (can damage players)
		_enable_projectile_mode()
		
		Logger.combat("🚀 Weapon " + item_name + " WEAPONIZED with force " + str(clamped_force) + " (damage: " + str(throw_damage) + ")", "BaseWeapon")
	else:
		# LOW FORCE: Gentle drop mode
		is_thrown_projectile = false
		thrown_by_id = -1
		throw_damage = 0
		
		Logger.debug("🚀 GENTLE DROP: " + item_name + " dropped gently (not weaponized)", "BaseWeapon")
		
		# Use normal item collision (can be picked up, won't damage)
		CollisionLayers.setup_item(self)
		
		# Reset visual orientation for dropped items (face right, upright)
		rotation = 0.0
		scale.x = abs(scale.x)
		
		Logger.pickup("🚀 Weapon " + item_name + " gently dropped with force " + str(clamped_force), "BaseWeapon")
	
	# Apply physics (shared logic)
	linear_velocity = direction.normalized() * clamped_force
	
	# Release from holder (shared logic)
	is_held = false
	holder = null
	# Defer physics mode change to avoid conflicts during physics processing
	call_deferred("_unfreeze_weapon")
	
	# Set pickup cooldown timer to prevent immediate re-pickup
	last_use_time = Time.get_unix_time_from_system()
	
	# Emit appropriate signal
	weapon_thrown.emit(thrower_id)
	
	Logger.debug("🚀 Weapon throw completed - is_thrown_projectile=" + str(is_thrown_projectile) + " thrown_by_id=" + str(thrown_by_id), "BaseWeapon")
	return true

## Convenience method: Gentle drop (backwards compatibility)
func drop(drop_velocity: Vector2 = Vector2.ZERO) -> bool:
	var holder_id = holder.player_data.player_id if holder and holder.player_data else -1
	var direction = drop_velocity.normalized() if drop_velocity.length() > 0.1 else Vector2.DOWN
	var force = drop_velocity.length() if drop_velocity.length() > 10.0 else 50.0  # Gentle force
	
	return throw_weapon(direction, force, holder_id)

## Convenience method: Weaponized throw (backwards compatibility)  
func throw_as_projectile(direction: Vector2, force: float, thrower_id: int) -> bool:
	var weaponized_force = max(force, 250.0)  # Ensure it's weaponized
	return throw_weapon(direction, weaponized_force, thrower_id)

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

## Handle collision when weapon is thrown as projectile
func _on_thrown_weapon_collision(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	# Only handle collisions when thrown as projectile
	if not is_thrown_projectile:
		return
	
	Logger.combat("Thrown " + item_name + " collided with: " + body.name + " (" + body.get_class() + ")", "BaseWeapon")
	
	# Don't hit the thrower immediately
	if body is BasePlayer:
		var player: BasePlayer = body as BasePlayer
		if player.player_data and player.player_data.player_id == thrown_by_id:
			Logger.debug("Ignoring collision with thrower", "BaseWeapon")
			return
		
		# Hit player with thrown weapon
		_hit_player_with_thrown_weapon(player)
		return
	
	# Handle environment/wall hits for thrown weapons
	if body.is_in_group("walls") or body.is_in_group("environment"):
		_hit_environment_with_thrown_weapon(body)
		return
	
	# Other collisions - just stop the weapon
	Logger.debug("Thrown weapon hit other object: " + body.name, "BaseWeapon")
	_stop_thrown_weapon()

## Handle hitting a player with thrown weapon
func _hit_player_with_thrown_weapon(player: BasePlayer) -> void:
	if not player:
		Logger.debug("🚀 Thrown weapon hit - no player target, stopping weapon", "BaseWeapon")
		_stop_thrown_weapon()
		return
	
	Logger.combat("🚀 THROWN WEAPON HIT: " + item_name + " hit " + player.player_data.player_name + " (thrown_by_id: " + str(thrown_by_id) + ")", "BaseWeapon")
	
	# Look up the thrower using stored ID
	var thrower: BasePlayer = PlayerManager.get_player(thrown_by_id) if thrown_by_id != -1 else null
	
	Logger.debug("🚀 Thrower lookup: thrown_by_id=" + str(thrown_by_id) + " thrower_found=" + str(thrower != null), "BaseWeapon")
	if thrower:
		Logger.debug("🚀 Thrower details: name=" + thrower.player_data.player_name + " id=" + str(thrower.player_data.player_id), "BaseWeapon")
	
	# Apply damage with kill tracking info
	if player.health:
		if thrower and thrower.player_data:
			Logger.combat("🚀 ✅ APPLYING THROWN DAMAGE: " + str(throw_damage) + " from " + thrower.player_data.player_name + " (ID: " + str(thrower.player_data.player_id) + ") to " + player.player_data.player_name, "BaseWeapon")
			
			# SUCCESS: Proper kill attribution with thrower info
			player.health.take_damage(
				throw_damage,
				self,
				thrower.player_data.player_id,
				"Thrown " + item_name
			)
			
			var player_name: String = player.player_data.player_name
			var thrower_name: String = thrower.player_data.player_name
			Logger.combat("🚀 ✅ Thrown " + item_name + " from " + thrower_name + " hit " + player_name + " for " + str(throw_damage) + " damage - ATTRIBUTION SUCCESS", "BaseWeapon")
		elif thrown_by_id != -1:
			Logger.error("🚀 ❌ ATTRIBUTION FAILED: thrown_by_id=" + str(thrown_by_id) + " but PlayerManager lookup failed", "BaseWeapon")
			Logger.error("🚀 Available players in PlayerManager: " + str(PlayerManager.players.keys()), "BaseWeapon")
			
			# ERROR: Valid thrower ID but lookup failed
			player.health.take_damage(
				throw_damage,
				self,
				-1,
				"Thrown " + item_name
			)
			Logger.combat("🚀 ❌ Thrown " + item_name + " hit " + player.player_data.player_name + " - attribution FAILED, falling back to environmental", "BaseWeapon")
		else:
			Logger.debug("🚀 Environmental throw: thrown_by_id=-1, expected environmental damage", "BaseWeapon")
			
			# Expected: No thrower ID (environmental throw)
			player.health.take_damage(
				throw_damage,
				self,
				-1,
				"Thrown " + item_name
			)
			Logger.combat("🚀 Thrown " + item_name + " hit " + player.player_data.player_name + " - no thrower (environmental)", "BaseWeapon")
	else:
		Logger.error("🚀 Target player has no health component: " + player.player_data.player_name, "BaseWeapon")
	
	# Apply knockback/ragdoll force
	_apply_thrown_weapon_knockback(player)
	
	# Stop the thrown weapon
	_stop_thrown_weapon()
	
	Logger.debug("🚀 Thrown weapon hit processing completed", "BaseWeapon")

## Apply knockback/ragdoll from thrown weapon impact
func _apply_thrown_weapon_knockback(target: BasePlayer) -> void:
	if not target:
		return
	
	# Calculate impact direction based on weapon velocity
	var impact_direction: Vector2 = linear_velocity.normalized()
	var impact_force: float = linear_velocity.length()
	
	# Apply knockback based on impact force
	var knockback_force: float = impact_force * 0.5  # Scale down impact
	target.velocity += impact_direction * knockback_force
	
	# Check if impact is strong enough to cause ragdoll  
	var ragdoll_threshold: float = 250.0  # Lowered threshold for momentum-based throwing
	
	if impact_force > ragdoll_threshold:
		var ragdoll_component: RagdollComponent = target.get_component(RagdollComponent)
		if ragdoll_component:
			ragdoll_component.enter_ragdoll_state()
			Logger.combat("Thrown " + item_name + " caused ragdoll on " + target.player_data.player_name + " (impact: " + str(impact_force) + ")", "BaseWeapon")
		else:
			Logger.warning("No ragdoll component found on " + target.player_data.player_name, "BaseWeapon")
	
	Logger.combat("Applied thrown weapon knockback: " + str(knockback_force) + " force", "BaseWeapon")

## Handle thrown weapon hitting environment
func _hit_environment_with_thrown_weapon(surface: Node) -> void:
	Logger.debug("Thrown weapon hit environment: " + surface.name, "BaseWeapon")
	
	# Check for ricochet
	if can_ricochet and ricochet_count < max_ricochets:
		_handle_thrown_weapon_ricochet(surface)
	else:
		_stop_thrown_weapon()

## Handle thrown weapon ricochet
func _handle_thrown_weapon_ricochet(surface: Node) -> void:
	ricochet_count += 1
	
	# Calculate surface normal (simplified)
	var hit_point = global_position
	var surface_position = surface.global_position
	var relative_pos = hit_point - surface_position
	
	var surface_normal: Vector2
	if abs(relative_pos.x) > abs(relative_pos.y):
		surface_normal = Vector2(sign(relative_pos.x), 0)  # Vertical surface
	else:
		surface_normal = Vector2(0, sign(relative_pos.y))  # Horizontal surface
	
	# Reflect velocity and reduce speed
	linear_velocity = linear_velocity.bounce(surface_normal) * 0.7
	throw_damage = int(throw_damage * 0.8)  # Reduce damage on ricochet
	
	Logger.debug("Thrown weapon ricocheted off " + surface.name + " (" + str(ricochet_count) + "/" + str(max_ricochets) + ")", "BaseWeapon")

## Stop thrown weapon movement and return to normal item state
func _stop_thrown_weapon() -> void:
	is_thrown_projectile = false
	thrown_by_id = -1
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# Re-enable normal item physics and collision
	CollisionLayers.setup_item(self)
	
	Logger.debug("Thrown weapon stopped and returned to item state", "BaseWeapon")

## Unfreeze weapon safely (called deferred to avoid physics flush conflicts)
func _unfreeze_weapon() -> void:
	freeze = false

## Cleanup on exit
func _exit_tree() -> void:
	# Disconnect positioning signals
	_disconnect_positioning_signals()
	
	# Disconnect collision signal
	if body_shape_entered.is_connected(_on_thrown_weapon_collision):
		body_shape_entered.disconnect(_on_thrown_weapon_collision)
	
	# Basic cleanup
	super()

## Getter methods for kill tracking integration
func get_holder_id() -> int:
	if holder and holder.player_data:
		return holder.player_data.player_id
	return thrown_by_id if thrown_by_id != -1 else -1

func get_weapon_name() -> String:
	return item_name

 
