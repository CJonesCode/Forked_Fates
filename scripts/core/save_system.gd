extends RefCounted

# Import data structures
const SessionData = preload("res://scripts/core/data_structures/session_data.gd")
const SessionConfig = preload("res://scripts/core/data_structures/session_config.gd")
const GameSettings = preload("res://scripts/core/data_structures/game_settings.gd")
const SaveData = preload("res://scripts/core/data_structures/save_data.gd")
const PlayerStatistics = preload("res://scripts/core/data_structures/player_statistics.gd")

# Save file paths and configuration
const SAVE_DIRECTORY: String = "user://saves/"
const SETTINGS_FILE: String = "user://settings.tres"
const STATISTICS_DIRECTORY: String = "user://statistics/"
const SESSION_DIRECTORY: String = "user://sessions/"
const BACKUP_DIRECTORY: String = "user://backups/"

const SAVE_VERSION: String = "1.0"
const MAX_BACKUPS: int = 5
const MAX_SAVES: int = 20

# Signals for save/load events
signal save_operation_completed(success: bool, file_path: String)
signal load_operation_completed(success: bool, file_path: String)
signal save_validation_failed(file_path: String, error: String)

func _init() -> void:
	_ensure_directories_exist()

# Game data save/load
func save_game_data(save_data) -> bool:
	if not save_data:
		Logger.error("Cannot save null save data")
		return false
	
	var save_path: String = _get_save_path(save_data.save_name)
	
	# Create backup of existing save if it exists
	if FileAccess.file_exists(save_path):
		_create_backup(save_path, save_data.save_name)
	
	# Validate save data before saving
	if not _validate_save_data(save_data):
		Logger.error("Save data validation failed for: " + save_data.save_name)
		return false
	
	# Save the data
	var error: Error = ResourceSaver.save(save_data, save_path)
	var success: bool = error == OK
	
	if success:
		Logger.info("Game saved successfully: " + save_path)
	else:
		Logger.error("Failed to save game: " + error_string(error))
	
	save_operation_completed.emit(success, save_path)
	return success

func load_game_data(save_name: String):
	var save_path: String = _get_save_path(save_name)
	
	if not FileAccess.file_exists(save_path):
		Logger.error("Save file not found: " + save_path)
		return null
	
	var save_data = load(save_path) as SaveData
	
	if not save_data:
		Logger.error("Failed to load save data from: " + save_path)
		load_operation_completed.emit(false, save_path)
		return null
	
	# Validate loaded data
	if not _validate_save_data(save_data):
		Logger.error("Loaded save data validation failed: " + save_name)
		save_validation_failed.emit(save_path, "Data validation failed")
		return null
	
	# Check version compatibility
	if not _is_version_compatible(save_data.game_version):
		Logger.warning("Save version mismatch: " + save_data.game_version + " vs " + SAVE_VERSION)
		# Could implement migration logic here
	
	Logger.info("Game loaded successfully: " + save_path)
	load_operation_completed.emit(true, save_path)
	return save_data

func get_save_list() -> Array[String]:
	var save_names: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIRECTORY)
	
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var save_name: String = file_name.get_basename()
				save_names.append(save_name)
			file_name = dir.get_next()
	
	return save_names

func delete_save(save_name: String) -> bool:
	var save_path: String = _get_save_path(save_name)
	
	if not FileAccess.file_exists(save_path):
		Logger.warning("Cannot delete non-existent save: " + save_name)
		return false
	
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.remove(save_path)
	
	if error == OK:
		Logger.info("Save deleted: " + save_name)
		return true
	else:
		Logger.error("Failed to delete save: " + error_string(error))
		return false

# Settings save/load
func save_settings(settings) -> bool:
	if not settings:
		Logger.error("Cannot save null settings")
		return false
	
	var error: Error = ResourceSaver.save(settings, SETTINGS_FILE)
	var success: bool = error == OK
	
	if success:
		Logger.info("Settings saved successfully")
	else:
		Logger.error("Failed to save settings: " + error_string(error))
	
	return success

func load_settings():
	if not FileAccess.file_exists(SETTINGS_FILE):
		Logger.info("No settings file found, using defaults")
		return null
	
	var settings = load(SETTINGS_FILE) as GameSettings
	
	if settings:
		Logger.info("Settings loaded successfully")
	else:
		Logger.error("Failed to load settings")
	
	return settings

# Player statistics save/load
func save_player_statistics(player_id: int, stats) -> bool:
	if not stats:
		Logger.error("Cannot save null statistics")
		return false
	
	var stats_path: String = _get_statistics_path(player_id)
	var error: Error = ResourceSaver.save(stats, stats_path)
	var success: bool = error == OK
	
	if success:
		Logger.info("Player statistics saved: " + str(player_id))
	else:
		Logger.error("Failed to save player statistics: " + error_string(error))
	
	return success

func load_player_statistics(player_id: int):
	var stats_path: String = _get_statistics_path(player_id)
	
	if not FileAccess.file_exists(stats_path):
		# Return new stats if none exist
		var new_stats = PlayerStatistics.new()
		new_stats.player_id = player_id
		return new_stats
	
	var stats = load(stats_path) as PlayerStatistics
	
	if stats:
		Logger.info("Player statistics loaded: " + str(player_id))
	else:
		Logger.error("Failed to load player statistics for: " + str(player_id))
		# Return new stats as fallback
		var fallback_stats = PlayerStatistics.new()
		fallback_stats.player_id = player_id
		return fallback_stats
	
	return stats

# Session data save/load
func save_session_data(session_data) -> bool:
	if not session_data:
		Logger.error("Cannot save null session data")
		return false
	
	var session_path: String = _get_session_path(session_data.session_id)
	var error: Error = ResourceSaver.save(session_data, session_path)
	var success: bool = error == OK
	
	if success:
		Logger.info("Session data saved: " + str(session_data.session_id))
	else:
		Logger.error("Failed to save session data: " + error_string(error))
	
	return success

# Auto-save functionality
func auto_save_player_data(player_id: int, data: PlayerData) -> void:
	var autosave_path: String = "user://autosave_player_" + str(player_id) + ".tres"
	var error: Error = ResourceSaver.save(data, autosave_path)
	
	if error != OK:
		Logger.error("Auto-save failed for player " + str(player_id) + ": " + error_string(error))

# Backup and recovery
func create_save_backup(save_name: String) -> bool:
	var save_path: String = _get_save_path(save_name)
	if not FileAccess.file_exists(save_path):
		return false
	
	return _create_backup(save_path, save_name)

func restore_save_backup(save_name: String, backup_index: int = 0) -> bool:
	var backup_path: String = _get_backup_path(save_name, backup_index)
	var save_path: String = _get_save_path(save_name)
	
	if not FileAccess.file_exists(backup_path):
		Logger.error("Backup not found: " + backup_path)
		return false
	
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.copy(backup_path, save_path)
	
	if error == OK:
		Logger.info("Save restored from backup: " + save_name)
		return true
	else:
		Logger.error("Failed to restore backup: " + error_string(error))
		return false

# Private helper methods
func _ensure_directories_exist() -> void:
	var directories: Array[String] = [
		SAVE_DIRECTORY,
		STATISTICS_DIRECTORY,
		SESSION_DIRECTORY,
		BACKUP_DIRECTORY
	]
	
	for directory in directories:
		if not DirAccess.dir_exists_absolute(directory):
			DirAccess.make_dir_recursive_absolute(directory)

func _get_save_path(save_name: String) -> String:
	return SAVE_DIRECTORY + save_name + ".tres"

func _get_statistics_path(player_id: int) -> String:
	return STATISTICS_DIRECTORY + "player_" + str(player_id) + ".tres"

func _get_session_path(session_id: int) -> String:
	return SESSION_DIRECTORY + "session_" + str(session_id) + ".tres"

func _get_backup_path(save_name: String, backup_index: int) -> String:
	return BACKUP_DIRECTORY + save_name + "_backup_" + str(backup_index) + ".tres"

func _validate_save_data(save_data) -> bool:
	if not save_data:
		return false
	
	# Check required fields
	if save_data.save_name.is_empty():
		Logger.error("Save data missing save name")
		return false
	
	if not save_data.game_settings:
		Logger.error("Save data missing game settings")
		return false
	
	# Validate player registry
	if save_data.player_registry.is_empty():
		Logger.warning("Save data has empty player registry")
	
	# Additional validation logic can be added here
	return true

func _is_version_compatible(save_version: String) -> bool:
	# Simple version check - could be more sophisticated
	return save_version == SAVE_VERSION

func _create_backup(source_path: String, save_name: String) -> bool:
	# Find the next available backup slot
	var backup_index: int = 0
	while backup_index < MAX_BACKUPS:
		var backup_path: String = _get_backup_path(save_name, backup_index)
		if not FileAccess.file_exists(backup_path):
			break
		backup_index += 1
	
	# If all backup slots are full, overwrite the oldest
	if backup_index >= MAX_BACKUPS:
		backup_index = 0
	
	var final_backup_path: String = _get_backup_path(save_name, backup_index)
	var dir: DirAccess = DirAccess.open("user://")
	var error: Error = dir.copy(source_path, final_backup_path)
	
	if error == OK:
		Logger.info("Backup created: " + final_backup_path)
		return true
	else:
		Logger.error("Failed to create backup: " + error_string(error))
		return false 
