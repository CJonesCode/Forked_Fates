class_name MinigameRegistry
extends Node

## Registry system for dynamic minigame discovery and management
## Handles minigame registration, launching, and lifecycle coordination

# Registered minigames
var registered_minigames: Dictionary = {}  # minigame_id -> MinigameInfo
var current_minigame: BaseMinigame = null
var minigame_history: Array[Dictionary] = []

# Signals
signal minigame_registered(minigame_id: String, info: MinigameInfo)
signal minigame_launched(minigame_id: String, minigame: BaseMinigame)
signal minigame_completed(minigame_id: String, result: MinigameResult)

## Minigame information structure
class MinigameInfo:
	var minigame_id: String
	var display_name: String
	var description: String
	var scene_path: String
	var minigame_type: String  # "physics", "ui", "turn_based"
	var min_players: int
	var max_players: int
	var estimated_duration: float
	var tags: Array[String] = []
	var enabled: bool = true
	
	func _init(id: String, name: String, path: String) -> void:
		minigame_id = id
		display_name = name
		scene_path = path

func _ready() -> void:
	Logger.system("MinigameRegistry ready", "MinigameRegistry")
	_discover_and_register_minigames()

## Register a minigame with the system
func register_minigame(info: MinigameInfo) -> void:
	if registered_minigames.has(info.minigame_id):
		Logger.warning("Minigame already registered: " + info.minigame_id, "MinigameRegistry")
		return
	
	registered_minigames[info.minigame_id] = info
	Logger.system("Registered minigame: " + info.display_name + " (" + info.minigame_id + ")", "MinigameRegistry")
	minigame_registered.emit(info.minigame_id, info)

## Launch a minigame by ID
func launch_minigame(minigame_id: String, context: MinigameContext) -> BaseMinigame:
	if not registered_minigames.has(minigame_id):
		Logger.error("Minigame not found: " + minigame_id, "MinigameRegistry")
		return null
	
	var info: MinigameInfo = registered_minigames[minigame_id]
	
	if not info.enabled:
		Logger.warning("Minigame disabled: " + minigame_id, "MinigameRegistry")
		return null
	
	# Validate player count
	var player_count: int = context.participating_players.size()
	if player_count < info.min_players or player_count > info.max_players:
		Logger.error("Invalid player count for " + minigame_id + ": " + str(player_count) + " (requires " + str(info.min_players) + "-" + str(info.max_players) + ")", "MinigameRegistry")
		return null
	
	# Load minigame scene
	var minigame_scene: PackedScene = load(info.scene_path)
	if not minigame_scene:
		Logger.error("Failed to load minigame scene: " + info.scene_path, "MinigameRegistry")
		return null
	
	# Instantiate minigame
	var minigame: BaseMinigame = minigame_scene.instantiate()
	if not minigame:
		Logger.error("Failed to instantiate minigame: " + minigame_id, "MinigameRegistry")
		return null
	
	# Set up the minigame
	current_minigame = minigame
	add_child(minigame)
	
	# Connect lifecycle signals
	minigame.minigame_ended.connect(_on_minigame_ended)
	
	# Initialize and start
	minigame.initialize_minigame(context)
	minigame.start_minigame()
	
	Logger.game_flow("Launched minigame: " + info.display_name, "MinigameRegistry")
	minigame_launched.emit(minigame_id, minigame)
	
	return minigame

## Quick launch with player IDs (creates context automatically)
func quick_launch(minigame_id: String, player_ids: Array[int]) -> BaseMinigame:
	# Create basic context
	var context: MinigameContext = MinigameContext.new()
	
	# Populate with player data
	for player_id in player_ids:
		var player_data: PlayerData = GameManager.get_player_data(player_id)
		if player_data:
			context.participating_players.append(player_data)
	
	# Create map snapshot
	context.map_state_snapshot = MinigameContext.create_current_snapshot()
	
	return launch_minigame(minigame_id, context)

## Get all registered minigames
func get_all_minigames() -> Array[MinigameInfo]:
	return registered_minigames.values()

## Get minigames by type
func get_minigames_by_type(minigame_type: String) -> Array[MinigameInfo]:
	var filtered: Array[MinigameInfo] = []
	for info in registered_minigames.values():
		if info.minigame_type == minigame_type:
			filtered.append(info)
	return filtered

## Get minigames suitable for player count
func get_suitable_minigames(player_count: int) -> Array[MinigameInfo]:
	var suitable: Array[MinigameInfo] = []
	for info in registered_minigames.values():
		if info.enabled and player_count >= info.min_players and player_count <= info.max_players:
			suitable.append(info)
	return suitable

## Get minigames with specific tag
func get_minigames_with_tag(tag: String) -> Array[MinigameInfo]:
	var tagged: Array[MinigameInfo] = []
	for info in registered_minigames.values():
		if tag in info.tags:
			tagged.append(info)
	return tagged

## Get current running minigame
func get_current_minigame() -> BaseMinigame:
	return current_minigame

## Check if a minigame is currently running
func is_minigame_active() -> bool:
	return current_minigame != null and current_minigame.is_active

## End current minigame (emergency stop)
func end_current_minigame() -> void:
	if current_minigame:
		await current_minigame.abort_minigame()

## Get minigame info by ID
func get_minigame_info(minigame_id: String) -> MinigameInfo:
	return registered_minigames.get(minigame_id, null)

## Enable/disable a minigame
func set_minigame_enabled(minigame_id: String, enabled: bool) -> void:
	var info: MinigameInfo = get_minigame_info(minigame_id)
	if info:
		info.enabled = enabled
		Logger.system("Minigame " + minigame_id + " " + ("enabled" if enabled else "disabled"), "MinigameRegistry")

## Get minigame history
func get_minigame_history() -> Array[Dictionary]:
	return minigame_history.duplicate()

## Handle minigame completion
func _on_minigame_ended(result: MinigameResult) -> void:
	if not current_minigame:
		return
	
	var minigame_id: String = _find_minigame_id(current_minigame)
	
	# Record in history
	var history_entry: Dictionary = {
		"minigame_id": minigame_id,
		"timestamp": Time.get_unix_time_from_system(),
		"duration": result.duration,
		"outcome": result.outcome,
		"participants": result.participating_players.duplicate(),
		"winners": result.winners.duplicate()
	}
	minigame_history.append(history_entry)
	
	Logger.game_flow("Minigame completed: " + minigame_id + " in " + str(result.duration) + "s", "MinigameRegistry")
	minigame_completed.emit(minigame_id, result)
	
	# Cleanup
	current_minigame.queue_free()
	current_minigame = null

## Find minigame ID from instance
func _find_minigame_id(minigame: BaseMinigame) -> String:
	for id in registered_minigames.keys():
		var info: MinigameInfo = registered_minigames[id]
		if minigame.minigame_name == info.display_name:
			return id
	return "unknown"

## Discover and register minigames automatically by scanning scenes
func _discover_and_register_minigames() -> void:
	var minigame_scenes: Array[String] = _find_minigame_scenes()
	
	for scene_path in minigame_scenes:
		_register_minigame_from_scene(scene_path)
	
	Logger.system("Auto-discovered " + str(minigame_scenes.size()) + " minigames", "MinigameRegistry")

## Find all minigame scene files
func _find_minigame_scenes() -> Array[String]:
	var scenes: Array[String] = []
	
	# Look in the minigames scenes directory
	_scan_directory_for_minigames("res://scenes/minigames/", scenes)
	
	return scenes

## Scan a directory for minigame scene files
func _scan_directory_for_minigames(directory: String, scenes: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(directory)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = directory + file_name
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory_for_minigames(full_path + "/", scenes)
		elif file_name.ends_with(".tscn"):
			# Check if this scene contains a minigame
			if _is_minigame_scene(full_path):
				scenes.append(full_path)
		
		file_name = dir.get_next()

## Check if a scene file contains a BaseMinigame
func _is_minigame_scene(scene_path: String) -> bool:
	var scene: PackedScene = load(scene_path)
	if not scene:
		return false
	
	var instance: Node = scene.instantiate()
	var is_minigame: bool = instance is BaseMinigame
	instance.queue_free()
	
	return is_minigame

## Register a minigame from its scene file
func _register_minigame_from_scene(scene_path: String) -> void:
	var scene: PackedScene = load(scene_path)
	if not scene:
		Logger.warning("Failed to load minigame scene: " + scene_path, "MinigameRegistry")
		return
	
	var instance: BaseMinigame = scene.instantiate()
	if not instance:
		Logger.warning("Scene is not a BaseMinigame: " + scene_path, "MinigameRegistry")
		return
	
	# Get minigame info from the instance itself
	var info: MinigameInfo = instance.create_registry_info(scene_path)
	
	# Clean up the instance
	instance.queue_free()
	
	# Register the minigame
	register_minigame(info)
	Logger.system("Auto-registered minigame: " + info.display_name, "MinigameRegistry")

## Register a minigame from a scene path (convenience method)
func register_minigame_scene(scene_path: String) -> void:
	_register_minigame_from_scene(scene_path)

## Create a new minigame info helper (for manual registration)
static func create_minigame_info(id: String, display_name: String, scene_path: String) -> MinigameInfo:
	return MinigameInfo.new(id, display_name, scene_path)

## Batch register minigames from configuration
func register_from_config(config: Dictionary) -> void:
	for minigame_id in config.keys():
		var minigame_config: Dictionary = config[minigame_id]
		
		var info: MinigameInfo = MinigameInfo.new(
			minigame_id,
			minigame_config.get("name", minigame_id),
			minigame_config.get("scene_path", "")
		)
		
		info.description = minigame_config.get("description", "")
		info.minigame_type = minigame_config.get("type", "custom")
		info.min_players = minigame_config.get("min_players", 1)
		info.max_players = minigame_config.get("max_players", 4)
		info.estimated_duration = minigame_config.get("duration", 300.0)
		info.tags = minigame_config.get("tags", [])
		info.enabled = minigame_config.get("enabled", true)
		
		register_minigame(info) 
