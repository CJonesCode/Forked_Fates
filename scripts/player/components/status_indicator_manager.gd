class_name StatusIndicatorManager
extends Node2D

## Universal status indicator system for players
## Displays multiple indicators above player characters using a flexible container
## Supports text, sprites, and other visual elements for various status types
##
## AUTOMATIC CLEANUP: BasePlayer instances are destroyed between minigames,
## so all status indicators are automatically cleaned up without manual intervention
##
## DURATION CONTROL: auto_remove_after values:
## • -1.0 = infinite duration (default)
## • 0.0 = remove immediately 
## • >0.0 = remove after X seconds

# Core container and animation
@onready var indicator_container: HBoxContainer = $IndicatorContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Configuration
var float_height: float = -50.0
var indicator_spacing: int = 8
var bob_enabled: bool = true
var bob_amplitude: float = 3.0
var bob_speed: float = 2.0

# State tracking
var active_indicators: Dictionary = {}  # indicator_id -> StatusIndicator
var auto_remove_timers: Dictionary = {}  # indicator_id -> float (remaining time)
var base_offset: Vector2
var bob_timer: float = 0.0
var target_player: BasePlayer = null

# Status indicator types
enum IndicatorType {
	TEXT,
	SPRITE,
	SHAPE,
	CUSTOM
}

# Status indicator categories for organization
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
	Logger.debug("StatusIndicatorManager initialized", "StatusIndicatorManager")

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

## Setup the horizontal container for indicators
func _setup_container() -> void:
	if not indicator_container:
		indicator_container = HBoxContainer.new()
		indicator_container.name = "IndicatorContainer"
		add_child(indicator_container)
	
	# Configure container properties
	indicator_container.alignment = BoxContainer.ALIGNMENT_CENTER
	indicator_container.add_theme_constant_override("separation", indicator_spacing)
	
	# Center the container
	indicator_container.anchor_left = 0.5
	indicator_container.anchor_right = 0.5
	indicator_container.anchor_top = 0.5
	indicator_container.anchor_bottom = 0.5
	indicator_container.offset_left = 0
	indicator_container.offset_right = 0
	indicator_container.offset_top = 0
	indicator_container.offset_bottom = 0

## Setup animation player for entrance/exit effects
func _setup_animation_player() -> void:
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)

## Add a status indicator to the display
func add_indicator(indicator_id: String, indicator_data: StatusIndicatorData) -> bool:
	if active_indicators.has(indicator_id):
		Logger.warning("Indicator already exists: " + indicator_id, "StatusIndicatorManager")
		return false
	
	var indicator: StatusIndicator = _create_indicator(indicator_data)
	if not indicator:
		Logger.error("Failed to create indicator: " + indicator_id, "StatusIndicatorManager")
		return false
	
	# Add to container and track
	indicator_container.add_child(indicator)
	active_indicators[indicator_id] = indicator
	
	# Setup auto-removal if specified (>= 0.0 means timed removal, -1.0 means infinite)
	if indicator_data.auto_remove_after >= 0.0:
		auto_remove_timers[indicator_id] = indicator_data.auto_remove_after
	
	# Play entrance animation
	_animate_indicator_entrance(indicator)
	
	# Update container visibility
	_update_container_visibility()
	
	Logger.debug("Added indicator: " + indicator_id + " (" + str(indicator_data.type) + ")", "StatusIndicatorManager")
	return true

## Remove a status indicator from the display
func remove_indicator(indicator_id: String, animate: bool = true) -> bool:
	if not active_indicators.has(indicator_id):
		return false
	
	var indicator: StatusIndicator = active_indicators[indicator_id]
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
	
	# Update container visibility
	_update_container_visibility()
	
	Logger.debug("Removed indicator: " + indicator_id, "StatusIndicatorManager")
	return true

## Update an existing indicator
func update_indicator(indicator_id: String, new_data: StatusIndicatorData) -> bool:
	if not active_indicators.has(indicator_id):
		return false
	
	var indicator: StatusIndicator = active_indicators[indicator_id]
	indicator.update_data(new_data)
	
	Logger.debug("Updated indicator: " + indicator_id, "StatusIndicatorManager")
	return true

## Remove all indicators
func clear_indicators(animate: bool = true) -> void:
	var indicator_ids: Array = active_indicators.keys()
	for indicator_id in indicator_ids:
		remove_indicator(indicator_id, animate)
	
	# Clear any remaining timers
	auto_remove_timers.clear()

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
		var indicator: StatusIndicator = active_indicators[indicator_id]
		if indicator.get_category() == category:
			result.append(indicator_id)
	return result

## Attach indicator manager to a player
func attach_to_player(player: BasePlayer) -> void:
	if target_player == player:
		return
	
	# Detach from previous player if any
	if target_player:
		detach_from_player()
	
	target_player = player
	
	# Add as child to player
	player.add_child(self)
	
	# Position above player
	position = base_offset
	
	Logger.debug("StatusIndicatorManager attached to player: " + player.player_data.player_name, "StatusIndicatorManager")

## Detach from current player
func detach_from_player() -> void:
	if not target_player:
		return
	
	var previous_player = target_player
	target_player = null
	
	# Remove from player
	if get_parent() == previous_player:
		previous_player.remove_child(self)
	
	Logger.debug("StatusIndicatorManager detached from player", "StatusIndicatorManager")

## Create a specific indicator based on data
func _create_indicator(indicator_data: StatusIndicatorData) -> StatusIndicator:
	var indicator: StatusIndicator = StatusIndicator.new()
	indicator.setup_from_data(indicator_data)
	return indicator

## Animate indicator entrance
func _animate_indicator_entrance(indicator: StatusIndicator) -> void:
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
func _animate_indicator_exit(indicator: StatusIndicator) -> void:
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

## Cleanup on removal
## Note: BasePlayer instances are destroyed between minigames, so this provides
## automatic cleanup without manual intervention needed
func _exit_tree() -> void:
	clear_indicators(false)  # No animation during cleanup
	auto_remove_timers.clear()
	
	if target_player:
		target_player = null
	
	Logger.debug("StatusIndicatorManager cleanup completed (automatic via BasePlayer destruction)", "StatusIndicatorManager") 