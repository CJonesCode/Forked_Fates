class_name MinigameConfig
extends Resource

enum MinigameCategory {
	PHYSICS,
	UI,
	TURN_BASED,
	PUZZLE,
	RACING,
	SURVIVAL
}

@export var minigame_id: String = ""
@export var minigame_name: String = ""
@export var category: MinigameCategory = MinigameCategory.PHYSICS
@export var minigame_scene: PackedScene
@export var min_players: int = 1
@export var max_players: int = 4
@export var time_limit: float = 60.0
@export var difficulty: int = 1
@export var description: String = ""

# Standard manager requirements
@export_group("Standard Managers")
@export var needs_player_spawner: bool = true
@export var needs_item_spawner: bool = false
@export var needs_victory_manager: bool = true
@export var needs_respawn_manager: bool = false 
