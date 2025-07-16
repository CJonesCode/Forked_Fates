class_name PlayerData
extends Resource

## Player data structure for session management
## Contains all persistent player information

@export var player_id: int
@export var player_name: String = "Player"
@export var current_health: int = 3
@export var max_health: int = 3
@export var current_lives: int = 3  # Number of lives/respawns remaining
@export var max_lives: int = 3      # Maximum lives for the session
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