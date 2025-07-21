class_name ObjectIndicatorManager
extends Node2D

# Preload ObjectIndicator script to ensure it's available
const ObjectIndicatorScript = preload("res://scripts/player/components/object_indicator.gd")

## Universal indicator system for any object
## Displays multiple indicators above any object using a flexible container
## Supports text, sprites, and other visual elements for various status types
##
## AUTOMATIC CLEANUP: When the target object is destroyed, this manager is also cleaned up
##
## DURATION CONTROL: auto_remove_after values:
## • -1.0 = infinite duration (default)
## • 0.0 = remove immediately 
## • >0.0 = remove after X seconds

# Core container and animation (created dynamically if not present)
var indicator_container: HBoxContainer
var animation_player: AnimationPlayer

# Configuration
var float_height: float = -50.0
var indicator_spacing: int = 8
var bob_enabled: bool = true
var bob_amplitude: float = 3.0
var bob_speed: float = 2.0

# Fixed width scaling configuration
var max_width: float = -1.0  # -1 = no width constraint, >0 = max width in pixels
var scale_to_fit: bool = false  # Whether to scale indicators to fit within max_width
var maintain_aspect_ratio: bool = true  # Whether to maintain aspect ratio when scaling

# State tracking
var active_indicators: Dictionary = {}  # indicator_id -> ObjectIndicator
var auto_remove_timers: Dictionary = {}  # indicator_id -> float (remaining time)
var collections: Dictionary = {}  # collection_id -> {items: Dictionary, sort_key: String}
var base_offset: Vector2
var bob_timer: float = 0.0
var target_object: Node = null  # Generalized to any object

# Indicator types
enum IndicatorType {
	TEXT,
	SPRITE,
	SHAPE,
	CUSTOM
}

# Indicator categories for organization
enum IndicatorCategory {
	LEADERSHIP,      # Crown, lead indicators
	BUFF,           # Positive status effects
	DEBUFF,         # Negative status effects
	TEAM,           # Team indicators
	OBJECTIVE,      # Objective-related status
	CUSTOM          # Game-specific indicators
}

func _ready() -> void:
	_setup_container()
	_setup_animation_player()
	base_offset = Vector2(0, float_height)
	position = base_offset
	Logger.debug("ObjectIndicatorManager initialized", "ObjectIndicatorManager")

func _process(delta: float) -> void:
	if active_indicators.is_empty():
		return
	
	# Bob animation for the entire container
	if bob_enabled:
		bob_timer += delta * bob_speed
		var bob_offset = Vector2(0, sin(bob_timer) * bob_amplitude)
		position = base_offset + bob_offset
	
	# Handle auto-removal timers
	_process_auto_removal_timers(delta)

## Setup the horizontal container for indicators with improved centering
func _setup_container() -> void:
	if not indicator_container:
		indicator_container = HBoxContainer.new()
		indicator_container.name = "IndicatorContainer"
		add_child(indicator_container)
	
	# Configure container properties
	indicator_container.alignment = BoxContainer.ALIGNMENT_CENTER
	indicator_container.add_theme_constant_override("separation", indicator_spacing)
	
	# IMPROVED CENTERING: Ensure the container is properly centered
	# Use the most reliable centering approach for UI elements
	indicator_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Additional centering improvements for crown alignment
	indicator_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	indicator_container.grow_vertical = Control.GROW_DIRECTION_BOTH

## Setup animation player for entrance/exit effects
func _setup_animation_player() -> void:
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)

## Add an indicator to the display
func add_indicator(indicator_id: String, indicator_data: ObjectIndicatorData) -> bool:
	if active_indicators.has(indicator_id):
		Logger.warning("Indicator already exists: " + indicator_id, "ObjectIndicatorManager")
		return false
	
	var indicator = _create_indicator(indicator_data)
	if not indicator:
		Logger.error("Failed to create indicator: " + indicator_id, "ObjectIndicatorManager")
		return false
	
	# Add to container and track
	indicator_container.add_child(indicator)
	active_indicators[indicator_id] = indicator
	
	# Setup auto-removal if specified (>= 0.0 means timed removal, -1.0 means infinite)
	if indicator_data.auto_remove_after >= 0.0:
		auto_remove_timers[indicator_id] = indicator_data.auto_remove_after
	
	# Play entrance animation
	_animate_indicator_entrance(indicator)
	
	# Update container visibility and scaling
	_update_container_visibility()
	_apply_width_scaling()
	
	Logger.debug("Added indicator: " + indicator_id + " (" + str(indicator_data.type) + ")", "ObjectIndicatorManager")
	return true

## Remove an indicator from the display
func remove_indicator(indicator_id: String, animate: bool = true) -> bool:
	if not active_indicators.has(indicator_id):
		return false
	
	var indicator = active_indicators[indicator_id]
	active_indicators.erase(indicator_id)
	
	# Clean up auto-removal timer if it exists
	if auto_remove_timers.has(indicator_id):
		auto_remove_timers.erase(indicator_id)
	
	if animate:
		# Animate out then remove
		_animate_indicator_exit(indicator)
		await get_tree().create_timer(0.3).timeout  # Wait for animation
	
	if is_instance_valid(indicator) and indicator.get_parent():
		indicator.get_parent().remove_child(indicator)
		indicator.queue_free()
	
	# Update container visibility and scaling
	_update_container_visibility()
	_apply_width_scaling()
	
	Logger.debug("Removed indicator: " + indicator_id, "ObjectIndicatorManager")
	return true

## Update an existing indicator
func update_indicator(indicator_id: String, new_data: ObjectIndicatorData) -> bool:
	if not active_indicators.has(indicator_id):
		return false
	
	var indicator = active_indicators[indicator_id]
	indicator.update_data(new_data)
	
	Logger.debug("Updated indicator: " + indicator_id, "ObjectIndicatorManager")
	return true

## Remove all indicators
func clear_indicators(animate: bool = true) -> void:
	var indicator_ids: Array = active_indicators.keys()
	for indicator_id in indicator_ids:
		await remove_indicator(indicator_id, animate)
	
	# Clear any remaining timers
	auto_remove_timers.clear()
	
	# Clear all collections
	collections.clear()

## COLLECTION SUPPORT - Add an indicator to a collection with automatic sorting
func add_collection_indicator(collection_id: String, item_id: String, indicator_data: ObjectIndicatorData, sort_priority: float = 0.0) -> bool:
	# Initialize collection if it doesn't exist
	if not collections.has(collection_id):
		collections[collection_id] = {
			"items": {},
			"sort_key": "priority"
		}
	
	var collection = collections[collection_id]
	var full_id = _get_collection_indicator_id(collection_id, item_id)
	
	# Store item with sort priority
	collection.items[item_id] = {
		"data": indicator_data,
		"priority": sort_priority,
		"full_id": full_id
	}
	
	# Add the indicator using the standard system
	var success = add_indicator(full_id, indicator_data)
	if not success:
		collection.items.erase(item_id)
		return false
	
	# Re-sort the collection to maintain order
	_sort_collection(collection_id)
	
	Logger.debug("Added collection indicator: " + collection_id + "." + item_id + " (priority=" + str(sort_priority) + ")", "ObjectIndicatorManager")
	return true

## Remove an indicator from a collection
func remove_collection_indicator(collection_id: String, item_id: String, animate: bool = true) -> bool:
	if not collections.has(collection_id):
		return false
	
	var collection = collections[collection_id]
	if not collection.items.has(item_id):
		return false
	
	var item = collection.items[item_id]
	var full_id = item.full_id
	
	# Remove from the standard indicator system
	var success = await remove_indicator(full_id, animate)
	if success:
		collection.items.erase(item_id)
		
		# Clean up empty collection
		if collection.items.is_empty():
			collections.erase(collection_id)
		else:
			# Re-sort remaining items
			_sort_collection(collection_id)
	
	Logger.debug("Removed collection indicator: " + collection_id + "." + item_id, "ObjectIndicatorManager")
	return success

## Clear all indicators in a collection
func clear_collection(collection_id: String, animate: bool = true) -> void:
	if not collections.has(collection_id):
		return
	
	var collection = collections[collection_id]
	var item_ids = collection.items.keys()
	
	for item_id in item_ids:
		await remove_collection_indicator(collection_id, item_id, animate)

## Update sort priority for a collection item
func update_collection_priority(collection_id: String, item_id: String, new_priority: float) -> bool:
	if not collections.has(collection_id):
		return false
	
	var collection = collections[collection_id]
	if not collection.items.has(item_id):
		return false
	
	collection.items[item_id].priority = new_priority
	_sort_collection(collection_id)
	
	Logger.debug("Updated collection priority: " + collection_id + "." + item_id + " (priority=" + str(new_priority) + ")", "ObjectIndicatorManager")
	return true

## Get collection indicator count
func get_collection_count(collection_id: String) -> int:
	if not collections.has(collection_id):
		return 0
	return collections[collection_id].items.size()

## Check if collection has a specific item
func has_collection_indicator(collection_id: String, item_id: String) -> bool:
	if not collections.has(collection_id):
		return false
	return collections[collection_id].items.has(item_id)

## Internal: Generate unique ID for collection items
func _get_collection_indicator_id(collection_id: String, item_id: String) -> String:
	return collection_id + "_" + item_id

## Internal: Sort collection items by priority (higher priority first)
func _sort_collection(collection_id: String) -> void:
	if not collections.has(collection_id):
		return
	
	var collection = collections[collection_id]
	var items = collection.items
	
	# Create sorted array of item keys by priority
	var sorted_items = items.keys()
	sorted_items.sort_custom(func(a, b): return items[a].priority > items[b].priority)
	
	# Reorder indicators in container to match sort order
	for i in range(sorted_items.size()):
		var item_id = sorted_items[i]
		var full_id = items[item_id].full_id
		
		if active_indicators.has(full_id):
			var indicator = active_indicators[full_id]
			# Move indicator to correct position in container
			var current_index = indicator.get_index()
			if current_index != i:
				indicator_container.move_child(indicator, i)
	
	# Apply scaling after reordering
	_apply_width_scaling()

## Check if an indicator exists
func has_indicator(indicator_id: String) -> bool:
	return active_indicators.has(indicator_id)

## Get all active indicator IDs
func get_active_indicators() -> Array[String]:
	var result: Array[String] = []
	for id in active_indicators.keys():
		result.append(id)
	return result

## Get indicators by category
func get_indicators_by_category(category: IndicatorCategory) -> Array[String]:
	var result: Array[String] = []
	for indicator_id in active_indicators.keys():
		var indicator = active_indicators[indicator_id]
		if indicator.get_category() == category:
			result.append(indicator_id)
	return result

## Attach indicator manager to any object
func attach_to_object(object: Node) -> void:
	if target_object == object:
		return
	
	# Detach from previous object if any
	if target_object:
		detach_from_object()
	
	target_object = object
	
	# Add as child to object
	object.add_child(self)
	
	# Position above object
	position = base_offset
	
	var object_name = object.name if object else "Unknown"
	Logger.debug("ObjectIndicatorManager attached to object: " + object_name, "ObjectIndicatorManager")

## Detach from current object
func detach_from_object() -> void:
	if not target_object:
		return
	
	var previous_object = target_object
	target_object = null
	
	# Remove from object
	if get_parent() == previous_object:
		previous_object.remove_child(self)
	
	Logger.debug("ObjectIndicatorManager detached from object", "ObjectIndicatorManager")

## Create a specific indicator based on data
func _create_indicator(indicator_data: ObjectIndicatorData):
	var indicator = ObjectIndicatorScript.new()
	indicator.setup_from_data(indicator_data)
	return indicator

## Animate indicator entrance
func _animate_indicator_entrance(indicator) -> void:
	if not indicator:
		return
	
	# Start from small scale
	indicator.scale = Vector2(0.1, 0.1)
	indicator.modulate.a = 0.0
	
	# Animate to full scale and opacity
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(indicator, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(indicator, "modulate:a", 1.0, 0.3)

## Animate indicator exit
func _animate_indicator_exit(indicator) -> void:
	if not indicator:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(indicator, "scale", Vector2(0.1, 0.1), 0.3)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.3)

## Update container visibility based on active indicators
func _update_container_visibility() -> void:
	var should_be_visible = not active_indicators.is_empty()
	
	if visible != should_be_visible:
		visible = should_be_visible
		
		if should_be_visible:
			_animate_container_entrance()
		else:
			_animate_container_exit()

## Animate entire container entrance
func _animate_container_entrance() -> void:
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)
	tween.tween_property(self, "modulate:a", 1.0, 0.4)

## Animate entire container exit
func _animate_container_exit() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

## Process auto-removal timers for temporary indicators
## auto_remove_after = -1.0: infinite duration (no timer)
## auto_remove_after = 0.0: remove immediately 
## auto_remove_after > 0.0: remove after X seconds
func _process_auto_removal_timers(delta: float) -> void:
	var indicators_to_remove: Array[String] = []
	
	# Update timers and collect expired indicators
	for indicator_id in auto_remove_timers.keys():
		auto_remove_timers[indicator_id] -= delta
		if auto_remove_timers[indicator_id] <= 0.0:
			indicators_to_remove.append(indicator_id)
	
	# Remove expired indicators
	for indicator_id in indicators_to_remove:
		remove_indicator(indicator_id, true)

## Apply width constraint by scaling content to fit container width
func _apply_width_scaling() -> void:
	if not scale_to_fit or max_width <= 0.0 or not indicator_container:
		# Reset container constraints if disabled
		_reset_container_constraints()
		return
	
	# Calculate current content width
	var total_width = _calculate_total_width()
	
	# Set container to exactly max_width
	indicator_container.custom_minimum_size.x = max_width
	
	if total_width <= max_width:
		# Content fits naturally, no scaling needed
		_reset_indicator_scaling()
		return
	
	# Content exceeds max_width, scale it down to fit
	var scale_factor = max_width / total_width
	
	# Apply scaling to all indicators to fit within container width
	for indicator in active_indicators.values():
		if indicator and is_instance_valid(indicator):
			if maintain_aspect_ratio:
				# Uniform scaling (maintains aspect ratio)
				indicator.scale = Vector2(scale_factor, scale_factor)
			else:
				# Non-uniform scaling (compress horizontally, keep height)
				indicator.scale = Vector2(scale_factor, 1.0)

## Calculate total width needed for all indicators including spacing
func _calculate_total_width() -> float:
	if not indicator_container:
		return 0.0
	
	var children = indicator_container.get_children()
	if children.is_empty():
		return 0.0
	
	var total_width = 0.0
	
	for i in range(children.size()):
		var child = children[i]
		if child and is_instance_valid(child):
			# Get the child's size (considering current scale)
			var child_size = child.size * child.scale.x
			total_width += child_size.x
			
			# Add spacing between items (not after the last item)
			if i < children.size() - 1:
				total_width += indicator_spacing
	
	return total_width

## Reset container constraints to original state
func _reset_container_constraints() -> void:
	if indicator_container:
		indicator_container.custom_minimum_size = Vector2.ZERO
	_reset_indicator_scaling()

## Reset all indicator scaling to original size
func _reset_indicator_scaling() -> void:
	for indicator in active_indicators.values():
		if indicator and is_instance_valid(indicator):
			indicator.scale = Vector2.ONE

## Set fixed width constraints
func set_width_constraints(max_width_pixels: float, enable_scaling: bool = true, keep_aspect_ratio: bool = true) -> void:
	max_width = max_width_pixels
	scale_to_fit = enable_scaling
	maintain_aspect_ratio = keep_aspect_ratio
	
	# Apply new constraints immediately
	_apply_width_scaling()
	
	Logger.debug("Set width constraints: max_width=" + str(max_width) + ", scale_to_fit=" + str(scale_to_fit) + ", maintain_aspect=" + str(maintain_aspect_ratio), "ObjectIndicatorManager")

## Cleanup on removal
## Note: When target object is destroyed, this manager is also cleaned up automatically
func _exit_tree() -> void:
	clear_indicators(false)  # No animation during cleanup
	auto_remove_timers.clear()
	
	if target_object:
		target_object = null
	
	Logger.debug("ObjectIndicatorManager cleanup completed (automatic via target object destruction)", "ObjectIndicatorManager") 
