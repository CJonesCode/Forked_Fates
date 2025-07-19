class_name CrownConfig
extends Resource

## Crown indicator configuration resource
## Defines visual appearance and behavior for crown indicators

# Visual configuration
@export_group("Appearance")
@export var crown_text: String = "👑"
@export var crown_color: Color = Color.GOLD
@export var font_size: int = 24

# Animation configuration  
@export_group("Animation")
@export var float_height: float = -50.0  # How far above player to float
@export var bob_enabled: bool = true
@export var bob_amplitude: float = 5.0
@export var bob_speed: float = 2.0

# Victory type styling
@export_group("Victory Type Styles")
@export var elimination_text: String = "👑"
@export var elimination_color: Color = Color.GOLD
@export var score_based_text: String = "🏆"
@export var score_based_color: Color = Color.ORANGE
@export var time_based_text: String = "⏰"
@export var time_based_color: Color = Color.CYAN
@export var custom_text: String = "⭐"
@export var custom_color: Color = Color.PURPLE

# Manager configuration
@export_group("Manager Settings")
@export var update_frequency: float = 0.5  # How often to check for crown updates (seconds)
@export var victory_tie_breaker: String = "player_id"  # "player_id", "random", "first"

## Get crown style for a specific victory type
func get_style_for_victory_type(victory_type: String) -> Dictionary:
	match victory_type:
		"ELIMINATION":
			return {"text": elimination_text, "color": elimination_color}
		"SCORE_BASED":
			return {"text": score_based_text, "color": score_based_color}
		"TIME_BASED":
			return {"text": time_based_text, "color": time_based_color}
		"CUSTOM":
			return {"text": custom_text, "color": custom_color}
		_:
			return {"text": crown_text, "color": crown_color} 