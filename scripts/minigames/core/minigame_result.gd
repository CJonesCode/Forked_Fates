class_name MinigameResult
extends Resource

## Result data structure for minigame outcomes
## Communicates critical state information back to the map system for persistent world effects

@export var outcome: MinigameOutcome
@export var participating_players: Array[int]
@export var winners: Array[int] 
@export var statistics: Dictionary  # kills, deaths, items used, etc.
@export var rewards_earned: Array[Reward]
@export var penalties_applied: Array[Penalty]
@export var item_state_changes: Array[ItemStateChange]
@export var progression_data: ProgressionData  # Simple map progression
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

# Related data structures for complex state changes

class_name Reward
extends Resource

@export var player_id: int
@export var reward_type: String  # "currency", "item", "territory", "skill_point"
@export var amount: int
@export var item_name: String = ""  # For item rewards
@export var territory_id: String = ""  # For territory rewards

class_name Penalty
extends Resource

@export var player_id: int
@export var penalty_type: String  # "currency_loss", "item_loss", "territory_loss", "temporary_debuff"
@export var amount: int
@export var duration: float = 0.0  # For temporary penalties
@export var item_name: String = ""
@export var territory_id: String = ""

class_name ProgressionData
extends Resource

@export var unlock_next_nodes: Array[String] = []  # Node IDs that become available
@export var block_nodes: Array[String] = []        # Node IDs that become unavailable
@export var current_node_completed: bool = false   # Whether current node is marked complete

class_name ItemStateChange
extends Resource

@export var player_id: int
@export var item_name: String
@export var change_type: String  # "gained", "lost", "upgraded", "damaged"
@export var quantity: int = 1 