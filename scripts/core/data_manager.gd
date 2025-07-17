extends Node

# Import SaveSystem and data structures
const SaveSystem = preload("res://scripts/core/save_system.gd")
const SessionData = preload("res://scripts/core/data_structures/session_data.gd")
const SessionConfig = preload("res://scripts/core/data_structures/session_config.gd")
const GameSettings = preload("res://scripts/core/data_structures/game_settings.gd")
const SaveData = preload("res://scripts/core/data_structures/save_data.gd")
const PlayerStatistics = preload("res://scripts/core/data_structures/player_statistics.gd")

# Data storage
var session_data
var player_registry: Dictionary = {}
var game_settings
var save_system

# Signals for data events
signal data_saved(save_name: String)
signal data_loaded(save_name: String)
signal player_data_updated(player_id: int, data: PlayerData)
signal settings_changed(settings)
signal session_started(session)
signal session_ended()

func _ready() -> void:
	_initialize_data_systems()
	_load_default_settings()

func _initialize_data_systems() -> void:
	save_system = SaveSystem.new()
	game_settings = GameSettings.new()
	session_data = SessionData.new()

# Player data management
func get_player_data(player_id: int) -> PlayerData:
	if player_registry.has(player_id):
		return player_registry[player_id]
	else:
		Logger.warning("Player data not found for ID: " + str(player_id), "DataManager")
		return PlayerData.new()

func update_player_data(player_id: int, data: PlayerData) -> void:
	if not data:
		Logger.error("Attempted to update player with null data", "DataManager")
		return
	
	player_registry[player_id] = data
	player_data_updated.emit(player_id, data)
	
	# Auto-save if enabled
	if game_settings.auto_save_enabled:
		_auto_save_player_data(player_id, data)

func register_player(player_data: PlayerData) -> bool:
	if not player_data:
		Logger.error("Cannot register null player data", "DataManager")
		return false
	
	if player_registry.has(player_data.player_id):
		Logger.warning("Player ID already registered: " + str(player_data.player_id), "DataManager")
		return false
	
	player_registry[player_data.player_id] = player_data
	Logger.info("Player registered: " + player_data.player_name, "DataManager")
	return true

func unregister_player(player_id: int) -> void:
	if player_registry.has(player_id):
		var player_data: PlayerData = player_registry[player_id]
		player_registry.erase(player_id)
		Logger.info("Player unregistered: " + player_data.player_name, "DataManager")

func get_all_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	for player_data in player_registry.values():
		players.append(player_data)
	return players

func get_player_count() -> int:
	return player_registry.size()

# Session management
func start_new_session(session_config: SessionConfig) -> void:
	session_data = SessionData.new()
	session_data.session_id = Time.get_unix_time_from_system()
	session_data.start_time = Time.get_datetime_dict_from_system()
	session_data.player_count = get_player_count()
	session_data.config = session_config
	
	Logger.info("New session started: " + str(session_data.session_id), "DataManager")
	session_started.emit(session_data)

func end_current_session() -> void:
	if session_data:
		session_data.end_time = Time.get_datetime_dict_from_system()
		session_data.duration = Time.get_unix_time_from_system() - session_data.session_id
		
		# Save session data for statistics
		save_system.save_session_data(session_data)
		
		Logger.info("Session ended: " + str(session_data.session_id), "DataManager")
		session_ended.emit()
		
		session_data = null

func get_current_session():
	return session_data

# Settings management
func update_settings(new_settings) -> void:
	if not new_settings:
		Logger.error("Cannot update with null settings", "DataManager")
		return
	
	game_settings = new_settings
	settings_changed.emit(game_settings)
	
	# Save settings immediately
	save_system.save_settings(game_settings)

func get_settings():
	return game_settings

# Save/Load operations
func save_game(save_name: String) -> bool:
	var save_data = SaveData.new()
	save_data.save_name = save_name
	save_data.save_time = Time.get_datetime_dict_from_system()
	save_data.player_registry = player_registry.duplicate(true)
	save_data.session_data = session_data
	save_data.game_settings = game_settings
	
	var success: bool = save_system.save_game_data(save_data)
	if success:
		data_saved.emit(save_name)
		Logger.info("Game saved: " + save_name, "DataManager")
	else:
		Logger.error("Failed to save game: " + save_name, "DataManager")
	
	return success

func load_game(save_name: String) -> bool:
	var save_data = save_system.load_game_data(save_name)
	if not save_data:
		Logger.error("Failed to load game: " + save_name, "DataManager")
		return false
	
	# Restore data
	player_registry = save_data.player_registry
	session_data = save_data.session_data
	game_settings = save_data.game_settings
	
	data_loaded.emit(save_name)
	Logger.info("Game loaded: " + save_name, "DataManager")
	return true

func get_available_saves() -> Array[String]:
	return save_system.get_save_list()

func delete_save(save_name: String) -> bool:
	return save_system.delete_save(save_name)

# Statistics and analytics
func get_player_statistics(player_id: int):
	var player_data: PlayerData = get_player_data(player_id)
	if not player_data:
		return null
	
	return save_system.load_player_statistics(player_id)

func update_player_statistics(player_id: int, stats) -> void:
	if stats:
		save_system.save_player_statistics(player_id, stats)

# Private methods
func _load_default_settings() -> void:
	var default_settings = save_system.load_settings()
	if default_settings:
		game_settings = default_settings
	else:
		game_settings = GameSettings.new()  # Use defaults
		save_system.save_settings(game_settings)

func _auto_save_player_data(player_id: int, data: PlayerData) -> void:
	# Implement auto-save logic for individual player data
	save_system.auto_save_player_data(player_id, data)

# Data structure definitions moved to separate files 