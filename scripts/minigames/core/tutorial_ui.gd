class_name TutorialUI
extends Control

## Standard tutorial UI for displaying minigame instructions
## Mario Party-style tutorial screen with rules, controls, and countdown

# UI components
@onready var tutorial_panel: PanelContainer = $TutorialPanel
@onready var title_label: Label = $TutorialPanel/VBox/TitleLabel
@onready var objective_label: Label = $TutorialPanel/VBox/ObjectiveLabel
@onready var rules_container: VBoxContainer = $TutorialPanel/VBox/RulesContainer
@onready var controls_container: VBoxContainer = $TutorialPanel/VBox/ControlsContainer
@onready var tips_container: VBoxContainer = $TutorialPanel/VBox/TipsContainer
@onready var countdown_label: Label = $TutorialPanel/VBox/CountdownLabel
@onready var start_button: Button = $TutorialPanel/VBox/StartButton

# Tutorial state
var current_minigame: BaseMinigame = null
var countdown_time: float = 0.0
var manual_start: bool = false

# Signals
signal tutorial_start_requested()

func _ready() -> void:
	# Connect start button
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	
	# Initially hidden
	visible = false
	Logger.system("TutorialUI ready", "TutorialUI")

## Show tutorial for a specific minigame
func show_tutorial(minigame: BaseMinigame) -> void:
	current_minigame = minigame
	var tutorial_data: Dictionary = minigame.get_tutorial_data()
	
	# Set up UI elements
	_setup_tutorial_content(tutorial_data)
	
	# Handle timing
	countdown_time = tutorial_data.duration
	manual_start = countdown_time <= 0
	
	# Show the tutorial
	visible = true
	
	Logger.game_flow("Showing tutorial for: " + minigame.minigame_name, "TutorialUI")

## Setup tutorial content in UI
func _setup_tutorial_content(tutorial_data: Dictionary) -> void:
	# Title
	if title_label and current_minigame:
		title_label.text = current_minigame.minigame_name.to_upper()
	
	# Objective
	if objective_label:
		var objective: String = tutorial_data.get("objective", "")
		if objective.is_empty():
			objective_label.visible = false
		else:
			objective_label.text = "OBJECTIVE: " + objective
			objective_label.visible = true
	
	# Rules
	_setup_rules_section(tutorial_data.get("rules", []))
	
	# Controls
	_setup_controls_section(tutorial_data.get("controls", {}))
	
	# Tips
	_setup_tips_section(tutorial_data.get("tips", []))
	
	# Start button vs countdown
	if start_button and countdown_label:
		if manual_start:
			start_button.visible = true
			start_button.text = "START GAME"
			countdown_label.visible = false
		else:
			start_button.visible = false
			countdown_label.visible = true

## Setup rules section
func _setup_rules_section(rules: Array[String]) -> void:
	if not rules_container:
		return
	
	# Clear existing rules
	for child in rules_container.get_children():
		child.queue_free()
	
	if rules.is_empty():
		rules_container.visible = false
		return
	
	# Add header
	var header: Label = Label.new()
	header.text = "RULES:"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color.YELLOW)
	rules_container.add_child(header)
	
	# Add each rule
	for i in range(rules.size()):
		var rule_label: Label = Label.new()
		rule_label.text = "• " + rules[i]
		rule_label.add_theme_font_size_override("font_size", 14)
		rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rules_container.add_child(rule_label)
	
	rules_container.visible = true

## Setup controls section
func _setup_controls_section(controls: Dictionary) -> void:
	if not controls_container:
		return
	
	# Clear existing controls
	for child in controls_container.get_children():
		child.queue_free()
	
	if controls.is_empty():
		controls_container.visible = false
		return
	
	# Add header
	var header: Label = Label.new()
	header.text = "CONTROLS:"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color.CYAN)
	controls_container.add_child(header)
	
	# Add each control
	for action in controls.keys():
		var control_label: Label = Label.new()
		control_label.text = action + ": " + str(controls[action])
		control_label.add_theme_font_size_override("font_size", 14)
		controls_container.add_child(control_label)
	
	controls_container.visible = true

## Setup tips section
func _setup_tips_section(tips: Array[String]) -> void:
	if not tips_container:
		return
	
	# Clear existing tips
	for child in tips_container.get_children():
		child.queue_free()
	
	if tips.is_empty():
		tips_container.visible = false
		return
	
	# Add header
	var header: Label = Label.new()
	header.text = "TIPS:"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color.GREEN)
	tips_container.add_child(header)
	
	# Add each tip
	for tip in tips:
		var tip_label: Label = Label.new()
		tip_label.text = "💡 " + tip
		tip_label.add_theme_font_size_override("font_size", 12)
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tips_container.add_child(tip_label)
	
	tips_container.visible = true

## Process countdown timer
func _process(delta: float) -> void:
	if not visible or manual_start or countdown_time <= 0:
		return
	
	countdown_time -= delta
	
	# Update countdown display
	if countdown_label:
		if countdown_time > 1:
			countdown_label.text = "Starting in " + str(int(ceil(countdown_time))) + "..."
		else:
			countdown_label.text = "GET READY!"
	
	# Auto-start when countdown reaches zero
	if countdown_time <= 0:
		_start_minigame()

## Start button pressed
func _on_start_button_pressed() -> void:
	_start_minigame()

## Start the minigame
func _start_minigame() -> void:
	if current_minigame:
		Logger.game_flow("Tutorial finished, starting minigame", "TutorialUI")
		current_minigame.finish_tutorial()
	
	tutorial_start_requested.emit()
	hide_tutorial()

## Hide tutorial
func hide_tutorial() -> void:
	visible = false
	current_minigame = null
	countdown_time = 0.0

## Skip tutorial immediately
func skip_tutorial() -> void:
	if visible:
		_start_minigame() 