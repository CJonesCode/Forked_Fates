class_name KillFeed
extends Control

## Call of Duty style kill feed component
## Shows recent kills in the top right corner with player colors and weapon icons

# Configuration
const ENTRY_HEIGHT: float = 30.0
const ENTRY_SPACING: float = 5.0
const FADE_DURATION: float = 5.0
const MAX_ENTRIES: int = 5

# UI References
@onready var entries_container: VBoxContainer = $EntriesContainer

# Entry tracking
var active_entries: Array[KillFeedEntry] = []

# Player colors (matching PlayerHUD)
var player_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3, 1.0),  # Player 1 - Red
	Color(0.3, 0.3, 1.0, 1.0),  # Player 2 - Blue  
	Color(0.3, 1.0, 0.3, 1.0),  # Player 3 - Green
	Color(1.0, 1.0, 0.3, 1.0)   # Player 4 - Yellow
]

func _ready() -> void:
	# Setup the container
	if not entries_container:
		entries_container = VBoxContainer.new()
		entries_container.name = "EntriesContainer"
		add_child(entries_container)
	
	# Position in top right corner with proper sizing
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	
	# Constrain to reasonable width (max 400px or 30% of screen width, whichever is smaller)
	var screen_size = get_viewport().get_visible_rect().size
	var max_width = min(400.0, screen_size.x * 0.3)
	custom_minimum_size = Vector2(max_width, 200)
	size = Vector2(max_width, 200)
	
	# Position with margins from edges
	position.x -= max_width + 10  # Width + small margin from edge
	position.y += 10  # Small margin from top
	
	# Make sure it's on top of other UI
	z_index = 1000
	
	# Connect to kill events - simplified to just use weapon names
	EventBus.player_killed_by.connect(_on_player_killed_by)
	
	Logger.system("KillFeed initialized in top right corner (width: " + str(max_width) + ")", "KillFeed")

## Handle kill event and look up weapon icon
func _on_player_killed_by(victim_id: int, killer_id: int, weapon_name: String) -> void:
	Logger.debug("🎯 KILL FEED: Received kill event - victim=" + str(victim_id) + " killer=" + str(killer_id) + " weapon=" + weapon_name, "KillFeed")
	
	# Don't show environmental deaths in kill feed
	if killer_id == -1:
		Logger.debug("🎯 Kill feed ignoring environmental death (killer_id=-1)", "KillFeed")
		return
	
	# Get player data
	var killer_data = GameManager.get_player_data(killer_id)
	var victim_data = GameManager.get_player_data(victim_id)
	
	if not killer_data:
		Logger.error("🎯 ❌ Kill feed failed - killer data not found for ID " + str(killer_id), "KillFeed")
	if not victim_data:
		Logger.error("🎯 ❌ Kill feed failed - victim data not found for ID " + str(victim_id), "KillFeed")
	
	if not killer_data or not victim_data:
		Logger.warning("🎯 Missing player data for kill feed: killer=" + str(killer_id) + ", victim=" + str(victim_id), "KillFeed")
		return
	
	Logger.combat("🎯 ✅ KILL FEED: " + killer_data.player_name + " -> " + victim_data.player_name + " with " + weapon_name, "KillFeed")
	
	# Create kill entry and let it look up the weapon icon
	_add_kill_entry(killer_data, victim_data, weapon_name)

## Add a new kill entry to the feed
func _add_kill_entry(killer_data: PlayerData, victim_data: PlayerData, weapon_name: String) -> void:
	# Create new entry
	var entry = KillFeedEntry.new()
	entry.setup(killer_data, victim_data, weapon_name, player_colors, self)
	
	# Add to container at the top
	entries_container.add_child(entry)
	entries_container.move_child(entry, 0)  # Move to top
	
	# Add to tracking
	active_entries.insert(0, entry)
	
	# Remove old entries if we have too many
	while active_entries.size() > MAX_ENTRIES:
		var old_entry = active_entries.pop_back()
		old_entry._force_remove()
	
	# Start fade timer for this entry
	entry.start_fade_timer(FADE_DURATION)
	
	Logger.combat("Added kill feed entry: " + killer_data.player_name + " -> " + victim_data.player_name, "KillFeed")



## Remove an entry from the feed
func _remove_entry(entry: KillFeedEntry) -> void:
	if entry in active_entries:
		active_entries.erase(entry)
	entry.queue_free()

## Clear all entries
func clear_all_entries() -> void:
	for entry in active_entries:
		entry.queue_free()
	active_entries.clear()

# Inner class for individual kill feed entries
class KillFeedEntry extends Control:
	var fade_timer: Timer
	var killer_name: String
	var victim_name: String
	var weapon: String
	
	func setup(killer_data: PlayerData, victim_data: PlayerData, weapon_name: String, colors: Array[Color], parent_feed: KillFeed) -> void:
		killer_name = killer_data.player_name
		victim_name = victim_data.player_name
		weapon = weapon_name
		
		# Setup size - use parent's width
		var entry_width = parent_feed.size.x if parent_feed else 300.0
		custom_minimum_size = Vector2(entry_width, ENTRY_HEIGHT)
		size = Vector2(entry_width, ENTRY_HEIGHT)
		
		# Create horizontal layout
		var hbox = HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 4)  # Tight spacing
		add_child(hbox)
		
		# Killer info: [color] Name
		_add_killer_section(hbox, killer_data, colors)
		
		# Weapon icon
		_add_weapon_section(hbox, weapon_name, parent_feed)
		
		# Arrow
		_add_arrow_section(hbox)
		
		# Victim info: [color] Name  
		_add_victim_section(hbox, victim_data, colors)
		
		# Setup fade timer
		fade_timer = Timer.new()
		fade_timer.one_shot = true
		fade_timer.timeout.connect(_start_fade_out)
		add_child(fade_timer)
	
	func _add_killer_section(hbox: HBoxContainer, killer_data: PlayerData, colors: Array[Color]) -> void:
		# Color square
		var killer_square = ColorRect.new()
		killer_square.color = colors[killer_data.player_id % colors.size()]
		killer_square.custom_minimum_size = Vector2(16, 16)
		killer_square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(killer_square)
		
		# Name label (more compact)
		var killer_label = Label.new()
		killer_label.text = killer_data.player_name
		killer_label.add_theme_color_override("font_color", Color.WHITE)
		killer_label.clip_contents = true
		killer_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		killer_label.custom_minimum_size = Vector2(60, 16)  # Limit width
		killer_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(killer_label)
	
	func _add_weapon_section(hbox: HBoxContainer, weapon_name: String, parent_feed: KillFeed) -> void:
		# Simple text display for any damage source
		var display_name = weapon_name if weapon_name and weapon_name != "" else "Environment"
		
		var weapon_label = Label.new()
		weapon_label.text = display_name
		weapon_label.add_theme_color_override("font_color", Color.ORANGE)
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_label.custom_minimum_size = Vector2(60, 16)
		weapon_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(weapon_label)
	
	func _add_arrow_section(hbox: HBoxContainer) -> void:
		var arrow_label = Label.new()
		arrow_label.text = "→"
		arrow_label.add_theme_color_override("font_color", Color.GRAY)
		arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_label.custom_minimum_size = Vector2(16, 16)
		arrow_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(arrow_label)
	
	func _add_victim_section(hbox: HBoxContainer, victim_data: PlayerData, colors: Array[Color]) -> void:
		# Color square
		var victim_square = ColorRect.new()
		victim_square.color = colors[victim_data.player_id % colors.size()]
		victim_square.custom_minimum_size = Vector2(16, 16)
		victim_square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(victim_square)
		
		# Name label (more compact)
		var victim_label = Label.new()
		victim_label.text = victim_data.player_name
		victim_label.add_theme_color_override("font_color", Color.WHITE)
		victim_label.clip_contents = true
		victim_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		victim_label.custom_minimum_size = Vector2(60, 16)  # Limit width
		victim_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hbox.add_child(victim_label)
	
	func start_fade_timer(duration: float) -> void:
		if fade_timer:
			fade_timer.wait_time = duration
			fade_timer.start()
	
	func _start_fade_out() -> void:
		# Animate fade out
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
		tween.tween_callback(_force_remove)
	
	func _force_remove() -> void:
		var parent_feed = get_parent().get_parent() as KillFeed
		if parent_feed:
			parent_feed._remove_entry(self)
		else:
			queue_free() 
