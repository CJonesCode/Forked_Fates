extends Node

## PlayerManager - Singleton for ID-based player lookups
## Solves circular dependency by providing player access via IDs instead of direct object references
## All players register with their player_id for fast lookup

# Player registry: player_id -> BasePlayer
var players: Dictionary = {}

# Player lookup statistics (for debugging/monitoring)
var lookup_count: int = 0
var registration_count: int = 0

## Register a player with their ID for lookups
func register_player(player_id: int, player: BasePlayer) -> void:
	if player_id == -1:
		Logger.error("Cannot register player with invalid ID -1", "PlayerManager")
		return
	
	if not player:
		Logger.error("Cannot register null player", "PlayerManager")
		return
	
	players[player_id] = player
	registration_count += 1
	Logger.system("Player registered: ID=" + str(player_id), "PlayerManager")

## Unregister a player by ID
func unregister_player(player_id: int) -> void:
	if players.has(player_id):
		players.erase(player_id)
		Logger.system("Player unregistered: ID=" + str(player_id), "PlayerManager")
	else:
		Logger.warning("Attempted to unregister non-existent player: ID=" + str(player_id), "PlayerManager")

## Get player by ID - main lookup method
func get_player(player_id: int) -> BasePlayer:
	lookup_count += 1
	
	if player_id == -1:
		return null
	
	var player: BasePlayer = players.get(player_id, null)
	if not player:
		Logger.warning("Player lookup failed: ID=" + str(player_id), "PlayerManager")
	
	return player

## Get all registered players
func get_all_players() -> Array[BasePlayer]:
	var result: Array[BasePlayer] = []
	for player in players.values():
		if player:  # Safety check
			result.append(player)
	return result

## Get all registered player IDs
func get_all_player_ids() -> Array[int]:
	var result: Array[int] = []
	for player_id in players.keys():
		result.append(player_id)
	return result

## Check if player ID is registered
func has_player(player_id: int) -> bool:
	return players.has(player_id)

## Get current player count
func get_player_count() -> int:
	return players.size()

## Clear all players (for cleanup/reset)
func clear_all_players() -> void:
	var count: int = players.size()
	players.clear()
	Logger.system("Cleared " + str(count) + " players", "PlayerManager")

## Get lookup statistics
func get_stats() -> Dictionary:
	return {
		"registered_players": players.size(),
		"total_lookups": lookup_count,
		"total_registrations": registration_count
	}

## Debug: Print all registered players
func debug_print_players() -> void:
	Logger.system("Registered players: " + str(players.size()), "PlayerManager")
	for player_id in players.keys():
		var player: BasePlayer = players[player_id]
		if player:
			Logger.system("  ID=" + str(player_id) + " name=" + str(player.name), "PlayerManager")
		else:
			Logger.warning("  ID=" + str(player_id) + " <null player>", "PlayerManager") 