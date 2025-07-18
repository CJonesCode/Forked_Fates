class_name ScreenConfig
extends Resource

## Screen configuration for UIFactory
## Defines how screens should be created and styled

@export var screen_id: String = ""
@export var screen_name: String = ""
@export var screen_scene: PackedScene
@export var background_color: Color = Color.TRANSPARENT
@export var theme_path: String = "" 