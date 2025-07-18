class_name PlayerHUD
extends CanvasLayer

## Super Smash Bros style player HUD
## Shows all players' lives and health percentage at the bottom of the screen

# UI container for the HUD
@onready var hud_container: HBoxContainer = $HUDContainer

# Player colors (Smash Bros style)
var player_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3, 1.0),  # Player 1 - Red
	Color(0.3, 0.3, 1.0, 1.0),  # Player 2 - Blue  
	Color(0.3, 1.0, 0.3, 1.0),  # Player 3 - Green
	Color(1.0, 1.0, 0.3, 1.0)   # Player 4 - Yellow
]

# Player UI panels
var player_panels: Array[Control] = []

func _ready() -> void:
	# Wait one frame to ensure EventBus is fully initialized
	await get_tree().process_frame
	
	# Connect to EventBus for player updates
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_lives_changed.connect(_on_player_lives_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.player_ragdolled.connect(_on_player_ragdolled)
	EventBus.player_recovered.connect(_on_player_recovered)
	EventBus.player_respawn_timer_updated.connect(_on_player_respawn_timer_updated)
	
	# Create UI for all players
	_create_player_panels()
	
	# Debug UI visibility and positioning
	Logger.debug("PlayerHUD scene tree position: " + str(get_path()), "PlayerHUD")
	Logger.debug("PlayerHUD visible: " + str(visible), "PlayerHUD")
	Logger.debug("PlayerHUD layer: " + str(layer), "PlayerHUD")
	Logger.debug("PlayerHUD container: " + str(hud_container), "PlayerHUD")
	if hud_container:
		Logger.debug("HUDContainer children: " + str(hud_container.get_child_count()), "PlayerHUD")
		Logger.debug("HUDContainer visible: " + str(hud_container.visible), "PlayerHUD")
	
	Logger.system("PlayerHUD initialized with lives and health percentage display", "PlayerHUD")

## Create UI panels for all players
func _create_player_panels() -> void:
	# Clear existing panels
	for child in hud_container.get_children():
		child.queue_free()
	player_panels.clear()
	
	# Create panel for each player
	for player_id in range(4):
		var player_data = GameManager.get_player_data(player_id)
		if player_data:
			var panel = _create_player_panel(player_data, player_id)
			hud_container.add_child(panel)
			player_panels.append(panel)
	
	Logger.debug("Created " + str(player_panels.size()) + " player panels", "PlayerHUD")

## Create individual player panel with lives and health percentage
func _create_player_panel(player_data: PlayerData, player_id: int) -> Control:
	Logger.debug("Creating panel for " + player_data.player_name, "PlayerHUD")
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
	
	print("   ✅ Panel created with children: ", vbox.get_child_count())
	for i in range(vbox.get_child_count()):
		var child = vbox.get_child(i)
		print("     [", i, "] ", child.name, " (", child.get_class(), ")")
		if child is Label:
			print("         Text: '", child.text, "'")
	
	return panel

## Update player health display
func _update_player_health(player_id: int, new_health: int) -> void:
	if player_id >= player_panels.size():
		Logger.warning("Health update: Player ID " + str(player_id) + " out of range! Panel count: " + str(player_panels.size()), "PlayerHUD")
		return
	
	var panel = player_panels[player_id]
	var player_data = GameManager.get_player_data(player_id)
	if not player_data:
		Logger.warning("Health update: No player data for " + str(player_id), "PlayerHUD")
		return
	
	print("🔧 Updating health for Player ", player_id, ": ", player_data.current_health, "/", player_data.max_health, " = ", player_data.get_health_percentage(), "%")
	
	# Debug: Show panel structure
	print("   📋 Panel children: ", panel.get_child_count())
	for i in range(panel.get_child_count()):
		var child = panel.get_child(i)
		print("     [", i, "] ", child.name, " (", child.get_class(), ")")
		if child is VBoxContainer:
			print("       VBox children: ", child.get_child_count())
			for j in range(child.get_child_count()):
				var vchild = child.get_child(j)
				print("         [", j, "] ", vchild.name, " (", vchild.get_class(), ")")
	
	# Get the VBoxContainer first, then find children within it
	var vbox = panel.get_child(0) as VBoxContainer
	if not vbox:
		print("   ❌ VBoxContainer not found in panel!")
		return
	
	# Update health percentage label
	var health_label: Label = null
	var health_bar: ProgressBar = null
	
	# Find the specific children in the VBox
	for child in vbox.get_children():
		if child.name == "HealthLabel":
			health_label = child as Label
		elif child.name == "HealthBar":
			health_bar = child as ProgressBar
	
	if health_label:
		var health_percentage = player_data.get_health_percentage()
		health_label.text = str(int(health_percentage)) + "%"
		print("   ✅ Health label updated to: ", health_label.text)
		
		# Color code health percentage
		if health_percentage > 66:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif health_percentage > 33:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.RED)
	else:
		print("   ❌ HealthLabel not found in VBox!")
	
	# Update health bar
	if health_bar:
		health_bar.value = player_data.get_health_percentage()
		print("   ✅ Health bar updated to: ", health_bar.value, "%")
		
		# Update health bar color
		var fill_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style:
			if player_data.get_health_percentage() > 66:
				fill_style.bg_color = Color.GREEN
			elif player_data.get_health_percentage() > 33:
				fill_style.bg_color = Color.YELLOW
			else:
				fill_style.bg_color = Color.RED
	else:
		print("   ❌ HealthBar not found in VBox!")

## Update player lives display
func _update_player_lives(player_id: int, new_lives: int) -> void:
	if player_id >= player_panels.size():
		Logger.warning("Lives update: Player ID " + str(player_id) + " out of range! Panel count: " + str(player_panels.size()), "PlayerHUD")
		return
	
	var panel = player_panels[player_id]
	
	print("🔧 Updating lives for Player ", player_id, " to: ", new_lives)
	
	# Get the VBoxContainer first, then find LivesLabel within it
	var vbox = panel.get_child(0) as VBoxContainer
	if not vbox:
		print("   ❌ VBoxContainer not found in panel!")
		return
	
	var lives_label: Label = null
	for child in vbox.get_children():
		if child.name == "LivesLabel":
			lives_label = child as Label
			break
	
	if lives_label:
		lives_label.text = "Lives: " + str(new_lives)
		print("   ✅ Lives label updated to: ", lives_label.text)
		
		# Color code lives
		if new_lives > 1:
			lives_label.add_theme_color_override("font_color", Color.WHITE)
		elif new_lives == 1:
			lives_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			lives_label.add_theme_color_override("font_color", Color.RED)
	else:
		print("   ❌ LivesLabel not found in VBox!")

## Update player status display
func _update_player_status(player_id: int, status: String, color: Color = Color.WHITE) -> void:
	if player_id >= player_panels.size():
		return
	
	var panel = player_panels[player_id]
	
	# Get the VBoxContainer first, then find StatusLabel within it
	var vbox = panel.get_child(0) as VBoxContainer
	if not vbox:
		return
	
	var status_label: Label = null
	for child in vbox.get_children():
		if child.name == "StatusLabel":
			status_label = child as Label
			break
	
	if status_label:
		status_label.text = status
		status_label.add_theme_color_override("font_color", color)

## Make panel flash for dramatic effect
func _flash_panel(player_id: int, flash_color: Color) -> void:
	if player_id >= player_panels.size():
		return
	
	var panel = player_panels[player_id]
	var tween = create_tween()
	
	# Flash effect using tween_property (correct approach)
	tween.tween_property(panel, "modulate", flash_color, 0.1)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.1)

# Signal handlers
func _on_player_health_changed(player_id: int, new_health: int, max_health: int) -> void:
	_update_player_health(player_id, new_health)
	_flash_panel(player_id, Color.RED)  # Flash red on damage

func _on_player_lives_changed(player_id: int, new_lives: int) -> void:
	_update_player_lives(player_id, new_lives)
	_flash_panel(player_id, Color.ORANGE)  # Flash orange on life loss

func _on_player_died(player_id: int) -> void:
	_update_player_status(player_id, "DEAD", Color.RED)
	_flash_panel(player_id, Color.DARK_RED)

func _on_player_respawned(player_id: int) -> void:
	var player_data = GameManager.get_player_data(player_id)
	if player_data:
		_update_player_health(player_id, player_data.current_health)
		_update_player_status(player_id, "ALIVE", Color.WHITE)
		_flash_panel(player_id, Color.GREEN)

func _on_player_ragdolled(player_id: int) -> void:
	_update_player_status(player_id, "RAGDOLL", Color.ORANGE)

func _on_player_recovered(player_id: int) -> void:
	_update_player_status(player_id, "ALIVE", Color.WHITE) 

func _on_player_respawn_timer_updated(player_id: int, time_remaining: float) -> void:
	var countdown_text = "RESPAWN " + str(int(ceil(time_remaining)))
	_update_player_status(player_id, countdown_text, Color.YELLOW) 