class_name PlayerData
extends Resource

## Core player data for current session
## Contains minimal identification and current minigame state
## References segregated data structures for different purposes

# Core identification - never changes during session
@export var player_id: int = -1
@export var player_name: String = "Player"

# Current minigame state - resets per minigame
@export var current_health: int = 3
@export var max_health: int = 3
@export var current_lives: int = 3  # Deaths remaining before elimination (3 lives = 3 deaths allowed)
@export var max_lives: int = 3      # Maximum deaths allowed per session
@export var is_alive: bool = true
@export var position: Vector2 = Vector2.ZERO

# References to segregated data structures (not exported - created at runtime)
var map_progress: Resource  # MapProgressData - Individual player progress tracking for map view
var lifetime_stats: Resource  # PlayerStatistics - Lifetime statistics across all sessions

func _init(id: int = -1, name: String = "Player") -> void:
	player_id = id
	player_name = name
	current_health = max_health
	current_lives = max_lives
	is_alive = true
	
	# Initialize segregated data structures using preloads
	_initialize_data_structures()

## Initialize data structures safely
func _initialize_data_structures() -> void:
	# Load the classes dynamically to avoid compilation dependency issues
	var MapProgressDataClass = load("res://scripts/core/data_structures/map_progress_data.gd")
	var PlayerStatisticsClass = load("res://scripts/core/data_structures/player_statistics.gd")
	
	if MapProgressDataClass:
		map_progress = MapProgressDataClass.new(player_id, player_name)
	else:
		Logger.error("Failed to load MapProgressData class", "PlayerData")
	
	if PlayerStatisticsClass:
		lifetime_stats = PlayerStatisticsClass.new(player_id, player_name)
	else:
		Logger.error("Failed to load PlayerStatistics class", "PlayerData")

## Calculate health percentage
func get_health_percentage() -> float:
	if max_health <= 0:
		return 0.0
	return (float(current_health) / float(max_health)) * 100.0

## Check if player is out of lives
func is_out_of_lives() -> bool:
	return current_lives <= 0

## Reset player data to default values for new minigame session
func reset_for_new_minigame() -> void:
	current_health = max_health
	current_lives = max_lives
	is_alive = true
	# Don't reset player_id, player_name, max_health, max_lives - these are session constants
	# Don't reset map_progress or lifetime_stats - they persist across minigames

## Get current session summary combining all data types
func get_session_summary() -> Dictionary:
	var summary: Dictionary = {
		"player_id": player_id,
		"player_name": player_name,
		"current_health": current_health,
		"max_health": max_health,
		"current_lives": current_lives,
		"is_alive": is_alive,
		"health_percentage": get_health_percentage(),
		"is_eliminated": is_out_of_lives()
	}
	
	# Add map progress data if available
	if map_progress and map_progress.has_method("get_display_summary"):
		summary["map_progress"] = map_progress.get_display_summary()
	
	# Add lifetime stats summary if available
	if lifetime_stats and lifetime_stats.has_method("get_statistics_summary"):
		summary["lifetime_stats"] = lifetime_stats.get_statistics_summary()
	
	return summary

## Initialize data structures if they don't exist (for loading from saves)
func ensure_data_structures_exist() -> void:
	if not map_progress:
		_initialize_data_structures()
	
	if not lifetime_stats:
		_initialize_data_structures()

## Update data from a completed minigame
func update_from_minigame_result(minigame_stats: Resource, was_winner: bool) -> void:
	ensure_data_structures_exist()
	
	# Update map progress using duck typing to avoid compilation dependency
	if map_progress and map_progress.has_method("add_minigame_result"):
		var score: int = 0
		var rank: int = 0
		
		if minigame_stats:
			if minigame_stats.has("score"):
				score = minigame_stats.get("score")
			if minigame_stats.has("rank"):
				rank = minigame_stats.get("rank")
		
		map_progress.add_minigame_result(score, rank, was_winner)
		
		# Add any rewards from the minigame
		if minigame_stats and minigame_stats.has("rewards_earned"):
			var rewards: Array = minigame_stats.get("rewards_earned")
			if rewards:
				for reward in rewards:
					if map_progress.has_method("add_reward"):
						map_progress.add_reward(reward)
	
	# Note: Lifetime stats will be updated when the session ends
	# This separation allows for session-level vs lifetime-level tracking

## Eliminate player from current session
func eliminate_from_session(reason: String) -> void:
	is_alive = false
	current_lives = 0
	
	if map_progress and map_progress.has_method("eliminate_player"):
		map_progress.eliminate_player(reason)

## Get the segregated data structures for external access
func get_map_progress() -> Resource:
	ensure_data_structures_exist()
	return map_progress

func get_lifetime_stats() -> Resource:
	ensure_data_structures_exist()
	return lifetime_stats

## Cleanup method following standards
func cleanup() -> void:
	# Clear any cached data if needed
	# PlayerData is typically a resource so may not need extensive cleanup
	if map_progress:
		map_progress = null
	if lifetime_stats:
		lifetime_stats = null 