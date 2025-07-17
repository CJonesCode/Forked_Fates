class_name MinigameFactory
extends RefCounted

enum MinigameCategory {
	PHYSICS,
	UI,
	TURN_BASED,
	PUZZLE,
	RACING,
	COMBAT
}

# Static factory methods for minigame creation
static func create_minigame(minigame_id: String, context: MinigameContext) -> BaseMinigame:
	var minigame_config: MinigameConfig = _load_minigame_config(minigame_id)
	if not minigame_config:
		Logger.error("Failed to load minigame config for: " + minigame_id)
		return null
	
	var minigame: BaseMinigame = minigame_config.minigame_scene.instantiate()
	if minigame:
		_configure_minigame(minigame, minigame_config, context)
	
	return minigame

static func create_minigame_from_config(config: MinigameConfig, context: MinigameContext) -> BaseMinigame:
	if not config:
		return null
	
	var minigame: BaseMinigame = config.minigame_scene.instantiate()
	if minigame:
		_configure_minigame(minigame, config, context)
	
	return minigame

static func get_available_minigames() -> Array[MinigameConfig]:
	var minigames: Array[MinigameConfig] = []
	var config_dir: DirAccess = DirAccess.open("res://configs/minigame_configs/")
	
	if config_dir:
		config_dir.list_dir_begin()
		var file_name: String = config_dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var config: MinigameConfig = load("res://configs/minigame_configs/" + file_name) as MinigameConfig
				if config:
					minigames.append(config)
			file_name = config_dir.get_next()
	
	return minigames

static func get_minigames_by_category(category: MinigameCategory) -> Array[MinigameConfig]:
	var all_minigames: Array[MinigameConfig] = get_available_minigames()
	var filtered_minigames: Array[MinigameConfig] = []
	
	for config in all_minigames:
		if config.category == category:
			filtered_minigames.append(config)
	
	return filtered_minigames

static func get_minigames_for_player_count(player_count: int) -> Array[MinigameConfig]:
	var all_minigames: Array[MinigameConfig] = get_available_minigames()
	var suitable_minigames: Array[MinigameConfig] = []
	
	for config in all_minigames:
		if player_count >= config.min_players and player_count <= config.max_players:
			suitable_minigames.append(config)
	
	return suitable_minigames

static func create_standard_managers(minigame: BaseMinigame, config: MinigameConfig, context: MinigameContext) -> void:
	if not minigame or not config:
		return
	
	# Create player spawner if needed
	if config.needs_player_spawner:
		var player_spawner: PlayerSpawner = preload("res://scripts/minigames/core/standard_managers/player_spawner.gd").new()
		player_spawner.name = "PlayerSpawner"
		minigame.add_child(player_spawner)
		player_spawner.setup_for_minigame(context)
	
	# Create item spawner if needed
	if config.needs_item_spawner:
		var item_spawner: ItemSpawner = preload("res://scripts/minigames/core/standard_managers/item_spawner.gd").new()
		item_spawner.name = "ItemSpawner"
		minigame.add_child(item_spawner)
		item_spawner.setup_for_minigame(config.item_spawn_settings)
	
	# Create victory condition manager if needed
	if config.needs_victory_manager:
		var victory_manager: VictoryConditionManager = preload("res://scripts/minigames/core/standard_managers/victory_condition_manager.gd").new()
		victory_manager.name = "VictoryConditionManager"
		minigame.add_child(victory_manager)
		victory_manager.setup_victory_conditions(config.victory_conditions)
	
	# Create respawn manager if needed
	if config.needs_respawn_manager:
		var respawn_manager: RespawnManager = preload("res://scripts/minigames/core/standard_managers/respawn_manager.gd").new()
		respawn_manager.name = "RespawnManager"
		minigame.add_child(respawn_manager)
		respawn_manager.setup_respawn_settings(config.respawn_settings)

static func _load_minigame_config(minigame_id: String) -> MinigameConfig:
	var config_path: String = "res://configs/minigame_configs/" + minigame_id + ".tres"
	return load(config_path) as MinigameConfig

static func _configure_minigame(minigame: BaseMinigame, config: MinigameConfig, context: MinigameContext) -> void:
	if not minigame or not config:
		return
	
	# Set basic minigame properties
	minigame.minigame_name = config.minigame_name
	minigame.max_players = config.max_players
	minigame.min_players = config.min_players
	
	# Apply configuration settings
	if minigame.has_method("set_time_limit"):
		minigame.set_time_limit(config.time_limit)
	
	if minigame.has_method("set_difficulty"):
		minigame.set_difficulty(config.difficulty)
	
	# Create standard managers if specified
	create_standard_managers(minigame, config, context)
	
	# Initialize with context
	minigame.initialize_minigame(context)

# Item spawning configuration
class ItemSpawnSettings extends Resource:
@export var spawn_rate: float = 3.0
@export var max_items: int = 10
@export var spawn_areas: Array[Vector2] = []
@export var item_types: Array[String] = []
@export var random_spawn: bool = true

# Victory condition configuration
class VictoryConditions extends Resource:
enum VictoryType {
	ELIMINATION,
	SCORE,
	SURVIVAL,
	OBJECTIVE,
	TIME
}

@export var victory_type: VictoryType = VictoryType.ELIMINATION
@export var target_score: int = 10
@export var survival_time: float = 30.0
@export var allow_draws: bool = false

# Respawn configuration
class RespawnSettings extends Resource:
@export var respawn_enabled: bool = true
@export var respawn_delay: float = 3.0
@export var max_respawns: int = -1  # -1 for unlimited
@export var respawn_areas: Array[Vector2] = []
@export var invincibility_time: float = 2.0 