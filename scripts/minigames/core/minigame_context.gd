class_name MinigameContext
extends Resource

## Context passed to minigames containing player data and system control capabilities
## Minigames can use this to override, disable, or replace core game systems

# Data provided to the minigame
@export var participating_players: Array[PlayerData]
@export var map_state_snapshot: MapSnapshot
@export var available_systems: Dictionary  # System name -> system node reference
@export var minigame_config: Dictionary  # Custom configuration for this minigame instance

# System control tracking
var disabled_systems: Array[String] = []
var overridden_systems: Dictionary = {}  # system_name -> replacement_node
var standard_managers: Dictionary = {}  # manager_type -> manager_instance

signal system_override_requested(system_name: String, replacement: Node)
signal system_disabled(system_name: String)

func _init() -> void:
	participating_players = []
	available_systems = {}
	minigame_config = {}

## Request to completely replace a core system with custom implementation
func request_system_override(system_name: String, replacement: Node) -> void:
	Logger.system("Minigame requesting override of system: " + system_name, "MinigameContext")
	overridden_systems[system_name] = replacement
	system_override_requested.emit(system_name, replacement)

## Completely disable a system the minigame doesn't need
func disable_system(system_name: String) -> void:
	Logger.system("Minigame disabling system: " + system_name, "MinigameContext")
	disabled_systems.append(system_name)
	system_disabled.emit(system_name)

## Get a standard manager for common minigame patterns
func get_standard_manager(manager_type: String) -> Node:
	if not standard_managers.has(manager_type):
		standard_managers[manager_type] = _create_standard_manager(manager_type)
	return standard_managers[manager_type]

## Check if a system is available for use
func is_system_available(system_name: String) -> bool:
	return available_systems.has(system_name) and not system_name in disabled_systems

## Get an available system reference
func get_system(system_name: String) -> Node:
	if overridden_systems.has(system_name):
		return overridden_systems[system_name]
	elif is_system_available(system_name):
		return available_systems[system_name]
	else:
		return null

## Get player data by ID for convenience
func get_player_data(player_id: int) -> PlayerData:
	for player_data in participating_players:
		if player_data.player_id == player_id:
			return player_data
	return null

## Get all player IDs as array
func get_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for player_data in participating_players:
		ids.append(player_data.player_id)
	return ids

## Create standard manager instances
func _create_standard_manager(manager_type: String) -> Node:
	match manager_type:
		"player_spawner":
			return preload("res://scripts/minigames/core/standard_managers/player_spawner.gd").new()
		"item_spawner":
			return preload("res://scripts/minigames/core/standard_managers/item_spawner.gd").new()
		"victory_condition_manager":
			return preload("res://scripts/minigames/core/standard_managers/victory_condition_manager.gd").new()
		"respawn_manager":
			return preload("res://scripts/minigames/core/standard_managers/respawn_manager.gd").new()
		_:
			Logger.warning("Unknown standard manager type: " + manager_type, "MinigameContext")
			return null

## Helper to add custom configuration
func set_config(key: String, value) -> void:
	minigame_config[key] = value

## Helper to get custom configuration
func get_config(key: String, default_value = null):
	return minigame_config.get(key, default_value)


# Related data structure for map state snapshots
class_name MapSnapshot
extends Resource

## Snapshot of the current map state for minigame context and potential rollback

@export var current_map_node: String = ""     # Current node ID on the map
@export var available_nodes: Array[String] = []  # Available node IDs to move to
@export var completed_nodes: Array[String] = []  # Completed node IDs
@export var player_positions: Dictionary = {}    # player_id -> Vector2 position
@export var player_inventories: Dictionary = {}  # player_id -> Array[item_name]
@export var snapshot_timestamp: float

func _init() -> void:
	current_map_node = ""
	available_nodes = []
	completed_nodes = []
	player_positions = {}
	player_inventories = {}
	snapshot_timestamp = Time.get_time_dict_from_system()["unix"]

## Create a snapshot from current game state
static func create_current_snapshot() -> MapSnapshot:
	var snapshot: MapSnapshot = MapSnapshot.new()
	
	# TODO: Populate with actual game state data
	# This would be implemented as the map system develops
	Logger.system("Created map state snapshot at " + str(snapshot.snapshot_timestamp), "MapSnapshot")
	
	return snapshot

## Check if a node is available to move to
func is_node_available(node_id: String) -> bool:
	return node_id in available_nodes

## Check if a node has been completed
func is_node_completed(node_id: String) -> bool:
	return node_id in completed_nodes 