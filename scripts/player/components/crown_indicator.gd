class_name CrownIndicator
extends Node2D

## World-space crown indicator for players leading in victory conditions
## Floats above player characters to show who's currently winning

# Crown display components
@onready var crown_label: Label = $CrownLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Crown configuration (loaded from ConfigManager)
var crown_config: CrownConfig
var crown_text: String = "👑"
var crown_color: Color = Color.GOLD
var font_size: int = 24
var float_height: float = -50.0
var bob_enabled: bool = true
var bob_amplitude: float = 5.0
var bob_speed: float = 2.0

# State
var is_visible: bool = false
var base_offset: Vector2
var bob_timer: float = 0.0
var target_player: BasePlayer = null

func _ready() -> void:
	# Load crown configuration (standards compliance)
	_load_crown_config()
	
	# Create crown label if it doesn't exist
	if not crown_label:
		_create_crown_label()
	
	# Setup crown appearance
	_setup_crown_appearance()
	
	# Hide by default
	hide_crown()
	
	# Set base offset from config
	base_offset = Vector2(0, float_height)
	
	Logger.system("CrownIndicator initialized with config", "CrownIndicator")

func _process(delta: float) -> void:
	if not is_visible or not crown_label:
		return
	
	# Bob animation
	if bob_enabled:
		bob_timer += delta * bob_speed
		var bob_offset = Vector2(0, sin(bob_timer) * bob_amplitude)
		position = base_offset + bob_offset

## Create crown label programmatically
func _create_crown_label() -> void:
	# Use UIFactory for consistent UI creation (standards compliance)
	var label_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	label_config.element_name = "CrownLabel"
	label_config.text = crown_text
	label_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_config.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var crown_node: Node = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, label_config)
	if crown_node and crown_node is Label:
		crown_label = crown_node as Label
		add_child(crown_label)
		Logger.debug("Crown label created via UIFactory", "CrownIndicator")
	else:
		Logger.error("Failed to create crown label through UIFactory", "CrownIndicator")
		return
	
	# Create animation player for special effects
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

## Setup crown visual appearance
func _setup_crown_appearance() -> void:
	if not crown_label:
		return
	
	# Update text if it changed
	crown_label.text = crown_text
	
	# Set colors and styling (override UIFactory defaults)
	crown_label.add_theme_color_override("font_color", crown_color)
	crown_label.add_theme_font_size_override("font_size", font_size)
	
	# Add glow effect
	crown_label.add_theme_color_override("font_shadow_color", Color.YELLOW)
	crown_label.add_theme_constant_override("shadow_offset_x", 2)
	crown_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Add subtle outline
	crown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	crown_label.add_theme_constant_override("outline_size", 2)
	
	# Center the label relative to the Node2D position
	_center_crown_label()
	
	Logger.debug("Crown appearance configured: " + crown_text + " (" + str(crown_color) + ")", "CrownIndicator")

## Center the crown label relative to the Node2D position
func _center_crown_label() -> void:
	if not crown_label:
		return
	
	# Wait for the label to update its size
	await get_tree().process_frame
	
	# Use the actual size of the label control after it's been rendered
	var label_size = crown_label.size
	
	# If size is zero, try to calculate it from the text
	if label_size.x == 0 or label_size.y == 0:
		# Get the default font from the theme or system
		var font = crown_label.get_theme_font("font")
		if font:
			label_size = font.get_string_size(crown_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		else:
			# Fallback - estimate based on font size
			label_size = Vector2(font_size * crown_label.text.length() * 0.6, font_size)
	
	# Center the label relative to the Node2D position (0,0)
	crown_label.position = Vector2(-label_size.x / 2, -label_size.y / 2)
	
	Logger.debug("Crown label centered at position: " + str(crown_label.position) + " (size: " + str(label_size) + ")", "CrownIndicator")

## Show the crown with optional entrance animation
func show_crown(animate: bool = true) -> void:
	if is_visible:
		return
	
	is_visible = true
	visible = true
	
	if animate and animation_player:
		_play_entrance_animation()
	
	Logger.debug("Crown indicator shown", "CrownIndicator")

## Hide the crown with optional exit animation
func hide_crown(animate: bool = true) -> void:
	if not is_visible:
		return
	
	is_visible = false
	
	if animate and animation_player:
		_play_exit_animation()
	else:
		visible = false
	
	Logger.debug("Crown indicator hidden", "CrownIndicator")

## Attach crown to a specific player
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
	
	Logger.debug("Crown attached to player: " + player.player_data.player_name, "CrownIndicator")

## Detach crown from current player
func detach_from_player() -> void:
	if not target_player:
		return
	
	var previous_player = target_player
	target_player = null
	
	# Remove from player
	if get_parent() == previous_player:
		previous_player.remove_child(self)
	
	Logger.debug("Crown detached from player", "CrownIndicator")

## Update crown appearance (for different victory types)
func set_crown_style(victory_type: String) -> void:
	if crown_config:
		# Use configuration for victory type styling
		var style: Dictionary = crown_config.get_style_for_victory_type(victory_type)
		crown_text = style.get("text", crown_text)
		crown_color = style.get("color", crown_color)
	else:
		# Fallback to hardcoded values if config failed to load
		match victory_type:
			"ELIMINATION":
				crown_text = "👑"
				crown_color = Color.GOLD
			"SCORE_BASED":
				crown_text = "🏆"
				crown_color = Color.ORANGE
			"TIME_BASED":
				crown_text = "⏰"
				crown_color = Color.CYAN
			"CUSTOM":
				crown_text = "⭐"
				crown_color = Color.PURPLE
			_:
				crown_text = "👑"
				crown_color = Color.GOLD
	
	_setup_crown_appearance()
	Logger.debug("Crown style updated to: " + victory_type + " (" + crown_text + ")", "CrownIndicator")

## Play entrance animation
func _play_entrance_animation() -> void:
	if not animation_player:
		return
	
	# Create scale-in animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Start from small scale
	scale = Vector2(0.3, 0.3)
	
	# Animate to full scale
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

## Play exit animation  
func _play_exit_animation() -> void:
	if not animation_player:
		visible = false
		return
	
	# Create scale-out animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate to small scale
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.3)
	
	# Hide after animation
	tween.tween_callback(func(): visible = false)

## Pulse animation for special events
func pulse_crown() -> void:
	if not is_visible:
		return
	
	var tween = create_tween()
	tween.set_loops(3)
	
	# Pulse scale
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

## Cleanup on removal
func _exit_tree() -> void:
	# Proper cleanup following standards
	if target_player:
		target_player = null
	
	if crown_label and is_instance_valid(crown_label):
		crown_label = null
	
	if animation_player and is_instance_valid(animation_player):
		animation_player = null
	
	crown_config = null
	
	Logger.debug("CrownIndicator cleanup completed", "CrownIndicator")

## Load crown configuration from ConfigManager
func _load_crown_config() -> void:
	crown_config = ConfigManager.get_crown_config("default")
	if crown_config:
		# Apply configuration values
		crown_text = crown_config.crown_text
		crown_color = crown_config.crown_color
		font_size = crown_config.font_size
		float_height = crown_config.float_height
		bob_enabled = crown_config.bob_enabled
		bob_amplitude = crown_config.bob_amplitude
		bob_speed = crown_config.bob_speed
		Logger.debug("Crown config loaded successfully", "CrownIndicator")
	else:
		Logger.warning("Failed to load crown config - using defaults", "CrownIndicator") 