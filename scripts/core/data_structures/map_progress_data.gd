class_name MapProgressData
extends Resource

## Individual player progress tracking for map view
## Tracks scoring, wins, and progression state for each player across the entire session

@export var player_id: int = -1
@export var player_name: String = ""

# Scoring and performance
@export var total_score: int = 0  # Accumulated score across all minigames
@export var minigames_won: int = 0  # Number of minigames this player has won
@export var minigames_played: int = 0  # Total minigames participated in
@export var win_percentage: float = 0.0  # Calculated win rate

# Current player status
@export var is_eliminated: bool = false  # Player eliminated from the session
@export var elimination_reason: String = ""  # "Lives depleted", "Quit", etc.

# Rewards and items earned
@export var current_rewards: Array[String] = []  # Active buffs/items player has
@export var rewards_history: Array[String] = []  # All rewards ever earned this session

# Recent performance tracking (for UI display)
@export var recent_scores: Array[int] = []  # Last 5 minigame scores for trend display
@export var recent_ranks: Array[int] = []   # Last 5 minigame rankings for trend display
@export var current_streak: int = 0  # Win streak (positive) or loss streak (negative)
@export var best_streak: int = 0     # Best win streak this session

# Map-specific progress data
@export var nodes_unlocked: Array[int] = []    # Node IDs this player has helped unlock
@export var special_achievements: Array[String] = []  # Map-specific achievements
@export var progression_bonuses: Dictionary = {}  # Any map progression bonuses earned

func _init(id: int = -1, name: String = "") -> void:
	player_id = id
	player_name = name
	total_score = 0
	minigames_won = 0
	minigames_played = 0
	win_percentage = 0.0
	is_eliminated = false
	elimination_reason = ""
	current_rewards = []
	rewards_history = []
	recent_scores = []
	recent_ranks = []
	current_streak = 0
	best_streak = 0
	nodes_unlocked = []
	special_achievements = []
	progression_bonuses = {}

## Add score from a completed minigame
func add_minigame_result(minigame_score: int, rank: int, was_winner: bool) -> void:
	total_score += minigame_score
	minigames_played += 1
	
	if was_winner:
		minigames_won += 1
		current_streak = max(0, current_streak) + 1  # Extend win streak or start new one
	else:
		current_streak = min(0, current_streak) - 1  # Extend loss streak or start new one
	
	# Update best streak if we have a new record
	if current_streak > best_streak:
		best_streak = current_streak
	
	# Update win percentage
	win_percentage = float(minigames_won) / float(minigames_played) * 100.0
	
	# Track recent performance (keep only last 5)
	recent_scores.append(minigame_score)
	recent_ranks.append(rank)
	if recent_scores.size() > 5:
		recent_scores.pop_front()
	if recent_ranks.size() > 5:
		recent_ranks.pop_front()

## Add a reward to the player's inventory
func add_reward(reward_id: String) -> void:
	if reward_id not in current_rewards:
		current_rewards.append(reward_id)
	
	if reward_id not in rewards_history:
		rewards_history.append(reward_id)

## Remove a reward (when used or expires)
func remove_reward(reward_id: String) -> void:
	if reward_id in current_rewards:
		current_rewards.erase(reward_id)

## Check if player has a specific reward
func has_reward(reward_id: String) -> bool:
	return reward_id in current_rewards

## Eliminate player from the session
func eliminate_player(reason: String) -> void:
	is_eliminated = true
	elimination_reason = reason
	current_streak = 0  # Reset streaks when eliminated

## Get performance trend (positive = improving, negative = declining, 0 = stable)
func get_performance_trend() -> int:
	if recent_ranks.size() < 3:
		return 0  # Not enough data
	
	var early_avg: float = 0.0
	var late_avg: float = 0.0
	var half_point: int = recent_ranks.size() / 2
	
	# Calculate average of first half vs second half of recent ranks
	for i in range(half_point):
		early_avg += recent_ranks[i]
	early_avg /= half_point
	
	for i in range(half_point, recent_ranks.size()):
		late_avg += recent_ranks[i]
	late_avg /= (recent_ranks.size() - half_point)
	
	# Lower rank number = better performance, so trend is reversed
	if early_avg - late_avg > 0.5:
		return 1  # Improving (ranks getting lower/better)
	elif late_avg - early_avg > 0.5:
		return -1  # Declining (ranks getting higher/worse)
	else:
		return 0  # Stable

## Get current performance level based on win percentage
func get_performance_level() -> String:
	if win_percentage >= 75.0:
		return "Excellent"
	elif win_percentage >= 50.0:
		return "Good"
	elif win_percentage >= 25.0:
		return "Average"
	else:
		return "Needs Improvement"

## Get average score from recent games
func get_average_recent_score() -> float:
	if recent_scores.is_empty():
		return 0.0
	
	var sum: int = 0
	for score in recent_scores:
		sum += score
	return float(sum) / float(recent_scores.size())

## Get streak description for display
func get_streak_description() -> String:
	if current_streak == 0:
		return "No Streak"
	elif current_streak > 0:
		return str(current_streak) + " Win Streak"
	else:
		return str(abs(current_streak)) + " Loss Streak"

## Reset progress for new session (but keep lifetime achievements)
func reset_for_new_session() -> void:
	total_score = 0
	minigames_won = 0
	minigames_played = 0
	win_percentage = 0.0
	is_eliminated = false
	elimination_reason = ""
	current_rewards.clear()
	# Keep rewards_history for lifetime tracking
	recent_scores.clear()
	recent_ranks.clear()
	current_streak = 0
	best_streak = 0
	nodes_unlocked.clear()
	progression_bonuses.clear()
	# Keep special_achievements for lifetime tracking

## Create summary data for UI display
func get_display_summary() -> Dictionary:
	return {
		"player_name": player_name,
		"total_score": total_score,
		"games_won": minigames_won,
		"games_played": minigames_played,
		"win_rate": "%.1f%%" % win_percentage,
		"performance_level": get_performance_level(),
		"current_streak": get_streak_description(),
		"trend": get_performance_trend(),
		"active_rewards": current_rewards.size(),
		"is_eliminated": is_eliminated
	} 