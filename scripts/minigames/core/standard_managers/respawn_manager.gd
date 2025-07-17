class_name RespawnManager
extends Node

## Standard manager for handling player respawning in physics-based minigames
## Manages respawn timers, positions, and lifecycle

# Configuration
@export var respawn_delay: float = 3.0
@export var max_respawns: int = -1  # -1 for unlimited
@export var respawn_invincibility_time: float = 2.0

# Respawn management
var respawn_points: Array[Vector2] = []
var dead_players: Dictionary = {}  # player_id -> respawn_timer
var player_respawn_counts: Dictionary = {}  # player_id -> respawn_count
var is_tracking: bool = false

# Signals
signal player_respawned(player: BasePlayer)
signal respawn_timer_updated(player_id: int, time_remaining: float)
signal max_respawns_reached(player_id: int)

func _ready() -> void:
	Logger.system("RespawnManager ready", "RespawnManager")

## Setup respawn points from positions array
func setup_respawn_points(points: Array[Vector2]) -> void:
	respawn_points = points.duplicate()
	Logger.system("RespawnManager configured with " + str(respawn_points.size()) + " respawn points", "RespawnManager")

## Start respawn tracking
func start_respawn_tracking() -> void:
	is_tracking = true
	Logger.system("Respawn tracking started", "RespawnManager")
	
	# Connect to player death events
	EventBus.player_died.connect(_on_player_died)

## Stop respawn tracking
func stop_respawn_tracking() -> void:
	is_tracking = false
	Logger.system("Respawn tracking stopped", "RespawnManager")
	
	# Disconnect from events
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)

## Process respawn timers
func _process(delta: float) -> void:
	if not is_tracking:
		return
	
	var players_to_respawn: Array[int] = []
	
	for player_id in dead_players.keys():
		dead_players[player_id] -= delta
		
		# Emit timer update
		respawn_timer_updated.emit(player_id, dead_players[player_id])
		
		# Check if ready to respawn
		if dead_players[player_id] <= 0.0:
			players_to_respawn.append(player_id)
	
	# Respawn players whose timers have expired
	for player_id in players_to_respawn:
		_respawn_player(player_id)

## Handle player death event
func _on_player_died(player_id: int) -> void:
	if not is_tracking:
		return
	
	# Check respawn limits
	var respawn_count: int = player_respawn_counts.get(player_id, 0)
	if max_respawns >= 0 and respawn_count >= max_respawns:
		Logger.game_flow("Player " + str(player_id) + " has reached max respawns", "RespawnManager")
		max_respawns_reached.emit(player_id)
		return
	
	# Start respawn process
	Logger.game_flow("Starting respawn process for Player " + str(player_id) + " in " + str(respawn_delay) + " seconds", "RespawnManager")
	dead_players[player_id] = respawn_delay
	
	# Make player invisible during respawn countdown
	var player: BasePlayer = _get_player_by_id(player_id)
	if player:
		player.visible = false

## Respawn a specific player
func _respawn_player(player_id: int) -> void:
	var player: BasePlayer = _get_player_by_id(player_id)
	if not player:
		Logger.warning("Cannot respawn - player " + str(player_id) + " not found", "RespawnManager")
		dead_players.erase(player_id)
		return
	
	if respawn_points.is_empty():
		Logger.warning("No respawn points available for Player " + str(player_id), "RespawnManager")
		dead_players.erase(player_id)
		return
	
	# Choose respawn position
	var respawn_position: Vector2 = _choose_respawn_position(player_id)
	
	# Update player data
	var player_data: PlayerData = GameManager.get_player_data(player_id)
	if player_data:
		player_data.current_health = player_data.max_health
		player_data.is_alive = true
	
	# Set spawn position and respawn
	player.set_spawn_position(respawn_position)
	player.respawn()
	
	# Apply temporary invincibility if configured
	if respawn_invincibility_time > 0:
		_apply_respawn_invincibility(player, respawn_invincibility_time)
	
	# Update respawn count
	player_respawn_counts[player_id] = player_respawn_counts.get(player_id, 0) + 1
	
	# Clean up tracking
	dead_players.erase(player_id)
	
	Logger.game_flow("Player " + str(player_id) + " respawned at " + str(respawn_position), "RespawnManager")
	player_respawned.emit(player)

## Choose best respawn position for a player
func _choose_respawn_position(player_id: int) -> Vector2:
	if respawn_points.size() == 1:
		return respawn_points[0]
	
	# Simple random selection - could be improved with distance/safety calculations
	return respawn_points[randi() % respawn_points.size()]

## Apply temporary invincibility to respawned player
func _apply_respawn_invincibility(player: BasePlayer, duration: float) -> void:
	# This would need to be implemented in the player system
	# For now, just log the intention
	Logger.system("Applied " + str(duration) + "s invincibility to respawned player", "RespawnManager")
	
	# Could implement visual feedback like blinking
	var tween: Tween = create_tween()
	tween.tween_method(_blink_player, 1.0, 0.5, duration)
	tween.tween_callback(func(): player.modulate = Color.WHITE)

## Visual feedback for invincibility
func _blink_player(alpha: float) -> void:
	# This would make the player blink during invincibility
	pass

## Get player instance by ID
func _get_player_by_id(player_id: int) -> BasePlayer:
	# This would need to access the player spawner or game state
	# For now, search through the scene tree
	var players: Array[Node] = []
	players.assign(get_tree().get_nodes_in_group("players"))
	for node in players:
		if node is BasePlayer and node.player_data.player_id == player_id:
			return node
	return null

## Force respawn a player immediately
func force_respawn(player_id: int) -> void:
	if dead_players.has(player_id):
		dead_players[player_id] = 0.0
		Logger.system("Forced immediate respawn for Player " + str(player_id), "RespawnManager")

## Get respawn statistics
func get_respawn_statistics() -> Dictionary:
	return {
		"respawn_points_available": respawn_points.size(),
		"players_waiting_respawn": dead_players.size(),
		"total_respawns": player_respawn_counts.values().reduce(func(a, b): return a + b, 0),
		"respawn_counts_by_player": player_respawn_counts.duplicate()
	}

## Check if player is waiting to respawn
func is_player_waiting_respawn(player_id: int) -> bool:
	return dead_players.has(player_id)

## Get remaining respawn time for a player
func get_respawn_time_remaining(player_id: int) -> float:
	return dead_players.get(player_id, 0.0)

## Clear all respawn timers (for game end)
func clear_all_respawn_timers() -> void:
	dead_players.clear()
	Logger.system("Cleared all respawn timers", "RespawnManager") 