class_name MinigameResult
extends Resource

## Result data structure for minigame outcomes
## Communicates critical state information back to the map system for persistent world effects

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

## Create a simple victory result with basic information
static func create_victory_result(winner_id: int, all_players: Array[int], game_type: String, game_duration: float) -> MinigameResult:
	var result: MinigameResult = MinigameResult.new()
	result.outcome = MinigameOutcome.VICTORY
	result.participating_players = all_players.duplicate()
	result.winners = [winner_id]
	result.minigame_type = game_type
	result.duration = game_duration
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
	result.winners = []
	result.minigame_type = game_type
	result.duration = game_duration
	return result

# Note: Using Dictionary types for data structures to avoid inner class dependencies
# Dictionary structures should follow these patterns:
# 
# Reward: {"player_id": int, "reward_type": String, "amount": int, "item_name": String, "territory_id": String}
# Penalty: {"player_id": int, "penalty_type": String, "amount": int, "duration": float, "item_name": String, "territory_id": String}
# ProgressionData: {"unlock_next_nodes": Array[String], "block_nodes": Array[String], "current_node_completed": bool}
# ItemStateChange: {"player_id": int, "item_name": String, "change_type": String, "quantity": int} 