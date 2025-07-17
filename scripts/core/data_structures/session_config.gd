extends Resource

@export var session_name: String = ""
@export var max_players: int = 4
@export var time_limit: float = 0.0  # 0 for unlimited
@export var victory_conditions: String = "elimination"
@export var allowed_minigames: Array[String] = []
@export var difficulty_modifier: float = 1.0 