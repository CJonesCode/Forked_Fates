class_name ObjectIndicator
extends Control

## Individual object indicator that displays a single status element
## Can show text, sprites, custom shapes, or other visual elements
## Generalized system that works with any object, not just players

# Visual components
var label: Label
var texture_rect: TextureRect
var shape_rect: ColorRect
var custom_node: Node

# Data
var indicator_data: ObjectIndicatorData
var current_type: ObjectIndicatorManager.IndicatorType

func _ready() -> void:
	# Set control properties for proper sizing and centering
	custom_minimum_size = Vector2(24, 24)  # Default minimum size
	# Don't set anchors here - let the manager handle positioning

## Setup indicator from data configuration
func setup_from_data(data: ObjectIndicatorData) -> void:
	indicator_data = data
	current_type = data.type
	
	# Clear existing content
	_clear_content()
	
	# Create appropriate visual based on type
	match data.type:
		ObjectIndicatorManager.IndicatorType.TEXT:
			_create_text_indicator(data)
		ObjectIndicatorManager.IndicatorType.SPRITE:
			_create_sprite_indicator(data)
		ObjectIndicatorManager.IndicatorType.SHAPE:
			_create_shape_indicator(data)
		ObjectIndicatorManager.IndicatorType.CUSTOM:
			_create_custom_indicator(data)
	
	# Apply common properties
	_apply_common_properties(data)

## Update indicator with new data
func update_data(new_data: ObjectIndicatorData) -> void:
	# If type changed, recreate the indicator
	if new_data.type != current_type:
		setup_from_data(new_data)
		return
	
	# Otherwise update existing indicator
	indicator_data = new_data
	
	match current_type:
		ObjectIndicatorManager.IndicatorType.TEXT:
			_update_text_indicator(new_data)
		ObjectIndicatorManager.IndicatorType.SPRITE:
			_update_sprite_indicator(new_data)
		ObjectIndicatorManager.IndicatorType.SHAPE:
			_update_shape_indicator(new_data)
		ObjectIndicatorManager.IndicatorType.CUSTOM:
			_update_custom_indicator(new_data)
	
	_apply_common_properties(new_data)

## Get indicator category
func get_category() -> ObjectIndicatorManager.IndicatorCategory:
	if indicator_data:
		return indicator_data.category
	return ObjectIndicatorManager.IndicatorCategory.CUSTOM

## Clear all content
func _clear_content() -> void:
	for child in get_children():
		child.queue_free()
	
	label = null
	texture_rect = null
	shape_rect = null
	custom_node = null

## Create text-based indicator with improved centering
func _create_text_indicator(data: ObjectIndicatorData) -> void:
	label = Label.new()
	label.text = data.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# FIXED: Use CENTER preset for better crown alignment
	# This ensures the label is properly centered within the control
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# Actually, let's use FULL_RECT but ensure proper sizing
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
func _create_sprite_indicator(data: ObjectIndicatorData) -> void:
	texture_rect = TextureRect.new()
	texture_rect.texture = data.texture
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(texture_rect)

## Create shape-based indicator
func _create_shape_indicator(data: ObjectIndicatorData) -> void:
	shape_rect = ColorRect.new()
	shape_rect.color = data.color
	shape_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	add_child(shape_rect)

## Create custom indicator
func _create_custom_indicator(data: ObjectIndicatorData) -> void:
	if data.custom_scene:
		custom_node = data.custom_scene.instantiate()
		if custom_node:
			add_child(custom_node)
	elif data.custom_node_script:
		custom_node = data.custom_node_script.new()
		if custom_node:
			add_child(custom_node)

## Update text indicator
func _update_text_indicator(data: ObjectIndicatorData) -> void:
	if not label:
		return
	
	label.text = data.text
	
	if data.font_size > 0:
		label.add_theme_font_size_override("font_size", data.font_size)
	
	if data.color != Color.TRANSPARENT:
		label.add_theme_color_override("font_color", data.color)

## Update sprite indicator
func _update_sprite_indicator(data: ObjectIndicatorData) -> void:
	if not texture_rect:
		return
	
	texture_rect.texture = data.texture

## Update shape indicator
func _update_shape_indicator(data: ObjectIndicatorData) -> void:
	if not shape_rect:
		return
	
	shape_rect.color = data.color

## Update custom indicator
func _update_custom_indicator(data: ObjectIndicatorData) -> void:
	# Custom indicators handle their own updates
	if custom_node and custom_node.has_method("update_indicator_data"):
		custom_node.update_indicator_data(data)

## Apply common properties to all indicator types with improved centering
func _apply_common_properties(data: ObjectIndicatorData) -> void:
	# Set size and ensure it's properly sized for centering
	if data.size != Vector2.ZERO:
		custom_minimum_size = data.size
		size = data.size
	
	# FIXED: Better centering approach for crown alignment
	# Use anchor-based centering instead of manual position adjustment
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
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