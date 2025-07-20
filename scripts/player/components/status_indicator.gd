class_name StatusIndicator
extends Control

## Individual status indicator that displays a single status element
## Can show text, sprites, custom shapes, or other visual elements

# Visual components
var label: Label
var texture_rect: TextureRect
var shape_rect: ColorRect
var custom_node: Node

# Data
var indicator_data: StatusIndicatorData
var current_type: StatusIndicatorManager.IndicatorType

func _ready() -> void:
	# Set control properties for proper sizing
	custom_minimum_size = Vector2(24, 24)  # Default minimum size
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)

## Setup indicator from data configuration
func setup_from_data(data: StatusIndicatorData) -> void:
	indicator_data = data
	current_type = data.type
	
	# Clear existing content
	_clear_content()
	
	# Create appropriate visual based on type
	match data.type:
		StatusIndicatorManager.IndicatorType.TEXT:
			_create_text_indicator(data)
		StatusIndicatorManager.IndicatorType.SPRITE:
			_create_sprite_indicator(data)
		StatusIndicatorManager.IndicatorType.SHAPE:
			_create_shape_indicator(data)
		StatusIndicatorManager.IndicatorType.CUSTOM:
			_create_custom_indicator(data)
	
	# Apply common properties
	_apply_common_properties(data)

## Update indicator with new data
func update_data(new_data: StatusIndicatorData) -> void:
	# If type changed, recreate the indicator
	if new_data.type != current_type:
		setup_from_data(new_data)
		return
	
	# Otherwise update existing indicator
	indicator_data = new_data
	
	match current_type:
		StatusIndicatorManager.IndicatorType.TEXT:
			_update_text_indicator(new_data)
		StatusIndicatorManager.IndicatorType.SPRITE:
			_update_sprite_indicator(new_data)
		StatusIndicatorManager.IndicatorType.SHAPE:
			_update_shape_indicator(new_data)
		StatusIndicatorManager.IndicatorType.CUSTOM:
			_update_custom_indicator(new_data)
	
	_apply_common_properties(new_data)

## Get indicator category
func get_category() -> StatusIndicatorManager.IndicatorCategory:
	if indicator_data:
		return indicator_data.category
	return StatusIndicatorManager.IndicatorCategory.CUSTOM

## Clear all content
func _clear_content() -> void:
	for child in get_children():
		child.queue_free()
	
	label = null
	texture_rect = null
	shape_rect = null
	custom_node = null

## Create text-based indicator
func _create_text_indicator(data: StatusIndicatorData) -> void:
	label = Label.new()
	label.text = data.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Apply text styling
	if data.font_size > 0:
		label.add_theme_font_size_override("font_size", data.font_size)
	
	if data.color != Color.TRANSPARENT:
		label.add_theme_color_override("font_color", data.color)
	
	# Add effects
	if data.outline_size > 0:
		label.add_theme_color_override("font_outline_color", data.outline_color)
		label.add_theme_constant_override("outline_size", data.outline_size)
	
	if data.shadow_offset != Vector2.ZERO:
		label.add_theme_color_override("font_shadow_color", data.shadow_color)
		label.add_theme_constant_override("shadow_offset_x", int(data.shadow_offset.x))
		label.add_theme_constant_override("shadow_offset_y", int(data.shadow_offset.y))
	
	add_child(label)

## Create sprite-based indicator
func _create_sprite_indicator(data: StatusIndicatorData) -> void:
	texture_rect = TextureRect.new()
	texture_rect.texture = data.texture
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(texture_rect)

## Create shape-based indicator
func _create_shape_indicator(data: StatusIndicatorData) -> void:
	shape_rect = ColorRect.new()
	shape_rect.color = data.color
	shape_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(shape_rect)

## Create custom indicator
func _create_custom_indicator(data: StatusIndicatorData) -> void:
	if data.custom_scene:
		custom_node = data.custom_scene.instantiate()
		if custom_node:
			add_child(custom_node)
	elif data.custom_node_script:
		custom_node = data.custom_node_script.new()
		if custom_node:
			add_child(custom_node)

## Update text indicator
func _update_text_indicator(data: StatusIndicatorData) -> void:
	if not label:
		return
	
	label.text = data.text
	
	if data.font_size > 0:
		label.add_theme_font_size_override("font_size", data.font_size)
	
	if data.color != Color.TRANSPARENT:
		label.add_theme_color_override("font_color", data.color)

## Update sprite indicator
func _update_sprite_indicator(data: StatusIndicatorData) -> void:
	if not texture_rect:
		return
	
	texture_rect.texture = data.texture

## Update shape indicator
func _update_shape_indicator(data: StatusIndicatorData) -> void:
	if not shape_rect:
		return
	
	shape_rect.color = data.color

## Update custom indicator
func _update_custom_indicator(data: StatusIndicatorData) -> void:
	# Custom indicators handle their own updates
	if custom_node and custom_node.has_method("update_indicator_data"):
		custom_node.update_indicator_data(data)

## Apply common properties to all indicator types
func _apply_common_properties(data: StatusIndicatorData) -> void:
	# Set size
	if data.size != Vector2.ZERO:
		custom_minimum_size = data.size
		size = data.size
	
	# Set modulation
	if data.modulate != Color.WHITE:
		modulate = data.modulate
	
	# Set rotation
	if data.rotation != 0.0:
		rotation = data.rotation
	
	# Apply scale
	if data.scale != Vector2.ONE:
		scale = data.scale
	
	# Set tooltip
	if not data.tooltip.is_empty():
		tooltip_text = data.tooltip 