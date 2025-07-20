class_name PlayerStatistics
extends Resource

## Lifetime player statistics - persistent across all sessions
## Tracks long-term performance, achievements, and play patterns

@export var player_id: int = -1
@export var player_name: String = ""

# Basic lifetime metrics
@export var games_played: int = 0
@export var games_won: int = 0
@export var total_playtime: float = 0.0  # Total time played in seconds
@export var sessions_played: int = 0  # Number of game sessions

# Performance metrics
@export var best_session_score: int = 0  # Highest score in a single session
@export var longest_win_streak: int = 0  # Best win streak across all sessions
@export var total_eliminations: int = 0  # Total enemies defeated across all games
@export var total_deaths: int = 0  # Total times died across all games

# Minigame-specific statistics
@export var favorite_minigames: Array[String] = []  # Most played minigame types
@export var minigame_wins: Dictionary = {}  # minigame_type -> wins count
@export var minigame_plays: Dictionary = {}  # minigame_type -> plays count
@export var best_minigame_scores: Dictionary = {}  # minigame_type -> highest score

# Achievements and milestones
@export var achievements: Array[String] = []  # All lifetime achievements
@export var achievement_dates: Dictionary = {}  # achievement_id -> unlock timestamp
@export var milestones_reached: Array[String] = []  # Major milestones hit

# Play patterns and preferences
@export var preferred_play_times: Array[int] = []  # Hours when player is most active
@export var average_session_length: float = 0.0  # Average session duration in minutes
@export var most_played_with: Dictionary = {}  # player_id -> sessions_together count

# Advanced metrics (stubs for future implementation)
@export var skill_ratings: Dictionary = {}  # minigame_type -> skill_rating
@export var improvement_trends: Dictionary = {}  # metric_name -> trend_data
@export var social_metrics: Dictionary = {}  # cooperation, leadership, etc.
@export var performance_metrics: Dictionary = {}  # Legacy field maintained for compatibility

func _init(id: int = -1, name: String = "") -> void:
	player_id = id
	player_name = name
	games_played = 0
	games_won = 0
	total_playtime = 0.0
	sessions_played = 0
	best_session_score = 0
	longest_win_streak = 0
	total_eliminations = 0
	total_deaths = 0
	favorite_minigames = []
	minigame_wins = {}
	minigame_plays = {}
	best_minigame_scores = {}
	achievements = []
	achievement_dates = {}
	milestones_reached = []
	preferred_play_times = []
	average_session_length = 0.0
	most_played_with = {}
	skill_ratings = {}
	improvement_trends = {}
	social_metrics = {}
	performance_metrics = {}

## Add session data to lifetime statistics
func add_session_data(session_score: int, session_duration: float, minigames_data: Array[Dictionary]) -> void:
	sessions_played += 1
	total_playtime += session_duration
	
	# Update best session score
	if session_score > best_session_score:
		best_session_score = session_score
	
	# Update average session length
	average_session_length = (total_playtime / 60.0) / sessions_played
	
	# Process minigame data
	for minigame_data in minigames_data:
		var type: String = minigame_data.get("type", "")
		var won: bool = minigame_data.get("won", false)
		var score: int = minigame_data.get("score", 0)
		
		# Update minigame counts
		minigame_plays[type] = minigame_plays.get(type, 0) + 1
		games_played += 1
		
		if won:
			minigame_wins[type] = minigame_wins.get(type, 0) + 1
			games_won += 1
		
		# Update best scores
		if score > best_minigame_scores.get(type, 0):
			best_minigame_scores[type] = score
	
	# Update favorite minigames (top 3 most played)
	_update_favorite_minigames()
	
	# Track play time for patterns
	var current_hour: int = Time.get_datetime_dict_from_system().hour
	if current_hour not in preferred_play_times:
		preferred_play_times.append(current_hour)

## Unlock a lifetime achievement
func unlock_achievement(achievement_id: String, description: String = "") -> bool:
	if achievement_id in achievements:
		return false  # Already unlocked
	
	achievements.append(achievement_id)
	achievement_dates[achievement_id] = Time.get_unix_time_from_system()
	
	# Check for milestone achievements
	_check_milestone_achievements()
	
	return true

## Check if player has a specific achievement
func has_achievement(achievement_id: String) -> bool:
	return achievement_id in achievements

## Get win percentage across all games
func get_overall_win_percentage() -> float:
	if games_played == 0:
		return 0.0
	return (float(games_won) / float(games_played)) * 100.0

## Get K/D ratio across all games
func get_lifetime_kd_ratio() -> float:
	if total_deaths == 0:
		return float(total_eliminations)
	return float(total_eliminations) / float(total_deaths)

## Get most successful minigame type
func get_best_minigame() -> String:
	var best_type: String = ""
	var best_percentage: float = 0.0
	
	for minigame_type in minigame_plays.keys():
		var plays: int = minigame_plays[minigame_type]
		var wins: int = minigame_wins.get(minigame_type, 0)
		
		if plays >= 3:  # Only consider minigames played at least 3 times
			var win_percentage: float = (float(wins) / float(plays)) * 100.0
			if win_percentage > best_percentage:
				best_percentage = win_percentage
				best_type = minigame_type
	
	return best_type

## Get formatted playtime string
func get_formatted_playtime() -> String:
	var hours: int = int(total_playtime) / 3600
	var minutes: int = (int(total_playtime) % 3600) / 60
	
	if hours > 0:
		return "%d hours, %d minutes" % [hours, minutes]
	else:
		return "%d minutes" % minutes

## Get player's rank based on total score/achievements
func get_player_rank() -> String:
	var total_achievements: int = achievements.size()
	var win_percentage: float = get_overall_win_percentage()
	
	# Simple ranking system (can be made more sophisticated)
	if total_achievements >= 50 and win_percentage >= 75.0:
		return "Legendary"
	elif total_achievements >= 25 and win_percentage >= 60.0:
		return "Expert"
	elif total_achievements >= 10 and win_percentage >= 45.0:
		return "Veteran"
	elif games_played >= 20 and win_percentage >= 30.0:
		return "Experienced"
	elif games_played >= 5:
		return "Novice"
	else:
		return "Beginner"

## Create statistics summary for display
func get_statistics_summary() -> Dictionary:
	return {
		"player_name": player_name,
		"rank": get_player_rank(),
		"games_played": games_played,
		"games_won": games_won,
		"win_percentage": "%.1f%%" % get_overall_win_percentage(),
		"best_minigame": get_best_minigame(),
		"total_playtime": get_formatted_playtime(),
		"achievements_count": achievements.size(),
		"best_session_score": best_session_score,
		"longest_streak": longest_win_streak,
		"kd_ratio": "%.2f" % get_lifetime_kd_ratio(),
		"sessions_played": sessions_played
	}

## Private method to update favorite minigames list
func _update_favorite_minigames() -> void:
	# Sort minigames by play count and keep top 3
	var sorted_minigames: Array = []
	
	for minigame_type in minigame_plays.keys():
		sorted_minigames.append({
			"type": minigame_type,
			"plays": minigame_plays[minigame_type]
		})
	
	sorted_minigames.sort_custom(func(a, b): return a.plays > b.plays)
	
	favorite_minigames.clear()
	for i in range(min(3, sorted_minigames.size())):
		favorite_minigames.append(sorted_minigames[i].type)

## Private method to check for milestone achievements
func _check_milestone_achievements() -> void:
	# Games played milestones
	for milestone in [10, 50, 100, 500, 1000]:
		var achievement_id: String = "games_played_" + str(milestone)
		if games_played >= milestone and achievement_id not in achievements:
			unlock_achievement(achievement_id, "Played " + str(milestone) + " games")
	
	# Wins milestones
	for milestone in [5, 25, 50, 100, 250]:
		var achievement_id: String = "games_won_" + str(milestone)
		if games_won >= milestone and achievement_id not in achievements:
			unlock_achievement(achievement_id, "Won " + str(milestone) + " games")
	
	# Playtime milestones (in hours)
	var hours_played: int = int(total_playtime) / 3600
	for milestone in [1, 10, 25, 50, 100]:
		var achievement_id: String = "playtime_" + str(milestone) + "h"
		if hours_played >= milestone and achievement_id not in achievements:
			unlock_achievement(achievement_id, "Played for " + str(milestone) + " hours") 