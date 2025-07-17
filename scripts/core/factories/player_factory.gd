class_name PlayerFactory
extends RefCounted

enum PlayerType {
	STANDARD,
	HEAVYWEIGHT,
	SPEEDSTER,
	TECHNICAL
}

# Static factory methods for player creation
static func create_player(player_type: PlayerType, player_data: PlayerData) -> BasePlayer:
	var player_scene: PackedScene = _get_player_scene(player_type)
	var player: BasePlayer = player_scene.instantiate()
	
	_configure_player(player, player_type, player_data)
	return player

static func create_player_with_config(config_path: String, player_data: PlayerData) -> BasePlayer:
	var config: PlayerConfig = load(config_path) as PlayerConfig
	if config == null:
		Logger.error("Failed to load player config: " + config_path, "PlayerFactory")
		return create_player(PlayerType.STANDARD, player_data)
	
	var player: BasePlayer = config.player_scene.instantiate()
	_apply_config_to_player(player, config, player_data)
	return player

static func _get_player_scene(player_type: PlayerType) -> PackedScene:
	# For now, all player types use the base player scene since specialized scenes don't exist yet
	# TODO: Create specialized player scenes for different types
			return preload("res://scenes/player/base_player.tscn")

static func _configure_player(player: BasePlayer, player_type: PlayerType, player_data: PlayerData) -> void:
	if not player:
		return
		
	# Set basic player data
	player.player_id = player_data.player_id
	player.player_name = player_data.player_name
	
	# Configure components based on player type
	var health_component: HealthComponent = player.get_component(HealthComponent)
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	
	if health_component:
		health_component.max_health = _get_health_for_type(player_type)
		health_component.current_health = health_component.max_health
	
	if movement_component:
		movement_component.movement_speed = _get_speed_for_type(player_type)
		movement_component.jump_velocity = _get_jump_for_type(player_type)

static func _apply_config_to_player(player: BasePlayer, config: PlayerConfig, player_data: PlayerData) -> void:
	if not player or not config:
		return
		
	player.player_id = player_data.player_id
	player.player_name = player_data.player_name
	
	# Apply configuration values
	var health_component: HealthComponent = player.get_component(HealthComponent)
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	
	if health_component and config.health_settings:
		health_component.max_health = config.health_settings.max_health
		health_component.current_health = health_component.max_health
	
	if movement_component and config.movement_settings:
		movement_component.movement_speed = config.movement_settings.speed
		movement_component.jump_velocity = config.movement_settings.jump_velocity

static func _get_health_for_type(player_type: PlayerType) -> int:
	match player_type:
		PlayerType.STANDARD:
			return 3
		PlayerType.HEAVYWEIGHT:
			return 5
		PlayerType.SPEEDSTER:
			return 2
		PlayerType.TECHNICAL:
			return 3
		_:
			return 3

static func _get_speed_for_type(player_type: PlayerType) -> float:
	match player_type:
		PlayerType.STANDARD:
			return 300.0
		PlayerType.HEAVYWEIGHT:
			return 200.0
		PlayerType.SPEEDSTER:
			return 450.0
		PlayerType.TECHNICAL:
			return 280.0
		_:
			return 300.0

static func _get_jump_for_type(player_type: PlayerType) -> float:
	match player_type:
		PlayerType.STANDARD:
			return -400.0
		PlayerType.HEAVYWEIGHT:
			return -350.0
		PlayerType.SPEEDSTER:
			return -450.0
		PlayerType.TECHNICAL:
			return -420.0
		_:
			return -400.0