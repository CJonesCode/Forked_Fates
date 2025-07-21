# Forked Fates - Campaign Perk System Implementation

**Purpose**: Technical specification for implementing a map-wide minigame perk system that provides campaign-wide modifiers earned through minigame victories.

## System Overview

### **Core Features**
- **Post-Victory Selection**: Winner picks 1 from 3 random perks after each minigame
- **Campaign Persistence**: Perks remain active across all subsequent minigames
- **Physics & Gameplay Modifiers**: Low-gravity, bouncy objects, faster spawns, time effects, ragdoll chaos
- **Stacking & Conflict Rules**: Some perks stack (bouncy increases bounces), others conflict
- **Rarity System**: Common, Uncommon, Rare, Legendary perks with weighted selection
- **Removal Support**: Stubbed method for future perk removal mechanics

### **Integration Points**
- Integrates with existing victory system (`VictoryConditionManager`, `MinigameResult`)
- Uses UIFactory + UIManager patterns for perk selection UI
- Applies effects to `PhysicsMinigame` systems (gravity, physics materials, spawners)
- Persists in `SessionData` for campaign continuity

## Architecture Components

### **1. PerkConfig Resource Class**
```gdscript
# configs/perk_configs/perk_config.gd
class_name PerkConfig
extends Resource

## Configuration resource for individual perks
## Defines perk properties, effects, and stacking rules

@export var perk_id: String = ""
@export var perk_name: String = ""
@export var perk_description: String = ""
@export var perk_icon: Texture2D = null

# Effect categories
@export_group("Physics Effects")
@export var gravity_multiplier: float = 1.0
@export var bounce_multiplier: float = 1.0
@export var physics_material_override: PhysicsMaterial = null

@export_group("Gameplay Effects") 
@export var item_spawn_rate_multiplier: float = 1.0
@export var time_scale_multiplier: float = 1.0
@export var ragdoll_force_multiplier: float = 1.0

@export_group("Minigame Overrides")
@export var override_minigame_settings: Dictionary = {}  # setting_name -> value
@export var add_minigame_tags: Array[String] = []  # Additional tags for minigame selection

@export_group("Stacking Rules")
@export var can_stack: bool = false
@export var max_stack_count: int = 1
@export var stack_effect: StackEffect = StackEffect.ADDITIVE
@export var conflicts_with: Array[String] = []  # Perk IDs that can't coexist

@export_group("Meta")
@export var rarity: Rarity = Rarity.COMMON
@export var unlock_requirements: Array[String] = []  # Achievement/condition IDs

enum StackEffect {
	ADDITIVE,      # Effects add together
	MULTIPLICATIVE,  # Effects multiply
	MAX_VALUE,     # Take highest value
	REPLACE        # New value replaces old
}

enum Rarity {
	COMMON,
	UNCOMMON, 
	RARE,
	LEGENDARY
}

func _init() -> void:
	resource_name = "PerkConfig"

## Get effective multiplier when stacked
func get_effective_multiplier(base_value: float, stack_count: int) -> float:
	if stack_count <= 1:
		return base_value
	
	match stack_effect:
		StackEffect.ADDITIVE:
			return 1.0 + (base_value - 1.0) * stack_count
		StackEffect.MULTIPLICATIVE:
			return pow(base_value, stack_count)
		StackEffect.MAX_VALUE:
			return base_value
		StackEffect.REPLACE:
			return base_value
		_:
			return base_value

## Check if this perk conflicts with another
func conflicts_with_perk(other_perk_id: String) -> bool:
	return other_perk_id in conflicts_with
```

### **2. PerkManager Autoload**
```gdscript
# autoloads/perk_manager.gd
extends Node

## Campaign-wide perk management system
## Manages active perks and applies effects to minigames and physics

# Active perks in current campaign
var active_perks: Dictionary = {}  # perk_id -> stack_count
var perk_configs: Dictionary = {}  # perk_id -> PerkConfig (cached)

# Perk pools for random selection
var common_perks: Array[String] = []
var uncommon_perks: Array[String] = []
var rare_perks: Array[String] = []
var legendary_perks: Array[String] = []

# Current effect cache (calculated from active perks)
var current_effects: Dictionary = {}

# Signals
signal perk_added(perk_id: String, stack_count: int)
signal perk_removed(perk_id: String)
signal perk_effects_updated(effects: Dictionary)
signal perk_selection_requested(available_perks: Array[String])

func _ready() -> void:
	# Load perk configurations
	_load_all_perk_configs()
	
	# Connect to victory events for perk selection
	EventBus.minigame_ended.connect(_on_minigame_ended)
	
	Logger.system("PerkManager initialized with " + str(perk_configs.size()) + " perks", "PerkManager")

## Load all perk configurations from disk
func _load_all_perk_configs() -> void:
	var perk_dir: String = "res://configs/perk_configs/"
	var dir = DirAccess.open(perk_dir)
	
	if not dir:
		Logger.error("Failed to open perk configs directory", "PerkManager")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") and not file_name.begins_with("perk_config"):
			var perk_id = file_name.get_basename()
			var config: PerkConfig = load(perk_dir + file_name)
			
			if config:
				perk_configs[perk_id] = config
				_categorize_perk_by_rarity(perk_id, config.rarity)
				Logger.debug("Loaded perk config: " + perk_id, "PerkManager")
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	Logger.system("Loaded " + str(perk_configs.size()) + " perk configurations", "PerkManager")

## Categorize perk by rarity for random selection
func _categorize_perk_by_rarity(perk_id: String, rarity: PerkConfig.Rarity) -> void:
	match rarity:
		PerkConfig.Rarity.COMMON:
			common_perks.append(perk_id)
		PerkConfig.Rarity.UNCOMMON:
			uncommon_perks.append(perk_id)
		PerkConfig.Rarity.RARE:
			rare_perks.append(perk_id)
		PerkConfig.Rarity.LEGENDARY:
			legendary_perks.append(perk_id)

## Get 3 random perks for selection (weighted by rarity)
func get_random_perk_selection() -> Array[String]:
	var available_perks: Array[String] = []
	
	# Weight: 60% common, 25% uncommon, 12% rare, 3% legendary
	for i in 3:
		var roll = randf() * 100.0
		var selected_perk: String = ""
		
		if roll < 3.0 and not legendary_perks.is_empty():
			selected_perk = legendary_perks[randi() % legendary_perks.size()]
		elif roll < 15.0 and not rare_perks.is_empty():
			selected_perk = rare_perks[randi() % rare_perks.size()]
		elif roll < 40.0 and not uncommon_perks.is_empty():
			selected_perk = uncommon_perks[randi() % uncommon_perks.size()]
		elif not common_perks.is_empty():
			selected_perk = common_perks[randi() % common_perks.size()]
		
		# Avoid duplicates and conflicts
		if selected_perk != "" and selected_perk not in available_perks and _can_add_perk(selected_perk):
			available_perks.append(selected_perk)
	
	# Fill remaining slots with valid perks if needed
	while available_perks.size() < 3:
		var all_perks = common_perks + uncommon_perks + rare_perks + legendary_perks
		var random_perk = all_perks[randi() % all_perks.size()]
		
		if random_perk not in available_perks and _can_add_perk(random_perk):
			available_perks.append(random_perk)
		
		if all_perks.is_empty():
			break  # Safety check
	
	return available_perks

## Check if a perk can be added (conflicts, stacking rules)
func _can_add_perk(perk_id: String) -> bool:
	var config: PerkConfig = perk_configs.get(perk_id)
	if not config:
		return false
	
	# Check if already at max stack
	var current_stack = active_perks.get(perk_id, 0)
	if current_stack >= config.max_stack_count:
		return false
	
	# Check conflicts
	for active_perk_id in active_perks.keys():
		if config.conflicts_with_perk(active_perk_id):
			return false
		
		var active_config = perk_configs.get(active_perk_id)
		if active_config and active_config.conflicts_with_perk(perk_id):
			return false
	
	return true

## Add a perk to the active list
func add_perk(perk_id: String) -> bool:
	if not _can_add_perk(perk_id):
		Logger.warning("Cannot add perk: " + perk_id, "PerkManager")
		return false
	
	var current_stack = active_perks.get(perk_id, 0)
	active_perks[perk_id] = current_stack + 1
	
	_recalculate_effects()
	
	Logger.system("Added perk: " + perk_id + " (stack: " + str(active_perks[perk_id]) + ")", "PerkManager")
	perk_added.emit(perk_id, active_perks[perk_id])
	
	return true

## Remove a perk (stubbed for future implementation)
func remove_perk(perk_id: String) -> bool:
	if perk_id not in active_perks:
		return false
	
	var stack_count = active_perks[perk_id]
	stack_count -= 1
	
	if stack_count <= 0:
		active_perks.erase(perk_id)
		Logger.system("Removed perk: " + perk_id, "PerkManager")
		perk_removed.emit(perk_id)
	else:
		active_perks[perk_id] = stack_count
		Logger.system("Reduced perk stack: " + perk_id + " (stack: " + str(stack_count) + ")", "PerkManager")
		perk_added.emit(perk_id, stack_count)  # Update UI
	
	_recalculate_effects()
	return true

## Clear all perks (for new campaigns)
func clear_all_perks() -> void:
	active_perks.clear()
	_recalculate_effects()
	Logger.system("Cleared all perks", "PerkManager")

## Recalculate effective modifiers from all active perks
func _recalculate_effects() -> void:
	current_effects.clear()
	
	# Default values
	current_effects = {
		"gravity_multiplier": 1.0,
		"bounce_multiplier": 1.0,
		"item_spawn_rate_multiplier": 1.0,
		"time_scale_multiplier": 1.0,
		"ragdoll_force_multiplier": 1.0,
		"minigame_overrides": {},
		"additional_tags": []
	}
	
	# Apply each active perk
	for perk_id in active_perks.keys():
		var config: PerkConfig = perk_configs.get(perk_id)
		var stack_count: int = active_perks[perk_id]
		
		if not config:
			continue
		
		# Apply physics effects
		current_effects.gravity_multiplier *= config.get_effective_multiplier(config.gravity_multiplier, stack_count)
		current_effects.bounce_multiplier *= config.get_effective_multiplier(config.bounce_multiplier, stack_count)
		current_effects.ragdoll_force_multiplier *= config.get_effective_multiplier(config.ragdoll_force_multiplier, stack_count)
		
		# Apply gameplay effects
		current_effects.item_spawn_rate_multiplier *= config.get_effective_multiplier(config.item_spawn_rate_multiplier, stack_count)
		current_effects.time_scale_multiplier *= config.get_effective_multiplier(config.time_scale_multiplier, stack_count)
		
		# Merge minigame overrides
		for setting_name in config.override_minigame_settings.keys():
			current_effects.minigame_overrides[setting_name] = config.override_minigame_settings[setting_name]
		
		# Add tags
		for tag in config.add_minigame_tags:
			if tag not in current_effects.additional_tags:
				current_effects.additional_tags.append(tag)
	
	perk_effects_updated.emit(current_effects)
	Logger.debug("Recalculated perk effects: " + str(current_effects), "PerkManager")

## Get current effect value
func get_effect(effect_name: String, default_value = null):
	return current_effects.get(effect_name, default_value)

## Get active perks list for UI display
func get_active_perks() -> Array[Dictionary]:
	var perks_data: Array[Dictionary] = []
	
	for perk_id in active_perks.keys():
		var config: PerkConfig = perk_configs.get(perk_id)
		if config:
			perks_data.append({
				"id": perk_id,
				"name": config.perk_name,
				"description": config.perk_description,
				"icon": config.perk_icon,
				"stack_count": active_perks[perk_id]
			})
	
	return perks_data

## Handle minigame victory for perk selection
func _on_minigame_ended(winner_id: int, results: Dictionary) -> void:
	# Only trigger perk selection for actual victories (not timeouts, draws, etc.)
	if winner_id == -1:
		return
	
	Logger.game_flow("Minigame victory detected, triggering perk selection", "PerkManager")
	
	# Get available perks and request selection
	var available_perks = get_random_perk_selection()
	if not available_perks.is_empty():
		perk_selection_requested.emit(available_perks)
	else:
		Logger.warning("No perks available for selection", "PerkManager")

## Get perk config for UI display
func get_perk_config(perk_id: String) -> PerkConfig:
	return perk_configs.get(perk_id)

## Apply perks to minigame configuration (called by minigames)
func apply_perks_to_minigame(minigame: BaseMinigame) -> void:
	if active_perks.is_empty():
		return
	
	Logger.system("Applying " + str(active_perks.size()) + " active perks to " + minigame.minigame_name, "PerkManager")
	
	# Apply physics modifications
	_apply_physics_effects(minigame)
	
	# Apply gameplay modifications  
	_apply_gameplay_effects(minigame)
	
	# Apply minigame-specific overrides
	_apply_minigame_overrides(minigame)

## Apply physics effects to minigame
func _apply_physics_effects(minigame: BaseMinigame) -> void:
	var gravity_mult = get_effect("gravity_multiplier", 1.0)
	var bounce_mult = get_effect("bounce_multiplier", 1.0)
	var ragdoll_mult = get_effect("ragdoll_force_multiplier", 1.0)
	
	# Modify physics settings if they exist
	if minigame.has_method("set_gravity_multiplier"):
		minigame.set_gravity_multiplier(gravity_mult)
	
	if minigame.has_method("set_bounce_multiplier"):
		minigame.set_bounce_multiplier(bounce_mult)
	
	if minigame.has_method("set_ragdoll_force_multiplier"):
		minigame.set_ragdoll_force_multiplier(ragdoll_mult)

## Apply gameplay effects to minigame
func _apply_gameplay_effects(minigame: BaseMinigame) -> void:
	var spawn_rate_mult = get_effect("item_spawn_rate_multiplier", 1.0)
	var time_mult = get_effect("time_scale_multiplier", 1.0)
	
	# Modify gameplay settings if they exist
	if minigame.has_method("set_item_spawn_rate_multiplier"):
		minigame.set_item_spawn_rate_multiplier(spawn_rate_mult)
	
	# Apply time scale to physics minigames
	if time_mult != 1.0 and minigame is PhysicsMinigame:
		var physics_minigame = minigame as PhysicsMinigame
		if physics_minigame.has_method("set_time_scale"):
			physics_minigame.set_time_scale(time_mult)

## Apply minigame-specific overrides
func _apply_minigame_overrides(minigame: BaseMinigame) -> void:
	var overrides = get_effect("minigame_overrides", {})
	
	for setting_name in overrides.keys():
		var value = overrides[setting_name]
		
		if minigame.has_method("set_" + setting_name):
			minigame.call("set_" + setting_name, value)
		elif minigame.has_property(setting_name):
			minigame.set(setting_name, value)
```

### **3. Perk Selection UI**
```gdscript
# scripts/ui/components/perk_selector.gd
class_name PerkSelector
extends Control

## Post-victory perk selection UI
## Mario Party style perk selection with 3 choices

# UI References
@onready var background_panel: PanelContainer = $BackgroundPanel
@onready var title_label: Label = $BackgroundPanel/VBox/TitleLabel
@onready var perk_container: HBoxContainer = $BackgroundPanel/VBox/PerkContainer
@onready var continue_button: Button = $BackgroundPanel/VBox/ContinueButton

# State
var available_perks: Array[String] = []
var selected_perk: String = ""

# Signals
signal perk_selected(perk_id: String)
signal selection_completed()

func _ready() -> void:
	# Connect signals
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Initially hidden
	visible = false
	
	Logger.system("PerkSelector ready", "PerkSelector")

## Show perk selection with available options
func show_perk_selection(perk_ids: Array[String]) -> void:
	available_perks = perk_ids.duplicate()
	selected_perk = ""
	
	# Setup UI
	_setup_perk_selection_ui()
	
	# Show the selector
	visible = true
	z_index = 2000  # Above other UI
	
	Logger.game_flow("Showing perk selection with " + str(perk_ids.size()) + " options", "PerkSelector")

## Setup the perk selection UI
func _setup_perk_selection_ui() -> void:
	# Set title
	var title_config = UIFactory.UIElementConfig.new()
	title_config.element_name = "PerkSelectionTitle"
	title_config.text = "Choose Your Perk!"
	title_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var title = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, title_config)
	if title and title is Label:
		var label = title as Label
		title_label.text = label.text
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.add_theme_color_override("font_color", Color.GOLD)
	
	# Clear existing perk options
	for child in perk_container.get_children():
		child.queue_free()
	
	# Create perk option buttons
	for i in available_perks.size():
		var perk_id = available_perks[i]
		var perk_button = _create_perk_button(perk_id, i)
		perk_container.add_child(perk_button)
	
	# Setup continue button
	continue_button.text = "Continue"
	continue_button.disabled = true

## Create a perk selection button
func _create_perk_button(perk_id: String, index: int) -> Control:
	var perk_config: PerkConfig = PerkManager.get_perk_config(perk_id)
	if not perk_config:
		Logger.error("Failed to get perk config for: " + perk_id, "PerkSelector")
		return Control.new()
	
	# Create button container using UIFactory
	var panel_config = UIFactory.UIElementConfig.new()
	panel_config.element_name = "PerkOption" + str(index)
	
	var button_panel = UIFactory.create_ui_element(UIFactory.UIElementType.PANEL, panel_config)
	if not button_panel or not button_panel is Control:
		Logger.error("Failed to create perk button panel", "PerkSelector")
		return Control.new()
	
	var panel = button_panel as Control
	panel.custom_minimum_size = Vector2(200, 250)
	
	# Create button
	var button_config = UIFactory.UIElementConfig.new()
	button_config.element_name = "PerkButton" + str(index)
	button_config.text = ""
	
	var button = UIFactory.create_ui_element(UIFactory.UIElementType.BUTTON, button_config)
	if not button or not button is Button:
		Logger.error("Failed to create perk button", "PerkSelector")
		return panel
	
	var perk_button = button as Button
	
	# Create content container
	var vbox = VBoxContainer.new()
	vbox.name = "PerkContent"
	
	# Add perk icon
	if perk_config.perk_icon:
		var icon_rect = TextureRect.new()
		icon_rect.texture = perk_config.perk_icon
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(icon_rect)
	
	# Add perk name
	var name_config = UIFactory.UIElementConfig.new()
	name_config.element_name = "PerkName" + str(index)
	name_config.text = perk_config.perk_name
	name_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var name_label = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, name_config)
	if name_label and name_label is Label:
		var label = name_label as Label
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label)
	
	# Add perk description
	var desc_config = UIFactory.UIElementConfig.new()
	desc_config.element_name = "PerkDesc" + str(index)
	desc_config.text = perk_config.perk_description
	desc_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var desc_label = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, desc_config)
	if desc_label and desc_label is Label:
		var label = desc_label as Label
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(label)
	
	# Add rarity indicator
	var rarity_color = _get_rarity_color(perk_config.rarity)
	var rarity_config = UIFactory.UIElementConfig.new()
	rarity_config.element_name = "PerkRarity" + str(index)
	rarity_config.text = PerkConfig.Rarity.keys()[perk_config.rarity]
	rarity_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var rarity_label = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, rarity_config)
	if rarity_label and rarity_label is Label:
		var label = rarity_label as Label
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", rarity_color)
		vbox.add_child(label)
	
	# Setup button
	perk_button.add_child(vbox)
	perk_button.pressed.connect(_on_perk_selected.bind(perk_id))
	
	# Add to panel
	panel.add_child(perk_button)
	
	return panel

## Get color for rarity display
func _get_rarity_color(rarity: PerkConfig.Rarity) -> Color:
	match rarity:
		PerkConfig.Rarity.COMMON:
			return Color.WHITE
		PerkConfig.Rarity.UNCOMMON:
			return Color.CYAN
		PerkConfig.Rarity.RARE:
			return Color.PURPLE
		PerkConfig.Rarity.LEGENDARY:
			return Color.GOLD
		_:
			return Color.WHITE

## Handle perk selection
func _on_perk_selected(perk_id: String) -> void:
	selected_perk = perk_id
	
	# Update button states to show selection
	for i in perk_container.get_child_count():
		var panel = perk_container.get_child(i)
		var button = panel.get_child(0) if panel.get_child_count() > 0 else null
		
		if button and button is Button:
			if available_perks[i] == selected_perk:
				button.modulate = Color.GOLD  # Highlight selected
			else:
				button.modulate = Color.GRAY  # Dim unselected
	
	# Enable continue button
	continue_button.disabled = false
	
	Logger.system("Perk selected: " + perk_id, "PerkSelector")
	perk_selected.emit(perk_id)

## Handle continue button
func _on_continue_pressed() -> void:
	if selected_perk == "":
		Logger.warning("No perk selected", "PerkSelector")
		return
	
	# Add the selected perk
	var success = PerkManager.add_perk(selected_perk)
	if success:
		Logger.game_flow("Perk added to campaign: " + selected_perk, "PerkSelector")
	else:
		Logger.error("Failed to add perk: " + selected_perk, "PerkSelector")
	
	# Hide the selector
	visible = false
	
	# Emit completion signal
	selection_completed.emit()
```

### **4. BaseMinigame Integration**
```gdscript
# Modify scripts/minigames/core/base_minigame.gd

# Add to BaseMinigame class:
var perk_selector: PerkSelector = null

func end_minigame(result) -> void:
	if not is_active:
		Logger.warning("Trying to end inactive minigame: " + minigame_name, "BaseMinigame")
		return
	
	is_active = false
	
	# Hide any active game HUD when minigame ends
	UIManager.hide_game_hud()
	
	# Clear current leader reference
	current_leader = null
	
	# Disconnect universal systems
	if EventBus.player_damage_reported.is_connected(_on_player_damage_reported):
		EventBus.player_damage_reported.disconnect(_on_player_damage_reported)
	
	# Set duration and type if not already set
	if result.duration == 0.0:
		result.duration = Time.get_unix_time_from_system() - start_time
	if result.minigame_type == "":
		result.minigame_type = minigame_name
	
	Logger.game_flow("Ending minigame: " + minigame_name + " after " + str(result.duration) + "s", "BaseMinigame")
	
	# Check if we should show perk selection (only for victories)
	if _should_show_perk_selection(result):
		_show_perk_selection_then_end(result)
	else:
		_finalize_minigame_end(result)

## Check if perk selection should be shown
func _should_show_perk_selection(result: MinigameResult) -> bool:
	# Only show for victories, not draws/timeouts
	if result.outcome != MinigameResult.MinigameOutcome.VICTORY:
		return false
	
	# Only show if there are winners
	if result.winners.is_empty():
		return false
	
	return true

## Show perk selection UI then end minigame
func _show_perk_selection_then_end(result: MinigameResult) -> void:
	# Create perk selector using UIFactory pattern
	perk_selector = PerkSelector.new()
	perk_selector.name = "PerkSelector"
	
	# Connect to completion signal
	perk_selector.selection_completed.connect(_on_perk_selection_completed.bind(result))
	
	# Show via UIManager overlay system
	UIManager.show_overlay(perk_selector, "perk_selection")
	
	# Connect to PerkManager for available perks
	if not PerkManager.perk_selection_requested.is_connected(_on_perk_selection_requested):
		PerkManager.perk_selection_requested.connect(_on_perk_selection_requested)
	
	Logger.system("Requesting perk selection for victory", "BaseMinigame")

## Handle perk selection request from PerkManager
func _on_perk_selection_requested(available_perks: Array[String]) -> void:
	if perk_selector:
		perk_selector.show_perk_selection(available_perks)

## Handle perk selection completion
func _on_perk_selection_completed(result: MinigameResult) -> void:
	# Clean up perk selector
	UIManager.hide_overlay("perk_selection")
	
	if PerkManager.perk_selection_requested.is_connected(_on_perk_selection_requested):
		PerkManager.perk_selection_requested.disconnect(_on_perk_selection_requested)
	
	perk_selector = null
	
	# Now actually end the minigame
	_finalize_minigame_end(result)

## Finalize minigame ending (called after perk selection or directly)
func _finalize_minigame_end(result: MinigameResult) -> void:
	minigame_ended.emit(result)
	_on_end(result)
```

### **5. PhysicsMinigame Perk Effects**
```gdscript
# Modify scripts/minigames/core/physics_minigame.gd

# Add to PhysicsMinigame class:
var gravity_multiplier: float = 1.0
var bounce_multiplier: float = 1.0
var ragdoll_force_multiplier: float = 1.0
var item_spawn_rate_multiplier: float = 1.0
var time_scale: float = 1.0

func _on_physics_initialize() -> void:
	# Apply perks before other initialization
	PerkManager.apply_perks_to_minigame(self)
	
	# Continue with normal initialization
	pass

## Perk effect setters
func set_gravity_multiplier(multiplier: float) -> void:
	gravity_multiplier = multiplier
	# Apply to physics space
	var physics_space = get_world_2d().direct_space_state.get_space()
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * multiplier
	PhysicsServer2D.space_set_param(physics_space, PhysicsServer2D.SPACE_PARAM_GRAVITY, gravity)
	Logger.system("Applied gravity multiplier: " + str(multiplier), "PhysicsMinigame")

func set_bounce_multiplier(multiplier: float) -> void:
	bounce_multiplier = multiplier
	# This would require updating all RigidBody2D objects with new physics materials
	_update_physics_materials_for_bounce(multiplier)
	Logger.system("Applied bounce multiplier: " + str(multiplier), "PhysicsMinigame")

func set_ragdoll_force_multiplier(multiplier: float) -> void:
	ragdoll_force_multiplier = multiplier
	# Update all player ragdoll components
	if player_spawner:
		for player in player_spawner.get_spawned_players():
			if player.has_method("set_ragdoll_force_multiplier"):
				player.set_ragdoll_force_multiplier(multiplier)
	Logger.system("Applied ragdoll force multiplier: " + str(multiplier), "PhysicsMinigame")

func set_item_spawn_rate_multiplier(multiplier: float) -> void:
	item_spawn_rate_multiplier = multiplier
	# Update item spawner
	if item_spawner and item_spawner.has_method("set_spawn_rate_multiplier"):
		item_spawner.set_spawn_rate_multiplier(multiplier)
	Logger.system("Applied item spawn rate multiplier: " + str(multiplier), "PhysicsMinigame")

func set_time_scale(scale: float) -> void:
	time_scale = scale
	# Apply time scale to engine (affects physics and animations)
	Engine.time_scale = scale
	Logger.system("Applied time scale: " + str(scale), "PhysicsMinigame")

## Update physics materials for bounce effects
func _update_physics_materials_for_bounce(multiplier: float) -> void:
	# This would iterate through all RigidBody2D objects and update their bounce
	var space_state = get_world_2d().direct_space_state
	# Implementation would depend on how objects are tracked
	# Could use a group or iterate through spawned objects
```

## Configuration Examples

### **Perk Config Files (.tres)**
```gdscript
# configs/perk_configs/low_gravity.tres
[gd_resource type="Resource" script_class="PerkConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://configs/perk_configs/perk_config.gd" id="perk_config_script"]

[resource]
script = ExtResource("perk_config_script")
perk_id = "low_gravity"
perk_name = "Low Gravity"
perk_description = "Reduced gravity makes everyone float more!"
gravity_multiplier = 0.5
can_stack = true
max_stack_count = 3
stack_effect = 1  # MULTIPLICATIVE
rarity = 0  # COMMON

# configs/perk_configs/bouncy_world.tres
[gd_resource type="Resource" script_class="PerkConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://configs/perk_configs/perk_config.gd" id="perk_config_script"]

[resource]
script = ExtResource("perk_config_script")
perk_id = "bouncy_world"
perk_name = "Bouncy World"
perk_description = "Everything bounces like rubber!"
bounce_multiplier = 2.0
can_stack = true
max_stack_count = 5
stack_effect = 0  # ADDITIVE
rarity = 1  # UNCOMMON

# configs/perk_configs/chaos_physics.tres
[gd_resource type="Resource" script_class="PerkConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://configs/perk_configs/perk_config.gd" id="perk_config_script"]

[resource]
script = ExtResource("perk_config_script")
perk_id = "chaos_physics"
perk_name = "Chaos Physics"
perk_description = "Ragdoll forces are completely insane!"
ragdoll_force_multiplier = 3.0
can_stack = false
max_stack_count = 1
conflicts_with = ["gentle_ragdolls"]
rarity = 2  # RARE

# configs/perk_configs/time_warp.tres
[gd_resource type="Resource" script_class="PerkConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://configs/perk_configs/perk_config.gd" id="perk_config_script"]

[resource]
script = ExtResource("perk_config_script")
perk_id = "time_warp"
perk_name = "Time Warp"
perk_description = "Everything moves in slow motion!"
time_scale_multiplier = 0.7
can_stack = false
max_stack_count = 1
conflicts_with = ["speed_boost"]
rarity = 3  # LEGENDARY

# configs/perk_configs/weapon_frenzy.tres
[gd_resource type="Resource" script_class="PerkConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://configs/perk_configs/perk_config.gd" id="perk_config_script"]

[resource]
script = ExtResource("perk_config_script")
perk_id = "weapon_frenzy"
perk_name = "Weapon Frenzy"
perk_description = "Weapons spawn twice as fast!"
item_spawn_rate_multiplier = 2.0
can_stack = true
max_stack_count = 3
stack_effect = 0  # ADDITIVE
rarity = 1  # UNCOMMON
```

## Data Persistence

### **SessionData Integration**
```gdscript
# Modify scripts/core/data_structures/session_data.gd

# Add to SessionData class:
@export var active_campaign_perks: Dictionary = {}  # perk_id -> stack_count

func reset_for_new_session() -> void:
	# ... existing reset logic ...
	active_campaign_perks.clear()  # Clear perks for new campaigns

func get_active_perks() -> Dictionary:
	return active_campaign_perks.duplicate()

func set_active_perks(perks: Dictionary) -> void:
	active_campaign_perks = perks.duplicate()

# Save/load integration
func save_to_dict() -> Dictionary:
	var data = super.save_to_dict()
	data["active_campaign_perks"] = active_campaign_perks
	return data

func load_from_dict(data: Dictionary) -> void:
	super.load_from_dict(data)
	active_campaign_perks = data.get("active_campaign_perks", {})
```

### **PerkManager Session Sync**
```gdscript
# Add to PerkManager._ready():
func _ready() -> void:
	# ... existing initialization ...
	
	# Load perks from session data
	var session_data = GameManager.get_session_data()
	if session_data:
		active_perks = session_data.get_active_perks()
		_recalculate_effects()
	
	# Connect to save perks when they change
	perk_added.connect(_save_perks_to_session)
	perk_removed.connect(_save_perks_to_session)

func _save_perks_to_session() -> void:
	var session_data = GameManager.get_session_data()
	if session_data:
		session_data.set_active_perks(active_perks)
```

## Project Configuration

### **Autoload Registration**
```gdscript
# Add to project.godot autoloads section:
[autoload]
# ... existing autoloads ...
PerkManager="*res://autoloads/perk_manager.gd"
```

## Implementation Notes

### **Integration Points**
1. **Victory System**: PerkManager connects to `EventBus.minigame_ended` for automatic perk selection triggering
2. **UI System**: Uses UIFactory + UIManager patterns for consistent perk selection interface
3. **Physics System**: Integrates with PhysicsMinigame to apply real-time effects to gravity, bounce, ragdolls
4. **Data Persistence**: Syncs with SessionData for campaign continuity across map progression

### **Effect Application Flow**
1. **Perk Selection**: Winner chooses from 3 weighted-random perks after victory
2. **Effect Calculation**: PerkManager recalculates all active effects considering stacking rules
3. **Minigame Application**: Next minigame calls `PerkManager.apply_perks_to_minigame()` during initialization
4. **Runtime Modification**: Physics parameters, spawn rates, and game behavior modified in real-time

### **Extensibility**
- **New Perk Types**: Add new effect categories to PerkConfig and corresponding application logic
- **Custom Stacking**: Implement new StackEffect types for complex perk interactions
- **Minigame-Specific Effects**: Use `override_minigame_settings` for per-minigame customization
- **Removal Mechanics**: Expand `remove_perk()` implementation for future gameplay features

### **Performance Considerations**
- **Lazy Loading**: Perk configs loaded only once at startup
- **Effect Caching**: Current effects calculated once when perks change, not per-frame
- **Physics Updates**: Physics modifications applied once during minigame initialization
- **UI Efficiency**: Perk selection UI created on-demand, destroyed after use

## Future Extensions

### **Potential Features**
- **Perk Conflicts UI**: Visual indicators showing which perks can't coexist
- **Perk Preview**: Tooltip showing exact effect numbers before selection
- **Perk History**: Track which perks were selected and when
- **Perk Achievements**: Unlock new perks based on gameplay achievements
- **Perk Combinations**: Special effects when certain perks are active together
- **Temporary Perks**: Time-limited effects that expire after certain conditions
- **Perk Trading**: Allow players to exchange or steal perks
- **Perk Removal Items**: Special map events or items that remove perks

### **Advanced Stacking**
- **Diminishing Returns**: Stack effects that become less powerful with each stack
- **Exponential Growth**: Stack effects that become exponentially more powerful
- **Threshold Effects**: Perks that only activate when certain stack counts are reached
- **Synergy Effects**: Perks that become more powerful when combined with specific other perks

This system provides the foundation for the chaotic, Mario Party-style campaign progression while maintaining the clean architecture patterns established in the existing codebase. 