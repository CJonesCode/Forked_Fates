class_name MinigameStats
extends Resource

## Minigame-specific statistics for post-game display
## Each minigame defines what stats to track and how to present them
## This data is temporary and used only for the post-game screen

@export var player_id: int = -1
@export var player_name: String = ""

# Core performance metrics
@export var rank: int = 0  # Final placement: 1st, 2nd, 3rd, etc.
@export var score: int = 0  # Points earned in this specific minigame
@export var performance_rating: String = ""  # "Excellent", "Good", "Poor", etc.

# Flexible statistics - each minigame defines what goes here
@export var stats: Dictionary = {}

# Common stat categories that minigames might use:
# stats["eliminations"] = 5
# stats["deaths"] = 2  
# stats["items_used"] = 3
# stats["distance_traveled"] = 1250.5
# stats["time_survived"] = 45.2
# stats["accuracy"] = 0.75
# stats["damage_dealt"] = 120
# stats["damage_taken"] = 85

# Special achievements for this minigame
@export var achievements: Array[String] = []
# Examples: "First Blood", "Triple Kill", "Survivor", "Speed Demon"

# Rewards earned from this specific minigame
@export var rewards_earned: Array[String] = []
# Examples: "health_potion", "speed_boost", "extra_life"

# Display formatting hints for the UI
@export var display_data: Dictionary = {}
# display_data["highlight_stats"] = ["eliminations", "survival_time"]
# display_data["format_types"] = {"time_survived": "time", "accuracy": "percentage"}
# display_data["stat_labels"] = {"eliminations": "Enemies Defeated", "damage_dealt": "Damage Output"}

func _init(id: int = -1, name: String = "") -> void:
	player_id = id
	player_name = name
	stats = {}
	achievements = []
	rewards_earned = []
	display_data = {}

## Add a statistic with optional formatting hint
func add_stat(stat_name: String, value, format_type: String = "number") -> void:
	stats[stat_name] = value
	if format_type != "number":
		if not display_data.has("format_types"):
			display_data["format_types"] = {}
		display_data["format_types"][stat_name] = format_type

## Add a display label for a statistic
func set_stat_label(stat_name: String, display_label: String) -> void:
	if not display_data.has("stat_labels"):
		display_data["stat_labels"] = {}
	display_data["stat_labels"][stat_name] = display_label

## Mark a stat as highlighted for prominent display
func highlight_stat(stat_name: String) -> void:
	if not display_data.has("highlight_stats"):
		display_data["highlight_stats"] = []
	if stat_name not in display_data["highlight_stats"]:
		display_data["highlight_stats"].append(stat_name)

## Get formatted stat value for display
func get_formatted_stat(stat_name: String) -> String:
	if not stats.has(stat_name):
		return "N/A"
	
	var value = stats[stat_name]
	var format_type: String = "number"
	
	if display_data.has("format_types") and display_data["format_types"].has(stat_name):
		format_type = display_data["format_types"][stat_name]
	
	match format_type:
		"time":
			return _format_time(value)
		"percentage":
			return str(round(value * 100)) + "%"
		"distance":
			return str(round(value)) + "m"
		_:
			return str(value)

## Get display label for a stat (falls back to stat name)
func get_stat_label(stat_name: String) -> String:
	if display_data.has("stat_labels") and display_data["stat_labels"].has(stat_name):
		return display_data["stat_labels"][stat_name]
	
	# Convert snake_case to Title Case as fallback
	return stat_name.replace("_", " ").capitalize()

## Check if a stat should be highlighted
func is_stat_highlighted(stat_name: String) -> bool:
	if display_data.has("highlight_stats"):
		return stat_name in display_data["highlight_stats"]
	return false

## Private helper for time formatting
func _format_time(seconds: float) -> String:
	var minutes: int = int(seconds) / 60
	var remaining_seconds: int = int(seconds) % 60
	return "%d:%02d" % [minutes, remaining_seconds]

## Static factory for common minigame stats
static func create_elimination_stats(player_id: int, player_name: String, rank: int, eliminations: int, deaths: int, survival_time: float) -> MinigameStats:
	var stats: MinigameStats = MinigameStats.new(player_id, player_name)
	stats.rank = rank
	stats.score = eliminations * 10 - deaths * 5  # Example scoring
	
	stats.add_stat("eliminations", eliminations)
	stats.add_stat("deaths", deaths) 
	stats.add_stat("survival_time", survival_time, "time")
	stats.add_stat("kd_ratio", float(eliminations) / max(deaths, 1))
	
	stats.set_stat_label("eliminations", "Enemies Defeated")
	stats.set_stat_label("kd_ratio", "K/D Ratio")
	stats.set_stat_label("survival_time", "Time Survived")
	
	stats.highlight_stat("eliminations")
	stats.highlight_stat("survival_time")
	
	return stats

static func create_racing_stats(player_id: int, player_name: String, rank: int, finish_time: float, laps: int, best_lap: float) -> MinigameStats:
	var stats: MinigameStats = MinigameStats.new(player_id, player_name)
	stats.rank = rank
	stats.score = max(100 - rank * 10, 10)  # Example scoring
	
	stats.add_stat("finish_time", finish_time, "time")
	stats.add_stat("laps_completed", laps)
	stats.add_stat("best_lap_time", best_lap, "time")
	stats.add_stat("average_lap", finish_time / max(laps, 1), "time")
	
	stats.set_stat_label("finish_time", "Total Time")
	stats.set_stat_label("best_lap_time", "Best Lap")
	stats.set_stat_label("average_lap", "Average Lap")
	
	stats.highlight_stat("finish_time")
	stats.highlight_stat("best_lap_time")
	
	return stats 