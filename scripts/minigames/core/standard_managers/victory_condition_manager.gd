class_name VictoryConditionManager
extends Node

## Standard manager for tracking and evaluating victory conditions in minigames
## Supports elimination, scoring, time-based, and custom victory conditions

# Victory condition types
enum VictoryType {
	ELIMINATION,    # Last player/team standing
	SCORE_BASED,    # First to reach target score
	TIME_BASED,     # Highest score when time runs out
	CUSTOM          # Custom victory condition logic
}

# Configuration
@export var victory_type: VictoryType = VictoryType.ELIMINATION
@export var target_score: int = 100
@export var enable_teams: bool = false

# Player tracking
var players: Array[PlayerData] = []
var player_scores: Dictionary = {}  # player_id -> score
var player_teams: Dictionary = {}   # player_id -> team_id
var team_scores: Dictionary = {}    # team_id -> score
var eliminated_players: Array[int] = []

# Victory tracking
var is_tracking: bool = false
var game_statistics: Dictionary = {}

# Signals
signal victory_achieved(winner_data: Dictionary)
signal score_updated(player_id: int, new_score: int)
signal player_eliminated(player_id: int)
signal team_score_updated(team_id: int, new_score: int)

func _ready() -> void:
	Logger.system("VictoryConditionManager ready", "VictoryConditionManager")

## Setup players for victory tracking
func setup_players(player_data_array: Array[PlayerData]) -> void:
	players = player_data_array.duplicate()
	
	# Initialize player scores
	for player_data in players:
		player_scores[player_data.player_id] = 0
		
		# Setup teams if enabled
		if enable_teams:
			var team_id: int = player_data.player_id % 2  # Simple 2-team setup
			player_teams[player_data.player_id] = team_id
			if not team_scores.has(team_id):
				team_scores[team_id] = 0
	
	# Initialize statistics
	game_statistics = {
		"victory_type": VictoryType.keys()[victory_type],
		"players_count": players.size(),
		"teams_enabled": enable_teams,
		"start_time": Time.get_time_dict_from_system()["unix"]
	}
	
	Logger.system("VictoryConditionManager setup for " + str(players.size()) + " players", "VictoryConditionManager")

## Start tracking victory conditions
func start_tracking() -> void:
	is_tracking = true
	Logger.system("Victory condition tracking started", "VictoryConditionManager")

## Stop tracking victory conditions
func stop_tracking() -> void:
	is_tracking = false
	Logger.system("Victory condition tracking stopped", "VictoryConditionManager")

## Add score to a player
func add_score(player_id: int, score_delta: int) -> void:
	if not is_tracking:
		return
	
	if not player_scores.has(player_id):
		Logger.warning("Player " + str(player_id) + " not found in victory tracking", "VictoryConditionManager")
		return
	
	player_scores[player_id] += score_delta
	Logger.system("Player " + str(player_id) + " score: " + str(player_scores[player_id]) + " (+" + str(score_delta) + ")", "VictoryConditionManager")
	
	# Update team score if teams are enabled
	if enable_teams and player_teams.has(player_id):
		var team_id: int = player_teams[player_id]
		team_scores[team_id] += score_delta
		team_score_updated.emit(team_id, team_scores[team_id])
	
	score_updated.emit(player_id, player_scores[player_id])
	
	# Check for victory condition
	_check_victory_conditions()

## Set absolute score for a player
func set_score(player_id: int, new_score: int) -> void:
	if not is_tracking:
		return
	
	if not player_scores.has(player_id):
		Logger.warning("Player " + str(player_id) + " not found in victory tracking", "VictoryConditionManager")
		return
	
	var old_score: int = player_scores[player_id]
	var score_delta: int = new_score - old_score
	
	player_scores[player_id] = new_score
	
	# Update team score if teams are enabled
	if enable_teams and player_teams.has(player_id):
		var team_id: int = player_teams[player_id]
		team_scores[team_id] += score_delta
		team_score_updated.emit(team_id, team_scores[team_id])
	
	score_updated.emit(player_id, new_score)
	_check_victory_conditions()

## Mark a player as eliminated
func eliminate_player(player_id: int) -> void:
	if not is_tracking:
		return
	
	if player_id in eliminated_players:
		Logger.warning("Player " + str(player_id) + " already eliminated", "VictoryConditionManager")
		return
	
	eliminated_players.append(player_id)
	Logger.game_flow("Player " + str(player_id) + " eliminated", "VictoryConditionManager")
	player_eliminated.emit(player_id)
	
	# Update statistics
	if not game_statistics.has("eliminations"):
		game_statistics["eliminations"] = []
	game_statistics["eliminations"].append({
		"player_id": player_id,
		"timestamp": Time.get_time_dict_from_system()["unix"]
	})
	
	# Check for victory condition
	_check_victory_conditions()

## Get current scores
func get_scores() -> Dictionary:
	return player_scores.duplicate()

## Get team scores (if teams enabled)
func get_team_scores() -> Dictionary:
	return team_scores.duplicate()

## Get remaining players (not eliminated)
func get_remaining_players() -> Array[int]:
	var remaining: Array[int] = []
	for player_data in players:
		if not player_data.player_id in eliminated_players:
			remaining.append(player_data.player_id)
	return remaining

## Get eliminated players
func get_eliminated_players() -> Array[int]:
	return eliminated_players.duplicate()

## Get current game statistics
func get_game_statistics() -> Dictionary:
	var stats: Dictionary = game_statistics.duplicate()
	stats["current_scores"] = get_scores()
	stats["eliminated_players"] = get_eliminated_players()
	stats["remaining_players"] = get_remaining_players()
	
	if enable_teams:
		stats["team_scores"] = get_team_scores()
	
	return stats

## Check victory conditions
func _check_victory_conditions() -> void:
	if not is_tracking:
		return
	
	var winner_data: Dictionary = {}
	
	match victory_type:
		VictoryType.ELIMINATION:
			winner_data = _check_elimination_victory()
		VictoryType.SCORE_BASED:
			winner_data = _check_score_victory()
		VictoryType.TIME_BASED:
			# Time-based victory is handled externally (when timer expires)
			return
		VictoryType.CUSTOM:
			winner_data = _check_custom_victory()
	
	if not winner_data.is_empty():
		_handle_victory(winner_data)

## Check elimination victory condition
func _check_elimination_victory() -> Dictionary:
	var remaining_players: Array[int] = get_remaining_players()
	
	if enable_teams:
		# Check team elimination
		var remaining_teams: Array[int] = []
		for player_id in remaining_players:
			var team_id: int = player_teams[player_id]
			if not team_id in remaining_teams:
				remaining_teams.append(team_id)
		
		if remaining_teams.size() <= 1:
			if remaining_teams.size() == 1:
				return {"winning_team": remaining_teams[0], "team_players": _get_team_players(remaining_teams[0])}
			else:
				return {"draw": true, "tied_players": []}
	else:
		# Individual elimination
		if remaining_players.size() <= 1:
			if remaining_players.size() == 1:
				return {"winner_id": remaining_players[0]}
			else:
				return {"draw": true, "tied_players": []}
	
	return {}

## Check score-based victory condition
func _check_score_victory() -> Dictionary:
	if enable_teams:
		# Check team scores
		for team_id in team_scores.keys():
			if team_scores[team_id] >= target_score:
				return {"winning_team": team_id, "team_players": _get_team_players(team_id)}
	else:
		# Check individual scores
		for player_id in player_scores.keys():
			if player_scores[player_id] >= target_score:
				return {"winner_id": player_id}
	
	return {}

## Check custom victory condition (override in subclasses)
func _check_custom_victory() -> Dictionary:
	# Default implementation - no custom victory
	return {}

## Get players on a specific team
func _get_team_players(team_id: int) -> Array[int]:
	var team_players: Array[int] = []
	for player_id in player_teams.keys():
		if player_teams[player_id] == team_id:
			team_players.append(player_id)
	return team_players

## Handle victory achievement
func _handle_victory(winner_data: Dictionary) -> void:
	is_tracking = false
	Logger.game_flow("Victory condition met: " + str(winner_data), "VictoryConditionManager")
	
	# Update final statistics
	game_statistics["end_time"] = Time.get_time_dict_from_system()["unix"]
	game_statistics["winner_data"] = winner_data.duplicate()
	
	victory_achieved.emit(winner_data)

## Force end with time-based victory
func end_with_time_victory() -> void:
	if not is_tracking:
		return
	
	Logger.game_flow("Time-based victory evaluation", "VictoryConditionManager")
	
	var winner_data: Dictionary = {}
	
	if enable_teams:
		# Find highest scoring team
		var highest_score: int = -1
		var winning_teams: Array[int] = []
		
		for team_id in team_scores.keys():
			if team_scores[team_id] > highest_score:
				highest_score = team_scores[team_id]
				winning_teams = [team_id]
			elif team_scores[team_id] == highest_score:
				winning_teams.append(team_id)
		
		if winning_teams.size() == 1:
			winner_data = {"winning_team": winning_teams[0], "team_players": _get_team_players(winning_teams[0])}
		else:
			winner_data = {"draw": true, "tied_teams": winning_teams}
	else:
		# Find highest scoring player(s)
		var highest_score: int = -1
		var winning_players: Array[int] = []
		
		for player_id in player_scores.keys():
			if player_scores[player_id] > highest_score:
				highest_score = player_scores[player_id]
				winning_players = [player_id]
			elif player_scores[player_id] == highest_score:
				winning_players.append(player_id)
		
		if winning_players.size() == 1:
			winner_data = {"winner_id": winning_players[0]}
		else:
			winner_data = {"draw": true, "tied_players": winning_players}
	
	_handle_victory(winner_data) 