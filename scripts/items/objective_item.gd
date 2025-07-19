class_name ObjectiveItem
extends BaseItem

## Objective items for keys, collectibles, and puzzle elements
## Used in collection and objective-based minigames

# Objective properties
@export var objective_type: String = "generic"  # "key", "coin", "gem", "flag", etc.
@export var objective_value: int = 1  # Points or completion value
@export var required_for_completion: bool = false
@export var unlock_target: String = ""  # What this key/item unlocks
@export var collection_group: String = ""  # Group for collective objectives

# State
var is_collected: bool = false

signal objective_collected(collector: BasePlayer, item_type: String, value: int)
signal objective_completed(collector: BasePlayer, group: String)

func _ready() -> void:
	super()
	
	# Set default properties for objectives
	item_description = "An objective item used for goals and puzzles"
	can_be_dropped = false  # Objectives typically can't be dropped once collected
	
	Logger.item("ObjectiveItem " + item_name + " (" + objective_type + ") ready", "ObjectiveItem")

## Override pickup for objective collection mechanics
func pickup(player: BasePlayer) -> bool:
	if is_collected:
		return false
	
	# Don't use standard pickup - objectives have special collection logic
	if not can_be_picked_up:
		return false
	
	_collect_objective(player)
	return true

## Collect this objective (alternative to pickup for auto-collection)
func _collect_objective(player: BasePlayer) -> void:
	if is_collected:
		return
	
	is_collected = true
	
	# Add to player's objective collection (would need ObjectiveComponent)
	var player_data = player.player_data
	if player_data:
		Logger.item(player_data.player_name + " collected " + objective_type + " (" + item_name + ") worth " + str(objective_value), "ObjectiveItem")
	
	# Emit collection signal
	objective_collected.emit(player, objective_type, objective_value)
	
	# Check for group completion
	if collection_group != "":
		_check_group_completion(player)
	
	# Visual/audio feedback
	_play_collection_feedback()
	
	# Remove from scene after collection
	visible = false
	can_be_picked_up = false
	
	# Destroy after a short delay (allows for effects)
	await get_tree().create_timer(0.5).timeout
	queue_free()

## Check if collecting this item completes a group objective
func _check_group_completion(collector: BasePlayer) -> void:
	# This would need integration with a minigame objective system
	# For now, just emit a signal that can be caught by minigame managers
	Logger.item("Checking group completion for: " + collection_group, "ObjectiveItem")
	
	# Emit group completion signal (minigame can listen and check totals)
	objective_completed.emit(collector, collection_group)

## Play collection feedback (visual/audio)
func _play_collection_feedback() -> void:
	# Add particle effect or sound
	if has_node("CollectionSound"):
		var sound_player: AudioStreamPlayer2D = get_node("CollectionSound")
		sound_player.play()
	
	# Add visual feedback (tween scale, flash, etc.)
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(self, "modulate", Color.WHITE.blend(Color.YELLOW), 0.2)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)

## Manual trigger for proximity-based collection
func trigger_collection(triggering_player: BasePlayer) -> void:
	if not is_collected and can_be_picked_up:
		_collect_objective(triggering_player)

## Get objective status for UI display
func get_objective_info() -> Dictionary:
	var info = get_item_info()
	info["objective_type"] = objective_type
	info["objective_value"] = objective_value
	info["is_collected"] = is_collected
	info["collection_group"] = collection_group
	info["required_for_completion"] = required_for_completion
	return info 