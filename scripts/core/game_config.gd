class_name GameConfig
extends Resource

## Centralized game configuration resource
## Contains commonly used gameplay values to replace magic numbers

# Player Physics Constants
@export_group("Player Physics")
@export var default_move_speed: float = 300.0
@export var default_jump_velocity: float = -400.0
@export var default_gravity: float = 980.0
@export var ragdoll_force_threshold: float = 500.0
@export var ragdoll_recovery_time: float = 2.0
@export var ragdoll_gravity_scale: float = 2.0
@export var ragdoll_mass: float = 1.0
@export var ragdoll_linear_damp: float = 3.0  # Increased from 2.0 - much more velocity damping
@export var ragdoll_angular_damp: float = 4.0  # Increased from 3.0 - even less spinning
# TODO: Add "Super Bouncy" passive that increases bounce to 0.8+ and reduces damping for chaos!

# Item System Constants
@export_group("Item System")
@export var item_pickup_disable_time: float = 0.2
@export var item_hold_offset: Vector2 = Vector2(30, -10)
@export var item_drop_upward_force: float = 100.0
@export var item_velocity_inheritance: float = 0.5
@export var pickup_area_radius: float = 50.0

# Weapon Constants
@export_group("Weapons")
@export var default_bullet_speed: float = 800.0
@export var default_recoil_force: float = 100.0
@export var default_weapon_cooldown: float = 0.3

# Audio/Visual Constants
@export_group("Effects")
@export var screen_shake_intensity: float = 5.0
@export var damage_flash_duration: float = 0.2
@export var muzzle_flash_duration: float = 0.1

# UI Constants
@export_group("User Interface")
@export var health_bar_update_speed: float = 2.0
@export var ui_fade_duration: float = 0.3

# Create a singleton instance
static var instance: GameConfig = null

## Get the singleton instance, creating it if necessary
static func get_instance() -> GameConfig:
	if not instance:
		instance = GameConfig.new()
		_setup_default_values(instance)
	return instance

## Setup default values for the configuration
static func _setup_default_values(config: GameConfig) -> void:
	# Values are already set via @export defaults above
	# This method can be used for any complex initialization if needed
	pass

## Load configuration from a file (for customization/modding)
static func load_from_file(path: String) -> GameConfig:
	if ResourceLoader.exists(path):
		var loaded_config = ResourceLoader.load(path) as GameConfig
		if loaded_config:
			instance = loaded_config
			return loaded_config
	
	# Fallback to default if file doesn't exist or failed to load
	return get_instance()

## Save current configuration to a file
func save_to_file(path: String) -> bool:
	var result = ResourceSaver.save(self, path)
	return result == OK 