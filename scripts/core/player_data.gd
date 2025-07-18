class_name PlayerData
extends Resource

## Player data structure for session management
## Contains all persistent player information

@export var player_id: int
@export var player_name: String = "Player"
@export var current_health: int = 3
@export var max_health: int = 3
@export var current_lives: int = 3  # Deaths remaining before elimination (3 lives = 3 deaths allowed)
@export var max_lives: int = 3      # Maximum deaths allowed per session
@export var is_alive: bool = true
@export var position: Vector2 = Vector2.ZERO

func _init(id: int = -1, name: String = "Player") -> void:
	player_id = id
	player_name = name
	current_health = max_health
	current_lives = max_lives
	is_alive = true

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

## Cleanup method following standards (though PlayerData is usually a Resource, this is for completeness)
func cleanup() -> void:
	# Clear any cached data if needed
	# PlayerData is typically a resource so may not need extensive cleanup
	pass 