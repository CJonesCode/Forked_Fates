class_name MinigameResult
extends Resource

## Result data structure for minigame outcomes
## Communicates critical state information back to the map system for persistent world effects
## Now includes detailed per-player statistics for post-game display

@export var outcome: MinigameOutcome
@export var participating_players: Array[int]
@export var winners: Array[int] 
@export var statistics: Dictionary  # kills, deaths, items used, etc.
@export var rewards_earned: Array[Dictionary]  # Array of reward dictionaries
@export var penalties_applied: Array[Dictionary]  # Array of penalty dictionaries
@export var item_state_changes: Array[Dictionary]  # Array of item change dictionaries
@export var progression_data: Dictionary = {}  # Simple map progression data
@export var duration: float = 0.0
@export var minigame_type: String = ""

# New: Per-player detailed statistics for post-game screen (using Resource to avoid compilation issues)
@export var player_stats: Array[Resource] = []  # Array of MinigameStats resources
var party_progress: Resource  # PartyProgressData - Updated party state

enum MinigameOutcome {
	VICTORY,
	DEFEAT, 
	DRAW,
	TIMEOUT,
	ABANDONED
}

func _init() -> void:
	participating_players = []
	winners = []
	statistics = {}
	rewards_earned = []
	penalties_applied = []
	item_state_changes = []
	progression_data = {}
	player_stats = []
	party_progress = null

## Add individual player statistics for post-game display
func add_player_stats(stats: Resource) -> void:
	if stats:
		player_stats.append(stats)

## Get statistics for a specific player
func get_player_stats(player_id: int) -> Resource:
	for stats in player_stats:
		if stats and stats.has("player_id") and stats.get("player_id") == player_id:
			return stats
	return null

## Check if a player was a winner
func is_player_winner(player_id: int) -> bool:
	return player_id in winners

## Get winner names for display
func get_winner_names() -> Array[String]:
	var names: Array[String] = []
	for stats in player_stats:
		if stats and stats.has("player_id") and stats.has("player_name"):
			var stats_player_id: int = stats.get("player_id")
			if stats_player_id in winners:
				names.append(stats.get("player_name"))
	return names

## Get all player statistics sorted by rank
func get_sorted_player_stats() -> Array[Resource]:
	var sorted_stats: Array[Resource] = player_stats.duplicate()
	sorted_stats.sort_custom(func(a, b): 
		var rank_a: int = 999
		var rank_b: int = 999
		
		if a and a.has("rank"):
			rank_a = a.get("rank")
		if b and b.has("rank"):
			rank_b = b.get("rank")
			
		return rank_a < rank_b
	)
	return sorted_stats

## Create a simple victory result with basic information
static func create_victory_result(winner_id: int, all_players: Array[int], game_type: String, game_duration: float) -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = MinigameOutcome.VICTORY
	result.participating_players = all_players.duplicate()
	result.winners = [winner_id]
	result.minigame_type = game_type
	result.duration = game_duration
	return result

## Create a comprehensive result with detailed player statistics
static func create_detailed_result(outcome: MinigameOutcome, winners: Array[int], player_statistics: Array[Resource], 
									game_type: String, game_duration: float, party_data: Resource = null) -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = outcome
	result.winners = winners.duplicate()
	result.minigame_type = game_type
	result.duration = game_duration
	result.party_progress = party_data
	
	# Add all player statistics
	for stats in player_statistics:
		result.add_player_stats(stats)
		if stats and stats.has("player_id"):
			result.participating_players.append(stats.get("player_id"))
	
	return result

## Create a draw result where multiple players tie
static func create_draw_result(tied_players: Array[int], all_players: Array[int], game_type: String, game_duration: float) -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = MinigameOutcome.DRAW
	result.participating_players = all_players.duplicate()
	result.winners = tied_players.duplicate()
	result.minigame_type = game_type
	result.duration = game_duration
	return result

## Create a timeout result when game ends due to time limit
static func create_timeout_result(all_players: Array[int], game_type: String, game_duration: float) -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = MinigameOutcome.TIMEOUT
	result.participating_players = all_players.duplicate()
	result.winners = []  # No winners on timeout
	result.minigame_type = game_type
	result.duration = game_duration
	return result

## Create an abandoned result when game is interrupted
static func create_abandoned_result(all_players: Array[int], game_type: String, game_duration: float, reason: String = "") -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = MinigameOutcome.ABANDONED
	result.participating_players = all_players.duplicate()
	result.winners = []
	result.minigame_type = game_type
	result.duration = game_duration
	
	# Store abandonment reason in progression data
	result.progression_data["abandonment_reason"] = reason
	
	return result

## Get a summary suitable for logging and debugging
func get_result_summary() -> Dictionary:
	return {
		"outcome": MinigameOutcome.keys()[outcome],
		"winners": get_winner_names(),
		"participants": participating_players.size(),
		"minigame_type": minigame_type,
		"duration": "%.1f seconds" % duration,
		"player_count": player_stats.size(),
		"has_party_data": party_progress != null
	} 