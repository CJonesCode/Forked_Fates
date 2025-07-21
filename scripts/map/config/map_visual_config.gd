class_name MapVisualConfig
extends Resource

@export_group("Node Layout")
@export var node_size: Vector2 = Vector2(80, 60)
@export var layer_spacing: float = 150.0
@export var row_spacing: float = 100.0

@export_group("Node Colors")
@export var color_current: Color = Color.YELLOW
@export var color_available: Color = Color.WHITE
@export var color_visited: Color = Color.LIGHT_GRAY
@export var color_locked: Color = Color.DIM_GRAY

@export_group("Connection Lines")
@export var line_width: float = 3.0
@export var line_color: Color = Color(0.7, 0.7, 0.7, 0.8)
@export var line_color_visited: Color = Color(0.2, 0.2, 0.2, 0.9)  # Black for visited connections
@export var dash_pattern_enabled: bool = true
@export var dash_length: float = 20.0

@export_group("Layout Margins")
@export var container_margin: Vector2 = Vector2(20, 20)
@export var content_padding: Vector2 = Vector2(10, 10)

@export_group("Node Styling")
@export var corner_radius: float = 8.0
@export var border_width: float = 2.0
@export var border_color_multiplier: float = 0.3  # How much to darken border vs background

@export_group("Fonts")
@export var font_size: int = 14
@export var font_color: Color = Color.BLACK
