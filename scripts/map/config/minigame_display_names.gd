class_name MinigameDisplayNames
extends Resource

## Centralized mapping for map node types to display names
## Maps node types to actual minigame names that players recognize

# Static mapping for node type to display name
const DISPLAY_NAMES: Dictionary = {
	"start": "Sudden Death",
	"boss": "Final Boss Battle",
	"sudden_death": "Sudden Death",
	"shop": "Item Shop",
	"race": "Race Challenge", 
	"gem_collection": "Gem Collection",
	"tag": "Tag Game",
	"normal": "Combat Arena"      # Fallback for any remaining normal nodes
}

## Get display name for a node type
## Optionally supports dynamic resolution via minigame_id for future expansion
static func get_display_name(node_type: String, minigame_id: String = "") -> String:
	# If a specific minigame_id is provided, try to get its configured name first
	if minigame_id != "":
		var minigame_name: String = _get_minigame_config_name(minigame_id)
		if minigame_name != "":
			return minigame_name
	
	# Fall back to static mapping
	if DISPLAY_NAMES.has(node_type):
		return DISPLAY_NAMES[node_type]
	
	# Fallback to capitalized node type for unknown types
	return node_type.capitalize()

## Get minigame name from configuration (future-proofing for dynamic minigame assignment)
static func _get_minigame_config_name(minigame_id: String) -> String:
	# Try to load the minigame config and get its display name
	# This supports future cases where nodes might have specific minigame_id assignments
	if ConfigManager and ConfigManager.has_method("get_minigame_config"):
		var config: MinigameConfig = ConfigManager.get_minigame_config(minigame_id)
		if config and config.minigame_name != "":
			return config.minigame_name
	
	return ""

## Get all available node types with their display names
static func get_all_mappings() -> Dictionary:
	return DISPLAY_NAMES.duplicate()

## Check if a node type has a custom display name
static func has_custom_name(node_type: String) -> bool:
	return DISPLAY_NAMES.has(node_type)
