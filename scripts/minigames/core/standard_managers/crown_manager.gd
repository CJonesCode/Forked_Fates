class_name CrownManager
extends Node

## Crown Manager for Victory Condition Integration
## Manages world-space crown indicators that show above the player currently leading in victory conditions
## Only ONE player gets the crown at a time (no ties) - the single player with the highest victory value

# Manager configuration
@export var crown_enabled: bool = true
@export var update_frequency: float = 0.5  # How often to check for crown updates (seconds)
@export var victory_tie_breaker: String = "player_id"  # How to break ties: "player_id", "random", "first"

# Crown configuration (loaded from ConfigManager)
var crown_config: CrownConfig

# Crown instance
var crown_indicator = null  # Will be CrownIndicator, but loaded dynamically
var current_crown_holder: BasePlayer = null

# Victory tracking
var victory_condition_manager: VictoryConditionManager = null
var player_spawner: PlayerSpawner = null
var last_update_time: float = 0.0

# Victory value tracking
var player_victory_values: Dictionary = {}  # player_id -> victory_value
var victory_type: String = "ELIMINATION"

# Signals
signal crown_awarded(player: BasePlayer)
signal crown_removed(player: BasePlayer)
signal crown_transferred(from_player: BasePlayer, to_player: BasePlayer)

func _ready() -> void:
	# Load crown configuration (standards compliance)
	_load_crown_config()
	
	Logger.system("CrownManager initialized", "CrownManager")

## Load crown configuration from ConfigManager
func _load_crown_config() -> void:
	crown_config = ConfigManager.get_crown_config("default")
	if crown_config:
		# Apply configuration values
		update_frequency = crown_config.update_frequency
		victory_tie_breaker = crown_config.victory_tie_breaker
		Logger.debug("Crown manager config loaded successfully", "CrownManager")
	else:
		Logger.warning("Failed to load crown config - using defaults", "CrownManager")

func _process(delta: float) -> void:
	if not crown_enabled:
		return
	
	# Update crown position periodically
	last_update_time += delta
	if last_update_time >= update_frequency:
		_update_crown_position()
		last_update_time = 0.0

## Setup crown manager with victory condition manager and player spawner
func setup_for_minigame(victory_manager: VictoryConditionManager, spawner: PlayerSpawner) -> void:
	victory_condition_manager = victory_manager
	player_spawner = spawner
	
	if victory_condition_manager:
		# Determine victory type
		victory_type = VictoryConditionManager.VictoryType.keys()[victory_condition_manager.victory_type]
		
		# Connect to victory manager signals
		if not victory_condition_manager.score_updated.is_connected(_on_score_updated):
			victory_condition_manager.score_updated.connect(_on_score_updated)
		if not victory_condition_manager.player_eliminated.is_connected(_on_player_eliminated):
			victory_condition_manager.player_eliminated.connect(_on_player_eliminated)
	else:
		# No victory condition manager - use basic setup
		victory_type = "CUSTOM"
		Logger.debug("Crown manager setup without victory condition manager - using CUSTOM mode", "CrownManager")
	
	# Create crown indicator
	_create_crown_indicator()
	
	# Initial crown update
	_update_crown_position()
	
	Logger.system("CrownManager setup completed with victory type: " + victory_type, "CrownManager")

## Create the crown indicator instance
func _create_crown_indicator() -> void:
	if crown_indicator:
		return
	
	# Create crown indicator
	crown_indicator = preload("res://scripts/player/components/crown_indicator.gd").new()
	
	# Set crown style based on victory type
	crown_indicator.set_crown_style(victory_type)
	
	Logger.debug("Crown indicator created with style: " + victory_type, "CrownManager")

## Update crown position based on current victory conditions
func _update_crown_position() -> void:
	if not crown_enabled:
		return
	
	# Calculate victory values for all players
	_calculate_victory_values()
	
	# Find the single player with the highest victory value
	var leading_player: BasePlayer = _find_leading_player()
	
	# Update crown holder
	_update_crown_holder(leading_player)

## Calculate victory values for all players based on victory type
func _calculate_victory_values() -> void:
	player_victory_values.clear()
	
	if not victory_condition_manager:
		return
	
	match victory_type:
		"ELIMINATION":
			_calculate_elimination_values()
		"SCORE_BASED":
			_calculate_score_values()
		"TIME_BASED":
			_calculate_score_values()  # Time-based uses scores too
		"CUSTOM":
			_calculate_custom_values()
		_:
			Logger.warning("Unknown victory type: " + victory_type, "CrownManager")

## Calculate values for elimination-based victory (lives remaining)
func _calculate_elimination_values() -> void:
	var remaining_players = victory_condition_manager.get_remaining_players()
	
	for player_id in remaining_players:
		var player_data = GameManager.get_player_data(player_id)
		if player_data and player_data.is_alive:
			# Victory value = current lives (higher is better)
			# Only include alive players who haven't been eliminated
			player_victory_values[player_id] = player_data.current_lives

## Calculate values for score-based victory
func _calculate_score_values() -> void:
	var scores = victory_condition_manager.get_scores()
	
	for player_id in scores.keys():
		# Victory value = current score (higher is better)
		player_victory_values[player_id] = scores[player_id]

## Calculate values for custom victory conditions (override in subclasses)
func _calculate_custom_values() -> void:
	# Default implementation: use player health as victory value
	for player_id in range(4):
		var player_data = GameManager.get_player_data(player_id)
		if player_data:
			player_victory_values[player_id] = player_data.current_health

## Find the single player with the highest victory value
func _find_leading_player() -> BasePlayer:
	if player_victory_values.is_empty():
		return null
	
	var highest_value: int = -999999
	var leading_players: Array[int] = []
	
	# Find all players with the highest value
	for player_id in player_victory_values.keys():
		var value = player_victory_values[player_id]
		
		if value > highest_value:
			highest_value = value
			leading_players = [player_id]
		elif value == highest_value:
			leading_players.append(player_id)
	
	# Handle ties - only ONE player gets the crown
	var winner_id: int = _break_tie(leading_players)
	
	# Get the actual player object
	return _get_player_by_id(winner_id)

## Get player by ID using available methods
func _get_player_by_id(player_id: int) -> BasePlayer:
	# Try player_spawner first (physics minigames)
	if player_spawner:
		return player_spawner.get_player(player_id)
	
	# Fallback: search scene tree for player nodes (UI/turn-based minigames)
	return _find_player_in_scene_tree(player_id)

## Fallback method to find player in scene tree
func _find_player_in_scene_tree(player_id: int) -> BasePlayer:
	# Search through the minigame's scene tree for BasePlayer nodes
	var minigame_node = get_parent()  # Should be the minigame
	if not minigame_node:
		return null
	
	# Recursively search for BasePlayer nodes with matching player_id
	return _search_for_player_recursive(minigame_node, player_id)

## Recursive search for player with matching ID
func _search_for_player_recursive(node: Node, target_id: int) -> BasePlayer:
	# Check if this node is a BasePlayer with matching ID
	if node is BasePlayer:
		var player = node as BasePlayer
		if player.player_data and player.player_data.player_id == target_id:
			return player
	
	# Search children
	for child in node.get_children():
		var result = _search_for_player_recursive(child, target_id)
		if result:
			return result
	
	return null

## Break ties when multiple players have the same victory value
func _break_tie(tied_players: Array[int]) -> int:
	if tied_players.is_empty():
		return -1
	
	if tied_players.size() == 1:
		return tied_players[0]
	
	# Apply tie-breaking rule
	match victory_tie_breaker:
		"player_id":
			# Lowest player ID wins
			tied_players.sort()
			return tied_players[0]
		"random":
			# Random player wins
			return tied_players[randi() % tied_players.size()]
		"first":
			# First player in list wins
			return tied_players[0]
		_:
			Logger.warning("Unknown tie breaker: " + victory_tie_breaker, "CrownManager")
			return tied_players[0]

## Update the crown holder
func _update_crown_holder(new_leader: BasePlayer) -> void:
	if current_crown_holder == new_leader:
		return  # No change needed
	
	var previous_holder = current_crown_holder
	
	# Single crown reuse pattern - don't destroy, just move it
	if current_crown_holder and crown_indicator:
		crown_indicator.hide_crown(true)
		crown_indicator.detach_from_player()
		crown_removed.emit(current_crown_holder)
		Logger.debug("Crown removed from: " + current_crown_holder.player_data.player_name, "CrownManager")
	
	# Set new crown holder
	current_crown_holder = new_leader
	
	# Reuse the same crown indicator for the new holder
	if current_crown_holder and crown_indicator:
		crown_indicator.attach_to_player(current_crown_holder)
		crown_indicator.show_crown(true)
		crown_awarded.emit(current_crown_holder)
		Logger.debug("Crown awarded to: " + current_crown_holder.player_data.player_name, "CrownManager")
		
		# Emit transfer signal if there was a previous holder
		if previous_holder:
			crown_transferred.emit(previous_holder, current_crown_holder)

## Manually set crown holder (for custom victory conditions)
func set_crown_holder(player: BasePlayer) -> void:
	_update_crown_holder(player)

## Remove crown from current holder (but don't destroy the indicator)
func remove_crown() -> void:
	if current_crown_holder and crown_indicator:
		crown_indicator.hide_crown(true)
		crown_indicator.detach_from_player()
		crown_removed.emit(current_crown_holder)
		Logger.debug("Crown removed from: " + current_crown_holder.player_data.player_name, "CrownManager")
	
	current_crown_holder = null

## Enable/disable crown system
func set_crown_enabled(enabled: bool) -> void:
	crown_enabled = enabled
	if not crown_enabled:
		remove_crown()

## Public method to update crown tracking (called when lives change)
func update_crown_tracking() -> void:
	_update_crown_position()

## Called when the scene is ready to start processing crown updates
func start_crown_tracking() -> void:
	crown_enabled = true
	_update_crown_position()

## Called when the minigame ends to stop crown updates
func stop_crown_tracking() -> void:
	crown_enabled = false
	remove_crown()

## Get current victory values for debugging
func get_victory_values() -> Dictionary:
	return player_victory_values.duplicate()

## Get current crown holder
func get_crown_holder() -> BasePlayer:
	return current_crown_holder

# Signal handlers

## Handle score updates from victory condition manager
func _on_score_updated(player_id: int, new_score: int) -> void:
	# Score changed - update crown position on next update cycle
	Logger.debug("Score updated for Player " + str(player_id) + ": " + str(new_score), "CrownManager")

## Handle player elimination
func _on_player_eliminated(player_id: int) -> void:
	# Player eliminated - update crown position immediately
	Logger.debug("Player " + str(player_id) + " eliminated - updating crown", "CrownManager")
	_update_crown_position()

## Cleanup on destruction
func _exit_tree() -> void:
	# Proper cleanup following standards
	if crown_indicator and is_instance_valid(crown_indicator):
		crown_indicator.queue_free()
		crown_indicator = null
	
	# Disconnect signals if connected
	if victory_condition_manager:
		if victory_condition_manager.score_updated.is_connected(_on_score_updated):
			victory_condition_manager.score_updated.disconnect(_on_score_updated)
		if victory_condition_manager.player_eliminated.is_connected(_on_player_eliminated):
			victory_condition_manager.player_eliminated.disconnect(_on_player_eliminated)
	
	# Clear references
	current_crown_holder = null
	victory_condition_manager = null
	player_spawner = null
	crown_config = null
	player_victory_values.clear()
	
	Logger.debug("CrownManager cleanup completed", "CrownManager") 