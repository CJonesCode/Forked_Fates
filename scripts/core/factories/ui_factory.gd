class_name UIFactory
extends RefCounted

# Enums and configuration classes defined first to avoid parser errors
enum UIElementType {
	BUTTON,
	LABEL,
	PANEL,
	PROGRESS_BAR,
	MENU,
	DIALOG,
	HUD_ELEMENT
}

enum NotificationType {
	INFO,
	WARNING,
	ERROR,
	SUCCESS
}

# Base configuration for UI elements
class UIElementConfig extends Resource:
	@export var element_name: String = ""
	@export var text: String = ""
	@export var description: String = ""
	@export var size: Vector2 = Vector2.ZERO
	@export var position: Vector2 = Vector2.ZERO
	@export var anchor_preset: int = -1
	@export var theme_path: String = ""
	@export var action_method: String = ""
	@export var action_params: Dictionary = {}

	# Progress bar specific properties
	@export var min_value: float = 0.0
	@export var max_value: float = 100.0
	@export var initial_value: float = 0.0

	# Label specific properties
	@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	@export var vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_TOP

# ScreenConfig now defined in separate file: configs/ui_configs/screen_config.gd

# HUD configuration
class HUDConfig extends Resource:
	@export var hud_id: String = ""
	@export var hud_name: String = ""
	@export var hud_scene: PackedScene
	@export var player_elements: Array[UIElementConfig] = []

# Menu configuration
class MenuConfig extends Resource:
	@export var menu_name: String = ""
	@export var menu_items: Array[UIElementConfig] = []
	@export var layout_type: String = "vertical"  # "vertical", "horizontal", "grid"

# Notification configuration
class NotificationConfig extends Resource:
	@export var background_color: Color = Color.WHITE
	@export var text_color: Color = Color.BLACK
	@export var font_size: int = 16
	@export var duration: float = 3.0

# Static factory methods for UI creation
static func create_ui_element(element_type: UIElementType, config: UIElementConfig = null) -> Node:
	var element: Node
	
	match element_type:
		UIElementType.BUTTON:
			element = _create_button(config)
		UIElementType.LABEL:
			element = _create_label(config)
		UIElementType.PANEL:
			element = _create_panel(config)
		UIElementType.PROGRESS_BAR:
			element = _create_progress_bar(config)
		UIElementType.MENU:
			element = _create_menu(config)
		UIElementType.DIALOG:
			element = _create_dialog(config)
		UIElementType.HUD_ELEMENT:
			element = _create_hud_element(config)
		_:
			Logger.error("Unknown UI element type: " + str(element_type))
			return null
	
	# Only apply styling to Control nodes
	if element and config and element is Control:
		_apply_common_styling(element as Control, config)
	
	return element

static func create_screen(screen_id: String) -> Control:
	var screen_config: ScreenConfig = _load_screen_config(screen_id)
	if not screen_config:
		Logger.error("Failed to load screen config for: " + screen_id)
		return null
	
	var screen: Control = screen_config.screen_scene.instantiate()
	if screen:
		_apply_screen_styling(screen, screen_config)
	
	return screen

## Get screen PackedScene for UIManager integration
static func get_screen_scene(screen_id: String) -> PackedScene:
	var screen_config: ScreenConfig = _load_screen_config(screen_id)
	if not screen_config:
		Logger.error("Failed to load screen config for: " + screen_id)
		return null
	
	return screen_config.screen_scene

## Create specialized player panel for HUD display
static func create_player_panel(player_data: PlayerData, player_id: int, player_colors: Array[Color]) -> Control:
	if player_id >= player_colors.size():
		Logger.error("Player ID " + str(player_id) + " out of range for color array", "UIFactory")
		return null
	
	var panel = PanelContainer.new()
	panel.name = "Player" + str(player_id) + "Panel"
	
	# Panel styling
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = player_colors[player_id]
	style_box.bg_color.a = 0.8  # Semi-transparent
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.border_color = player_colors[player_id]
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Content container
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Player name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = player_data.player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Lives display
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "Lives: " + str(player_data.current_lives)
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.add_theme_color_override("font_color", Color.WHITE)
	lives_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lives_label)
	
	# Health percentage display
	var health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = str(int(player_data.get_health_percentage())) + "%"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(health_label)
	
	# Health bar (visual progress bar)
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.max_value = 100.0
	health_bar.value = player_data.get_health_percentage()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(100, 8)
	
	# Style the progress bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.2, 0.2)
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", bar_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color.GREEN
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", fill_style)
	
	vbox.add_child(health_bar)
	
	# Status label (for ragdoll, etc.)
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "ALIVE" if player_data.is_alive else "DEAD"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_label)
	
	# Set minimum size
	panel.custom_minimum_size = Vector2(140, 100)
	
	return panel

static func create_menu_system(menu_config: MenuConfig) -> Control:
	if not menu_config:
		return null
	
	var menu_container: Control = VBoxContainer.new()
	menu_container.name = menu_config.menu_name
	
	# Create menu items
	for item_config in menu_config.menu_items:
		var menu_item: Node = create_ui_element(UIElementType.BUTTON, item_config)
		if menu_item and menu_item is Control:
			var menu_control: Control = menu_item as Control
			menu_container.add_child(menu_control)
			
			# Connect menu item signals if specified
			if item_config.action_method != "":
				if menu_control.has_signal("pressed"):
					# Connect to EventBus for global menu actions
					menu_control.pressed.connect(_handle_menu_action.bind(item_config.action_method, item_config.action_params))
	
	return menu_container

static func create_hud_for_players(player_data: Array[PlayerData]) -> Control:
	var hud_config: HUDConfig = _load_hud_config("default_hud")
	if not hud_config:
		Logger.error("Failed to load default HUD config")
		return null
	
	var hud: Control = hud_config.hud_scene.instantiate()
	if hud and hud.has_method("setup_for_players"):
		hud.setup_for_players(player_data)
	
	return hud

static func create_notification(message: String, notification_type: NotificationType = NotificationType.INFO) -> Control:
	var notification_config: NotificationConfig = _get_notification_config(notification_type)
	
	var notification: Panel = Panel.new()
	notification.name = "Notification"
	
	var label: Label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	notification.add_child(label)
	
	# Apply styling based on type
	if notification_config:
		_apply_notification_styling(notification, label, notification_config)
	
	return notification

# Private factory methods for specific UI elements
static func _create_button(config: UIElementConfig) -> Button:
	var button: Button = Button.new()
	
	if config:
		button.text = config.text
		button.name = config.element_name
		_set_element_size(button, config)
	
	return button

static func _create_label(config: UIElementConfig) -> Label:
	var label: Label = Label.new()
	
	if config:
		label.text = config.text
		label.name = config.element_name
		_set_element_size(label, config)
		
		if config.has_method("get_alignment"):
			label.horizontal_alignment = config.horizontal_alignment
			label.vertical_alignment = config.vertical_alignment
	
	return label

static func _create_panel(config: UIElementConfig) -> Panel:
	var panel: Panel = Panel.new()
	
	if config:
		panel.name = config.element_name
		_set_element_size(panel, config)
	
	return panel

static func _create_progress_bar(config: UIElementConfig) -> ProgressBar:
	var progress_bar: ProgressBar = ProgressBar.new()
	
	if config:
		progress_bar.name = config.element_name
		_set_element_size(progress_bar, config)
		
		if config.has_method("get_range"):
			progress_bar.min_value = config.min_value
			progress_bar.max_value = config.max_value
			progress_bar.value = config.initial_value
	
	return progress_bar

static func _create_menu(config: UIElementConfig) -> Control:
	var menu_container: VBoxContainer = VBoxContainer.new()
	
	if config:
		menu_container.name = config.element_name
		_set_element_size(menu_container, config)
	
	return menu_container

static func _create_dialog(config: UIElementConfig) -> AcceptDialog:
	var dialog: AcceptDialog = AcceptDialog.new()
	
	if config:
		dialog.title = config.text
		dialog.dialog_text = config.description
		# Note: AcceptDialog is a Window, not Control, so no size setting needed
	
	return dialog

static func _create_hud_element(config: UIElementConfig) -> Control:
	var hud_element: Control = Control.new()
	
	if config:
		hud_element.name = config.element_name
		_set_element_size(hud_element, config)
	
	return hud_element

# Helper methods
static func _handle_menu_action(action_method: String, action_params: Dictionary) -> void:
	EventBus.emit_signal("menu_action_triggered", action_method, action_params)

static func _apply_common_styling(element: Control, config: UIElementConfig) -> void:
	if not element or not config:
		return
	
	# Apply theme if specified
	if config.theme_path != "":
		var theme: Theme = load(config.theme_path) as Theme
		if theme:
			element.theme = theme
	
	# Apply position and anchoring
	if config.position != Vector2.ZERO:
		element.position = config.position
	
	if config.anchor_preset != -1:
		element.set_anchors_and_offsets_preset(config.anchor_preset)

static func _apply_screen_styling(screen: Control, config: ScreenConfig) -> void:
	if not screen or not config:
		return
	
	if config.background_color != Color.TRANSPARENT:
		var background: ColorRect = ColorRect.new()
		background.color = config.background_color
		screen.add_child(background)
		screen.move_child(background, 0)  # Move to background
	
	if config.theme_path != "":
		var theme: Theme = load(config.theme_path) as Theme
		if theme:
			screen.theme = theme

static func _apply_notification_styling(notification: Panel, label: Label, config: NotificationConfig) -> void:
	if config.background_color != Color.TRANSPARENT:
		notification.modulate = config.background_color
	
	if config.text_color != Color.TRANSPARENT:
		label.modulate = config.text_color
	
	if config.font_size > 0:
		var theme: Theme = Theme.new()
		var font: Font = ThemeDB.fallback_font
		theme.set_font_size("font_size", "Label", config.font_size)
		label.theme = theme

static func _set_element_size(element: Control, config: UIElementConfig) -> void:
	if config.size != Vector2.ZERO:
		element.custom_minimum_size = config.size
		element.size = config.size

static func _load_screen_config(screen_id: String) -> ScreenConfig:
	var config_path: String = "res://configs/ui_configs/screens/" + screen_id + ".tres"
	return load(config_path) as ScreenConfig

static func _load_hud_config(hud_id: String) -> HUDConfig:
	var config_path: String = "res://configs/ui_configs/hud/" + hud_id + ".tres"
	return load(config_path) as HUDConfig

static func _get_notification_config(notification_type: NotificationType) -> NotificationConfig:
	var config_path: String = ""
	match notification_type:
		NotificationType.INFO:
			config_path = "res://configs/ui_configs/notifications/info.tres"
		NotificationType.WARNING:
			config_path = "res://configs/ui_configs/notifications/warning.tres"
		NotificationType.ERROR:
			config_path = "res://configs/ui_configs/notifications/error.tres"
		NotificationType.SUCCESS:
			config_path = "res://configs/ui_configs/notifications/success.tres"
		_:
			return null
	
	# Check if specific config exists, fallback to info.tres
	if ResourceLoader.exists(config_path):
		return load(config_path) as NotificationConfig
	else:
		# Fallback to info config if specific type doesn't exist
		return load("res://configs/ui_configs/notifications/info.tres") as NotificationConfig 