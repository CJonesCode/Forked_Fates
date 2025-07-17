class_name Logger
extends RefCounted

## Structured logging utility for Forked Fates
## Replaces print() calls with build-flag-gated logging system
## Provides different log levels and formatted output

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	NONE = 4  # Disable all logging
}

# Configuration - can be changed based on build type
static var current_log_level: LogLevel = LogLevel.DEBUG if OS.is_debug_build() else LogLevel.INFO
static var log_to_file: bool = false
static var log_file_path: String = "user://forked_fates.log"
static var include_timestamps: bool = true
static var include_calling_script: bool = true

# Color codes for console output
static var level_colors: Dictionary = {
	LogLevel.DEBUG: "[color=gray]",
	LogLevel.INFO: "[color=white]",
	LogLevel.WARNING: "[color=yellow]",
	LogLevel.ERROR: "[color=red]"
}

## Log a debug message (only in debug builds by default)
static func debug(message: String, source: String = "") -> void:
	_log(LogLevel.DEBUG, message, source)

## Log an info message
static func info(message: String, source: String = "") -> void:
	_log(LogLevel.INFO, message, source)

## Log a warning message
static func warning(message: String, source: String = "") -> void:
	_log(LogLevel.WARNING, message, source)

## Log an error message
static func error(message: String, source: String = "") -> void:
	_log(LogLevel.ERROR, message, source)

## Log player-specific events
static func player(player_name: String, message: String, source: String = "") -> void:
	_log(LogLevel.INFO, "👤 " + player_name + ": " + message, source)

## Log item-related events
static func item(item_name: String, message: String, source: String = "") -> void:
	_log(LogLevel.INFO, "📦 " + item_name + ": " + message, source)

## Log combat/damage events
static func combat(message: String, source: String = "") -> void:
	_log(LogLevel.INFO, "⚔️ " + message, source)

## Log system/game state events
static func system(message: String, source: String = "") -> void:
	_log(LogLevel.INFO, "🔧 " + message, source)

## Log pickup/interaction events  
static func pickup(message: String, source: String = "") -> void:
	_log(LogLevel.DEBUG, "🎯 " + message, source)

## Log game flow events (minigames, transitions, etc.)
static func game_flow(message: String, source: String = "") -> void:
	_log(LogLevel.INFO, "🎮 " + message, source)

## Internal logging function
static func _log(level: LogLevel, message: String, source: String = "") -> void:
	# Check if we should log this level
	if level < current_log_level:
		return
	
	# Build the log message
	var formatted_message: String = ""
	
	# Add timestamp if enabled
	if include_timestamps:
		var time: Dictionary = Time.get_datetime_dict_from_system()
		formatted_message += "[%02d:%02d:%02d] " % [time.hour, time.minute, time.second]
	
	# Add log level
	var level_name: String = LogLevel.keys()[level]
	formatted_message += "[" + level_name + "] "
	
	# Add source if provided and enabled
	if include_calling_script and source != "":
		formatted_message += "[" + source + "] "
	
	# Add the actual message
	formatted_message += message
	
	# Output to console
	print(formatted_message)
	
	# Output to file if enabled
	if log_to_file:
		_write_to_file(formatted_message)

## Write log message to file
static func _write_to_file(message: String) -> void:
	var file: FileAccess = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		file.store_line(message)
		file.close()
	else:
		print("ERROR: Could not write to log file: ", log_file_path)

## Set the minimum log level
static func set_log_level(level: LogLevel) -> void:
	current_log_level = level
	info("Log level set to: " + LogLevel.keys()[level], "Logger")

## Enable/disable file logging
static func set_file_logging(enabled: bool, file_path: String = "") -> void:
	log_to_file = enabled
	if file_path != "":
		log_file_path = file_path
	info("File logging " + ("enabled" if enabled else "disabled") + (" to: " + log_file_path if enabled else ""), "Logger")

## Clear the log file
static func clear_log_file() -> void:
	if FileAccess.file_exists(log_file_path):
		var file: FileAccess = FileAccess.open(log_file_path, FileAccess.WRITE)
		if file:
			file.store_string("")  # Clear the file
			file.close()
			info("Log file cleared", "Logger") 