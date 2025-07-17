class_name ScreenManager
extends Node

## Screen Manager for UI Navigation
## Handles screen stack, transitions, and navigation flow

# Screen stack management
var screen_stack: Array[Control] = []
var transition_in_progress: bool = false

# Screen management signals
signal screen_pushed(screen_name: String)
signal screen_popped(screen_name: String)
signal screen_transition_started(from_screen: String, to_screen: String)
signal screen_transition_completed(to_screen: String)

# Transition settings
@export var default_transition_duration: float = 0.3
@export var transition_type: TransitionType = TransitionType.FADE

enum TransitionType {
	NONE,
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
	SLIDE_UP,
	SLIDE_DOWN
}

func _ready() -> void:
	Logger.system("ScreenManager initialized", "ScreenManager")

## Push a new screen onto the stack
func push_screen(screen_scene: PackedScene, screen_name: String = "") -> Control:
	if transition_in_progress:
		Logger.warning("Screen transition already in progress, rejecting push", "ScreenManager")
		return null
	
	var new_screen: Control = screen_scene.instantiate()
	var resolved_screen_name: String = screen_name if screen_name != "" else new_screen.get_class()
	new_screen.name = resolved_screen_name
	
	# Get current screen for transition
	var current_screen: Control = get_current_screen()
	var from_screen_name: String = str(current_screen.name) if current_screen else "None"
	
	# Start transition
	transition_in_progress = true
	screen_transition_started.emit(from_screen_name, resolved_screen_name)
	
	# Add new screen to stack
	screen_stack.append(new_screen)
	
	# Add to scene tree (initially hidden)
	get_tree().current_scene.add_child(new_screen)
	new_screen.visible = false
	
	# Perform transition
	await _perform_screen_transition(current_screen, new_screen, true)
	
	# Complete transition
	transition_in_progress = false
	screen_pushed.emit(resolved_screen_name)
	screen_transition_completed.emit(resolved_screen_name)
	
	Logger.debug("Pushed screen: " + resolved_screen_name, "ScreenManager")
	return new_screen

## Pop the current screen from the stack
func pop_screen() -> Control:
	if transition_in_progress:
		Logger.warning("Screen transition already in progress, rejecting pop", "ScreenManager")
		return null
	
	if screen_stack.size() <= 1:
		Logger.warning("Cannot pop screen - only one or no screens in stack", "ScreenManager")
		return null
	
	# Get screens for transition
	var current_screen: Control = screen_stack.pop_back()
	var previous_screen: Control = get_current_screen()
	
	var from_screen_name: String = str(current_screen.name) if current_screen else "None"
	var to_screen_name: String = str(previous_screen.name) if previous_screen else "None"
	
	# Start transition
	transition_in_progress = true
	screen_transition_started.emit(from_screen_name, to_screen_name)
	
	# Perform transition
	await _perform_screen_transition(current_screen, previous_screen, false)
	
	# Clean up popped screen
	current_screen.queue_free()
	
	# Complete transition
	transition_in_progress = false
	screen_popped.emit(from_screen_name)
	screen_transition_completed.emit(to_screen_name)
	
	Logger.debug("Popped screen: " + from_screen_name, "ScreenManager")
	return previous_screen

## Get the current top screen
func get_current_screen() -> Control:
	if screen_stack.is_empty():
		return null
	return screen_stack.back()

## Clear all screens from the stack
func clear_screen_stack() -> void:
	if transition_in_progress:
		Logger.warning("Cannot clear screen stack during transition", "ScreenManager")
		return
	
	# Clean up all screens except the first (base screen)
	for i in range(screen_stack.size() - 1, 0, -1):
		var screen: Control = screen_stack[i]
		# Remove from parent first to break references
		if screen.get_parent():
			screen.get_parent().remove_child(screen)
		screen.queue_free()
		screen_stack.remove_at(i)
	
	Logger.debug("Cleared screen stack, " + str(screen_stack.size()) + " screens remaining", "ScreenManager")

## Replace current screen with a new one
func replace_current_screen(screen_scene: PackedScene, screen_name: String = "") -> Control:
	if transition_in_progress:
		Logger.warning("Screen transition already in progress, rejecting replace", "ScreenManager")
		return null
	
	# Pop current screen first
	if screen_stack.size() > 0:
		var current_screen: Control = screen_stack.pop_back()
		current_screen.queue_free()
	
	# Push new screen
	return await push_screen(screen_scene, screen_name)

## Set transition type for future transitions
func set_transition_type(type: TransitionType) -> void:
	transition_type = type
	Logger.debug("Transition type set to: " + TransitionType.keys()[type], "ScreenManager")

## Set transition duration
func set_transition_duration(duration: float) -> void:
	default_transition_duration = duration
	Logger.debug("Transition duration set to: " + str(duration) + "s", "ScreenManager")

## Check if a transition is currently in progress
func is_transition_in_progress() -> bool:
	return transition_in_progress

## Get the number of screens in the stack
func get_screen_count() -> int:
	return screen_stack.size()

## Perform screen transition animation
func _perform_screen_transition(from_screen: Control, to_screen: Control, is_push: bool) -> void:
	if not to_screen:
		return
	
	match transition_type:
		TransitionType.NONE:
			_perform_no_transition(from_screen, to_screen)
		TransitionType.FADE:
			await _perform_fade_transition(from_screen, to_screen)
		TransitionType.SLIDE_LEFT:
			await _perform_slide_transition(from_screen, to_screen, Vector2(-1, 0))
		TransitionType.SLIDE_RIGHT:
			await _perform_slide_transition(from_screen, to_screen, Vector2(1, 0))
		TransitionType.SLIDE_UP:
			await _perform_slide_transition(from_screen, to_screen, Vector2(0, -1))
		TransitionType.SLIDE_DOWN:
			await _perform_slide_transition(from_screen, to_screen, Vector2(0, 1))

## No transition - instant swap
func _perform_no_transition(from_screen: Control, to_screen: Control) -> void:
	if from_screen:
		from_screen.visible = false
	to_screen.visible = true

## Fade transition
func _perform_fade_transition(from_screen: Control, to_screen: Control) -> void:
	# Setup initial states
	to_screen.visible = true
	to_screen.modulate.a = 0.0
	
	# Create tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Fade out current screen
	if from_screen:
		tween.tween_property(from_screen, "modulate:a", 0.0, default_transition_duration * 0.5)
	
	# Fade in new screen
	tween.tween_property(to_screen, "modulate:a", 1.0, default_transition_duration * 0.5).set_delay(default_transition_duration * 0.5)
	
	await tween.finished
	
	# Clean up
	if from_screen:
		from_screen.visible = false
		from_screen.modulate.a = 1.0
	to_screen.modulate.a = 1.0

## Slide transition
func _perform_slide_transition(from_screen: Control, to_screen: Control, direction: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2 = direction * screen_size
	
	# Setup initial states
	to_screen.visible = true
	to_screen.position = offset
	
	# Create tween
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Slide out current screen
	if from_screen:
		tween.tween_property(from_screen, "position", -offset, default_transition_duration)
	
	# Slide in new screen
	tween.tween_property(to_screen, "position", Vector2.ZERO, default_transition_duration)
	
	await tween.finished
	
	# Clean up
	if from_screen:
		from_screen.visible = false
		from_screen.position = Vector2.ZERO
	to_screen.position = Vector2.ZERO 

## Cleanup screen manager on exit
func _exit_tree() -> void:
	# Clear all screens to prevent CanvasItem RID leaks
	for screen in screen_stack:
		if screen and is_instance_valid(screen):
			if screen.get_parent():
				screen.get_parent().remove_child(screen)
			screen.queue_free()
	
	screen_stack.clear()
	Logger.debug("ScreenManager cleanup completed", "ScreenManager") 
