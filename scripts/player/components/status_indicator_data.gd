class_name StatusIndicatorData
extends Resource

## Configuration data for status indicators
## Defines the appearance and behavior of individual status indicators
##
## Duration system:
## • auto_remove_after = -1.0: infinite duration (default)
## • auto_remove_after = 0.0: remove immediately (flash effects)
## • auto_remove_after > 0.0: remove after X seconds (temporary effects)

# Core properties
@export var type: StatusIndicatorManager.IndicatorType = StatusIndicatorManager.IndicatorType.TEXT
@export var category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM
@export var priority: int = 0  # Higher priority indicators appear first

# Visual properties
@export var size: Vector2 = Vector2(24, 24)
@export var color: Color = Color.WHITE
@export var modulate: Color = Color.WHITE
@export var rotation: float = 0.0
@export var scale: Vector2 = Vector2.ONE

# Text properties (for TEXT type)
@export_group("Text Properties")
@export var text: String = ""
@export var font_size: int = 16
@export var outline_size: int = 0
@export var outline_color: Color = Color.BLACK
@export var shadow_offset: Vector2 = Vector2.ZERO
@export var shadow_color: Color = Color.BLACK

# Sprite properties (for SPRITE type)
@export_group("Sprite Properties")
@export var texture: Texture2D

# Custom properties (for CUSTOM type)
@export_group("Custom Properties")
@export var custom_scene: PackedScene
@export var custom_node_script: Script
@export var custom_data: Dictionary = {}

# Interaction properties
@export_group("Interaction")
@export var tooltip: String = ""
@export var clickable: bool = false

# Animation properties
@export_group("Animation")
@export var animate_entrance: bool = true
@export var animate_exit: bool = true
@export var pulse_on_update: bool = false
@export var auto_remove_after: float = -1.0  # -1 = never auto-remove, 0 = remove immediately, >0 = remove after X seconds

## Create a text indicator data
static func create_text(text: String, color: Color = Color.WHITE, font_size: int = 16, category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM) -> StatusIndicatorData:
	var data := StatusIndicatorData.new()
	data.type = StatusIndicatorManager.IndicatorType.TEXT
	data.category = category
	data.text = text
	data.color = color
	data.font_size = font_size
	return data

## Create a sprite indicator data
static func create_sprite(texture: Texture2D, size: Vector2 = Vector2(24, 24), category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM) -> StatusIndicatorData:
	var data := StatusIndicatorData.new()
	data.type = StatusIndicatorManager.IndicatorType.SPRITE
	data.category = category
	data.texture = texture
	data.size = size
	return data

## Create a shape indicator data
static func create_shape(color: Color, size: Vector2 = Vector2(24, 24), category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM) -> StatusIndicatorData:
	var data := StatusIndicatorData.new()
	data.type = StatusIndicatorManager.IndicatorType.SHAPE
	data.category = category
	data.color = color
	data.size = size
	return data

## Create a custom indicator data
static func create_custom(custom_scene: PackedScene = null, custom_script: Script = null, category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM) -> StatusIndicatorData:
	var data := StatusIndicatorData.new()
	data.type = StatusIndicatorManager.IndicatorType.CUSTOM
	data.category = category
	data.custom_scene = custom_scene
	data.custom_node_script = custom_script
	return data

## Create leadership indicator (crown/lead)
static func create_leadership_indicator(text: String = "👑", color: Color = Color.GOLD) -> StatusIndicatorData:
	var data := create_text(text, color, 20, StatusIndicatorManager.IndicatorCategory.LEADERSHIP)
	data.priority = 100  # High priority for leadership
	data.outline_size = 2
	data.outline_color = Color.BLACK
	data.shadow_offset = Vector2(2, 2)
	data.shadow_color = Color(0, 0, 0, 0.5)
	data.pulse_on_update = true
	return data

## Create buff indicator
static func create_buff_indicator(text: String, color: Color = Color.GREEN) -> StatusIndicatorData:
	var data := create_text(text, color, 14, StatusIndicatorManager.IndicatorCategory.BUFF)
	data.priority = 80
	data.outline_size = 1
	data.outline_color = Color.BLACK
	return data

## Create debuff indicator
static func create_debuff_indicator(text: String, color: Color = Color.RED) -> StatusIndicatorData:
	var data := create_text(text, color, 14, StatusIndicatorManager.IndicatorCategory.DEBUFF)
	data.priority = 70
	data.outline_size = 1
	data.outline_color = Color.BLACK
	return data

## Create team indicator
static func create_team_indicator(team_color: Color) -> StatusIndicatorData:
	var data := create_shape(team_color, Vector2(16, 16), StatusIndicatorManager.IndicatorCategory.TEAM)
	data.priority = 60
	return data

## Create objective indicator
static func create_objective_indicator(text: String = "🎯", color: Color = Color.CYAN) -> StatusIndicatorData:
	var data := create_text(text, color, 16, StatusIndicatorManager.IndicatorCategory.OBJECTIVE)
	data.priority = 90
	data.pulse_on_update = true
	return data

## Create temporary indicator with auto-removal
static func create_temporary_indicator(text: String, color: Color = Color.YELLOW, duration: float = 3.0) -> StatusIndicatorData:
	var data := create_text(text, color, 12)
	data.auto_remove_after = duration
	data.animate_entrance = true
	data.animate_exit = true
	return data

## Create permanent indicator that never auto-removes
static func create_permanent_indicator(text: String, color: Color = Color.WHITE, font_size: int = 16, category: StatusIndicatorManager.IndicatorCategory = StatusIndicatorManager.IndicatorCategory.CUSTOM) -> StatusIndicatorData:
	var data := create_text(text, color, font_size, category)
	data.auto_remove_after = -1.0  # Infinite duration - never auto-remove
	return data

## Create immediate removal indicator (for flash effects, etc.)
static func create_immediate_indicator(text: String, color: Color = Color.WHITE, font_size: int = 16) -> StatusIndicatorData:
	var data := create_text(text, color, font_size)
	data.auto_remove_after = 0.0  # Remove immediately on next frame
	data.animate_entrance = false  # No entrance animation for immediate removal
	return data

## Clone this indicator data
func clone() -> StatusIndicatorData:
	var new_data := StatusIndicatorData.new()
	
	# Copy all properties
	new_data.type = type
	new_data.category = category
	new_data.priority = priority
	new_data.size = size
	new_data.color = color
	new_data.modulate = modulate
	new_data.rotation = rotation
	new_data.scale = scale
	new_data.text = text
	new_data.font_size = font_size
	new_data.outline_size = outline_size
	new_data.outline_color = outline_color
	new_data.shadow_offset = shadow_offset
	new_data.shadow_color = shadow_color
	new_data.texture = texture
	new_data.custom_scene = custom_scene
	new_data.custom_node_script = custom_node_script
	new_data.custom_data = custom_data.duplicate()
	new_data.tooltip = tooltip
	new_data.clickable = clickable
	new_data.animate_entrance = animate_entrance
	new_data.animate_exit = animate_exit
	new_data.pulse_on_update = pulse_on_update
	new_data.auto_remove_after = auto_remove_after
	
	return new_data 