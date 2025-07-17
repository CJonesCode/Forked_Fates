extends Node

# Preload config classes to ensure they're registered
const PlayerConfigClass = preload("res://configs/player_configs/player_config.gd")
const ItemConfigClass = preload("res://configs/item_configs/item_config.gd")
const MinigameConfigClass = preload("res://configs/minigame_configs/minigame_config.gd")

# Configuration cache
var player_configs: Dictionary = {}
var item_configs: Dictionary = {}
var minigame_configs: Dictionary = {}
var ui_configs: Dictionary = {}

# Configuration directories
const PLAYER_CONFIG_DIR: String = "res://configs/player_configs/"
const ITEM_CONFIG_DIR: String = "res://configs/item_configs/"
const MINIGAME_CONFIG_DIR: String = "res://configs/minigame_configs/"
const UI_CONFIG_DIR: String = "res://configs/ui_configs/"

# Signals for configuration events
signal configs_loaded()
signal config_reloaded(config_type: String, config_id: String)
signal config_load_error(config_path: String, error: String)

func _ready() -> void:
	_load_all_configs()

# Player configuration management
func get_player_config(config_id: String) -> PlayerConfig:
	if player_configs.has(config_id):
		return player_configs[config_id]

	var config_path: String = PLAYER_CONFIG_DIR + config_id + ".tres"
	if not ResourceLoader.exists(config_path):
		Logger.warning("Player config not found: " + config_id, "ConfigManager")
		return null
	
	var config: PlayerConfig = load(config_path) as PlayerConfig
	if config:
		player_configs[config_id] = config
		config_reloaded.emit("player", config_id)
		Logger.info("Player config loaded: " + config_id, "ConfigManager")
	else:
		Logger.error("Failed to load player config: " + config_id, "ConfigManager")
	
	return config

func invalidate_player_config(config_id: String) -> void:
	if player_configs.has(config_id):
		player_configs.erase(config_id)

# Item configuration management
func get_item_config(config_id: String) -> ItemConfig:
	if item_configs.has(config_id):
		return item_configs[config_id]

	var config_path: String = ITEM_CONFIG_DIR + config_id + ".tres"
	if not ResourceLoader.exists(config_path):
		Logger.warning("Item config not found: " + config_id, "ConfigManager")
		return null
	
	var config: ItemConfig = load(config_path) as ItemConfig
	if config:
		item_configs[config_id] = config
		config_reloaded.emit("item", config_id)
		Logger.info("Item config loaded: " + config_id, "ConfigManager")
	else:
		Logger.error("Failed to load item config: " + config_id, "ConfigManager")
	
	return config

func invalidate_item_config(config_id: String) -> void:
	if item_configs.has(config_id):
		item_configs.erase(config_id)

# Minigame configuration management
func get_minigame_config(config_id: String) -> MinigameConfig:
	if minigame_configs.has(config_id):
		return minigame_configs[config_id]

	var config_path: String = MINIGAME_CONFIG_DIR + config_id + ".tres"
	if not ResourceLoader.exists(config_path):
		Logger.warning("Minigame config not found: " + config_id, "ConfigManager")
		return null
	
	var config: MinigameConfig = load(config_path) as MinigameConfig
	if config:
		minigame_configs[config_id] = config
		config_reloaded.emit("minigame", config_id)
		Logger.info("Minigame config loaded: " + config_id, "ConfigManager")
	else:
		Logger.error("Failed to load minigame config: " + config_id, "ConfigManager")
	
	return config

func invalidate_minigame_config(config_id: String) -> void:
	if minigame_configs.has(config_id):
		minigame_configs.erase(config_id)

func invalidate_all_configs() -> void:
	player_configs.clear()
	item_configs.clear()
	minigame_configs.clear()
	ui_configs.clear()

# UI configuration management
func get_ui_config(config_type: String, config_id: String) -> Resource:
	var config_key: String = config_type + "/" + config_id
	if ui_configs.has(config_key):
		return ui_configs[config_key]

	var config_path: String = UI_CONFIG_DIR + config_type + "/" + config_id + ".tres"
	if not ResourceLoader.exists(config_path):
		Logger.warning("UI config not found: " + config_key, "ConfigManager")
		return null
	
	var config: Resource = load(config_path)
	if config:
		ui_configs[config_key] = config
		config_reloaded.emit("ui_" + config_type, config_id)
		Logger.info("UI config loaded: " + config_key, "ConfigManager")
	else:
		Logger.error("Failed to load UI config: " + config_type + "/" + config_id, "ConfigManager")
	
	return config

# Configuration validation
func validate_player_config(config_id: String) -> bool:
	var config: PlayerConfig = get_player_config(config_id)
	if not config or not config.player_scene:
		Logger.error("Invalid player config: " + config_id, "ConfigManager")
		return false
	return true

func validate_item_config(config_id: String) -> bool:
	var config: ItemConfig = get_item_config(config_id)
	if not config or not config.item_scene:
		Logger.error("Invalid item config: " + config_id, "ConfigManager")
		return false
	return true

func validate_minigame_config(config_id: String) -> bool:
	var config: MinigameConfig = get_minigame_config(config_id)
	if not config or not config.minigame_scene:
		Logger.error("Invalid minigame config: " + config_id, "ConfigManager")
		return false
	return true

# Configuration reloading
func reload_config(config_type: String, config_id: String = "") -> void:
	match config_type:
		"player":
			if config_id.is_empty():
				player_configs.clear()
				_load_player_configs()
			else:
				invalidate_player_config(config_id)
		"item":
			if config_id.is_empty():
				item_configs.clear()
				_load_item_configs()
			else:
				invalidate_item_config(config_id)
		"minigame":
			if config_id.is_empty():
				minigame_configs.clear()
				_load_minigame_configs()
			else:
				invalidate_minigame_config(config_id)
		"ui":
			if config_id.is_empty():
				Logger.warning("UI config reloading requires sub-type specification", "ConfigManager")
			else:
				_reload_ui_config(config_id)
		_:
			Logger.error("Unknown config type: " + config_type, "ConfigManager")
	
	config_reloaded.emit(config_type, config_id)
	
func _reload_ui_config(sub_type: String) -> void:
	# Clear all UI configs of this sub-type
	var keys_to_remove: Array[String] = []
	for key in ui_configs.keys():
		if key.begins_with(sub_type + "/"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		ui_configs.erase(key)
	
	# Reload UI configs for this sub-type
	_load_ui_configs_for_type(sub_type)

# Get all available configurations
func get_available_player_configs() -> Array[String]:
	return _get_config_files_in_directory(PLAYER_CONFIG_DIR)

func get_available_item_configs() -> Array[String]:
	return _get_config_files_in_directory(ITEM_CONFIG_DIR)

func get_available_minigame_configs() -> Array[String]:
	return _get_config_files_in_directory(MINIGAME_CONFIG_DIR)

func get_available_ui_configs(sub_type: String) -> Array[String]:
	return _get_config_files_in_directory(UI_CONFIG_DIR + sub_type + "/")

# Configuration management
func _load_all_configs() -> void:
	_load_player_configs()
	_load_item_configs()
	_load_minigame_configs()
	_load_ui_configs()
	Logger.info("All configurations loaded", "ConfigManager")

func _get_config_files_in_directory(directory: String) -> Array[String]:
	var configs: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	
	if not dir:
		Logger.warning("Cannot open config directory: " + directory, "ConfigManager")
		return configs
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			configs.append(file_name.get_basename())
		file_name = dir.get_next()

	return configs

func _load_configs_from_directory(directory: String, config_type: String) -> Dictionary:
	var configs: Dictionary = {}
	var config_files: Array[String] = _get_config_files_in_directory(directory)
	
	for config_id in config_files:
		var config_path: String = directory + config_id + ".tres"
		
		# Check if file exists first
		if not FileAccess.file_exists(config_path):
			Logger.error("Config file does not exist: " + config_path, "ConfigManager")
			continue
			
		var config: Resource = load(config_path)
		if config:
			configs[config_id] = config
			Logger.info(config_type + " config loaded successfully: " + config_id, "ConfigManager")
		else:
			# Try to get more specific error information
			var resource_loader = ResourceLoader
			if resource_loader.exists(config_path):
				Logger.error("Resource exists but failed to load " + config_type + " config: " + config_id + " at path: " + config_path, "ConfigManager")
				# Try loading with explicit type checking
				var test_load = ResourceLoader.load(config_path, "", ResourceLoader.CACHE_MODE_IGNORE)
				Logger.error("Direct ResourceLoader result: " + str(test_load), "ConfigManager")
			else:
				Logger.error("Resource file does not exist: " + config_path, "ConfigManager")
	
	return configs

func _load_ui_configs_for_type(sub_type: String) -> void:
	var directory: String = UI_CONFIG_DIR + sub_type + "/"
	var dir: DirAccess = DirAccess.open(directory)
	
	if not dir:
		Logger.warning("Cannot open UI config subdirectory: " + directory, "ConfigManager")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var config_id: String = file_name.get_basename()
			var config_path: String = directory + file_name
			var config: Resource = load(config_path)
			if config:
				var config_key: String = sub_type + "/" + config_id
				ui_configs[config_key] = config
				Logger.info("UI config loaded: " + config_key, "ConfigManager")
			else:
				Logger.error("Failed to load UI config: " + sub_type + "/" + config_id, "ConfigManager")
		file_name = dir.get_next()

func has_config(config_path: String) -> bool:
	if not ResourceLoader.exists(config_path):
		Logger.warning("Config file not found: " + config_path, "ConfigManager")
		return false
	
	var config: Resource = load(config_path)
	if not config:
		Logger.error("Failed to load config file: " + config_path, "ConfigManager")
		return false
	
	return true

func _load_player_configs() -> void:
	Logger.info("Starting player config loading...", "ConfigManager")
	player_configs = _load_configs_from_directory(PLAYER_CONFIG_DIR, "Player")
	Logger.info("Player configs loaded: " + str(player_configs.size()) + " configs", "ConfigManager")

func _load_item_configs() -> void:
	Logger.info("Starting item config loading...", "ConfigManager")
	item_configs = _load_configs_from_directory(ITEM_CONFIG_DIR, "Item")
	Logger.info("Item configs loaded: " + str(item_configs.size()) + " configs", "ConfigManager")

func _load_minigame_configs() -> void:
	Logger.info("Starting minigame config loading...", "ConfigManager")
	minigame_configs = _load_configs_from_directory(MINIGAME_CONFIG_DIR, "Minigame")
	Logger.info("Minigame configs loaded: " + str(minigame_configs.size()) + " configs", "ConfigManager")

func _load_ui_configs() -> void:
	# Load all UI config sub-types
	var ui_subdirs: Array[String] = ["hud", "menus", "dialogs", "notifications"]
	for subdir in ui_subdirs:
		_load_ui_configs_for_type(subdir)

# Configuration hot-reloading (for development)
func enable_hot_reloading() -> bool:
	# TODO: Implement file watcher for automatic config reloading
		return false
	
# Configuration import/export
func export_config(config_type: String, config_id: String, export_path: String) -> bool:
	# TODO: Implement configuration export
		return false
	
func import_config(config_path: String, config_type: String) -> bool:
	# TODO: Implement configuration import
	Logger.info("Config import not yet implemented for type: " + config_type, "ConfigManager")
	return false

# Configuration caching
func clear_cache() -> void:
	invalidate_all_configs()

func get_cache_size() -> int:
	return player_configs.size() + item_configs.size() + minigame_configs.size() + ui_configs.size()

func get_cache_stats() -> Dictionary:
	return {
		"player_configs": player_configs.size(),
		"item_configs": item_configs.size(),
		"minigame_configs": minigame_configs.size(),
		"ui_configs": ui_configs.size(),
		"total": get_cache_size()
	} 
