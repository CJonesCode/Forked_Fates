class_name HUDController
extends Node

## HUD Controller for Game UI Management
## Manages player HUD display and updates during gameplay

# HUD state
var current_player_hud: PlayerHUD = null
var hud_visible: bool = false

# HUD management signals
signal hud_visibility_changed(visible: bool)
signal hud_updated(hud_data: Dictionary)

func _ready() -> void:
	Logger.system("HUDController initialized", "HUDController")

## Show player HUD for the given players
func show_player_hud(players: Array[PlayerData]) -> void:
	# Hide existing HUD first
	hide_player_hud()
	
	# Create new player HUD
	var player_hud_scene: PackedScene = preload("res://scenes/ui/player_hud.tscn")
	current_player_hud = player_hud_scene.instantiate()
	
	# Add to scene tree
	get_tree().current_scene.add_child(current_player_hud)
	
	# Setup for players
	if current_player_hud.has_method("setup_for_players"):
		current_player_hud.setup_for_players(players)
	
	# Make visible
	current_player_hud.visible = true
	hud_visible = true
	
	hud_visibility_changed.emit(true)
	Logger.debug("Player HUD shown for " + str(players.size()) + " players", "HUDController")

## Hide player HUD
func hide_player_hud() -> void:
	if current_player_hud:
		current_player_hud.queue_free()
		current_player_hud = null
		hud_visible = false
		hud_visibility_changed.emit(false)
		Logger.debug("Player HUD hidden", "HUDController")

## Toggle HUD visibility
func toggle_hud_visibility() -> void:
	if current_player_hud:
		current_player_hud.visible = not current_player_hud.visible
		hud_visible = current_player_hud.visible
		hud_visibility_changed.emit(hud_visible)
		Logger.debug("HUD visibility toggled: " + str(hud_visible), "HUDController")

## Update HUD with new data
func update_hud(update_data: Dictionary) -> void:
	if current_player_hud and current_player_hud.has_method("update_hud_data"):
		current_player_hud.update_hud_data(update_data)
		hud_updated.emit(update_data)

## Update specific player's health display
func update_player_health(player_id: int, current_health: int, max_health: int) -> void:
	if current_player_hud and current_player_hud.has_method("update_player_health"):
		current_player_hud.update_player_health(player_id, current_health, max_health)

## Update specific player's lives display
func update_player_lives(player_id: int, current_lives: int, max_lives: int) -> void:
	if current_player_hud and current_player_hud.has_method("update_player_lives"):
		current_player_hud.update_player_lives(player_id, current_lives, max_lives)

## Update player status (alive, dead, ragdolled, etc.)
func update_player_status(player_id: int, status: String) -> void:
	if current_player_hud and current_player_hud.has_method("update_player_status"):
		current_player_hud.update_player_status(player_id, status)

## Update respawn timer for a player
func update_respawn_timer(player_id: int, time_remaining: float) -> void:
	if current_player_hud and current_player_hud.has_method("update_respawn_timer"):
		current_player_hud.update_respawn_timer(player_id, time_remaining)

## Set HUD theme or style
func set_hud_theme(theme_name: String) -> void:
	if current_player_hud and current_player_hud.has_method("set_theme"):
		current_player_hud.set_theme(theme_name)
		Logger.debug("HUD theme set to: " + theme_name, "HUDController")

## Get current HUD instance for direct access
func get_current_hud() -> PlayerHUD:
	return current_player_hud

## Check if HUD is currently visible
func is_hud_visible() -> bool:
	return hud_visible and current_player_hud != null and current_player_hud.visible

## Create temporary notification overlay
func show_notification(message: String, duration: float = 3.0) -> void:
	# Always use UIFactory for consistent notification creation
	var notification_instance: Control = UIFactory.create_notification(message, UIFactory.NotificationType.INFO)
	if notification_instance:
		var notification_name: String = "notification_" + str(Time.get_unix_time_from_system())
		notification_instance = UIManager.show_overlay(notification_instance, notification_name)
		
		# Auto-remove after duration
		var timer: Timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.timeout.connect(func(): 
			UIManager.hide_overlay(notification_name)
			timer.queue_free()
		)
		get_tree().current_scene.add_child(timer)
		timer.start()
		
		Logger.debug("Notification shown through UIFactory + UIManager: " + message, "HUDController")
	else:
		Logger.error("Failed to create notification through UIFactory", "HUDController")

## Fallback notification system using UIFactory + UIManager
func _show_fallback_notification(message: String, duration: float) -> void:
	# Use UIFactory to create consistent notification
	var notification: Control = UIFactory.create_notification(message, UIFactory.NotificationType.INFO)
	if not notification:
		Logger.error("Failed to create notification through UIFactory", "HUDController")
		return
	
	# Use UIManager overlay system for proper notification management
	var notification_name: String = "notification_" + str(Time.get_unix_time_from_system())
	UIManager.show_overlay(notification, notification_name)
	
	# Auto-remove after duration
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): 
		UIManager.hide_overlay(notification_name)
		timer.queue_free()
	)
	get_tree().current_scene.add_child(timer)
	timer.start()

## Clean up HUD resources
func cleanup_hud() -> void:
	hide_player_hud()
	Logger.debug("HUD cleanup completed", "HUDController") 
