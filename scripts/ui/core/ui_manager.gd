extends Node

## Global UI Management System
## Coordinates all UI elements, screens, and HUD across the game

# UI State
var current_hud: Control = null
var screen_stack: Array[Control] = []
var overlay_stack: Array[Control] = []

# UI Management signals
signal screen_pushed(screen_name: String)
signal screen_popped(screen_name: String)
signal hud_visibility_changed(visible: bool)
signal overlay_shown(overlay_name: String)
signal overlay_hidden(overlay_name: String)

# References to UI controllers
var hud_controller: HUDController
var screen_manager: ScreenManager
var ui_event_router: UIEventRouter

func _ready() -> void:
	# Initialize UI controllers
	hud_controller = HUDController.new()
	screen_manager = ScreenManager.new()
	ui_event_router = UIEventRouter.new()
	
	add_child(hud_controller)
	add_child(screen_manager)
	add_child(ui_event_router)
	
	# Connect controller signals
	hud_controller.hud_visibility_changed.connect(_on_hud_visibility_changed)
	screen_manager.screen_pushed.connect(_on_screen_pushed)
	screen_manager.screen_popped.connect(_on_screen_popped)
	
	Logger.system("UIManager initialized with controllers", "UIManager")

## Show game HUD for players
func show_game_hud(players: Array[PlayerData]) -> void:
	hud_controller.show_player_hud(players)

## Hide game HUD
func hide_game_hud() -> void:
	hud_controller.hide_player_hud()

## Push a new screen onto the stack
func push_screen(screen_scene: PackedScene, screen_name: String = "") -> Control:
	return await screen_manager.push_screen(screen_scene, screen_name)

## Pop the current screen from the stack
func pop_screen() -> Control:
	return await screen_manager.pop_screen()

## Get the current top screen
func get_current_screen() -> Control:
	return screen_manager.get_current_screen()

## Show modal overlay (UIFactory-created Controls only)
func show_overlay(overlay_control: Control, overlay_name: String = "") -> Control:
	if not overlay_control:
		Logger.error("Cannot show null overlay control", "UIManager")
		return null
	
	var resolved_name: String = overlay_name if overlay_name != "" else overlay_control.get_class()
	overlay_control.name = resolved_name
	
	return _add_overlay_to_stack(overlay_control, resolved_name)

## DEPRECATED: Use UIFactory.create_screen() + show_overlay() instead
func show_overlay_from_scene(overlay_scene: PackedScene, overlay_name: String = "") -> Control:
	Logger.warning("show_overlay_from_scene() is deprecated. Use UIFactory.create_screen() + show_overlay() instead", "UIManager")
	var overlay: Control = overlay_scene.instantiate()
	overlay.name = overlay_name if overlay_name != "" else overlay.get_class()
	
	return _add_overlay_to_stack(overlay, overlay_name)

## Internal method to add overlay to stack and scene tree
func _add_overlay_to_stack(overlay: Control, overlay_name: String) -> Control:
	# Add to overlay stack
	overlay_stack.append(overlay)
	
	# Add to scene tree as top-level overlay
	get_tree().current_scene.add_child(overlay)
	overlay.z_index = 1000 + overlay_stack.size()  # Ensure it's on top
	
	overlay_shown.emit(overlay_name)
	Logger.debug("Showed overlay: " + overlay_name, "UIManager")
	
	return overlay

## Hide modal overlay
func hide_overlay(overlay_name: String = "") -> bool:
	if overlay_stack.is_empty():
		return false
	
	var overlay_to_remove: Control = null
	
	if overlay_name == "":
		# Remove top overlay
		overlay_to_remove = overlay_stack.pop_back()
	else:
		# Find specific overlay
		for i in range(overlay_stack.size()):
			if overlay_stack[i].name == overlay_name:
				overlay_to_remove = overlay_stack[i]
				overlay_stack.remove_at(i)
				break
	
	if overlay_to_remove:
		overlay_to_remove.queue_free()
		overlay_hidden.emit(overlay_to_remove.name)
		Logger.debug("Hid overlay: " + overlay_to_remove.name, "UIManager")
		return true
	
	return false

## Clear all overlays
func clear_all_overlays() -> void:
	for overlay in overlay_stack:
		overlay.queue_free()
	overlay_stack.clear()
	Logger.debug("Cleared all overlays", "UIManager")

## Route UI event through the event router
func route_ui_event(event_name: String, data: Dictionary = {}) -> void:
	ui_event_router.route_event(event_name, data)

## Check if any modal overlays are active
func has_active_overlays() -> bool:
	return not overlay_stack.is_empty()

## Get HUD controller for direct access
func get_hud_controller() -> HUDController:
	return hud_controller

## Get screen manager for direct access
func get_screen_manager() -> ScreenManager:
	return screen_manager

## Get UI event router for direct access  
func get_ui_event_router() -> UIEventRouter:
	return ui_event_router

# Signal handlers
func _on_hud_visibility_changed(visible: bool) -> void:
	hud_visibility_changed.emit(visible)

func _on_screen_pushed(screen_name: String) -> void:
	screen_pushed.emit(screen_name)

func _on_screen_popped(screen_name: String) -> void:
	screen_popped.emit(screen_name) 
