extends Node2D

## Sudden Death Minigame
## 3-life elimination system with ragdoll physics

@onready var arena: Node2D = $Arena
@onready var spawn_points: Node2D = $SpawnPoints
@onready var respawn_points: Node2D = $RespawnPoints
@onready var item_spawn_points: Node2D = $ItemSpawnPoints
@onready var ui_overlay: CanvasLayer = $UIOverlay
@onready var back_button: Button = $UIOverlay/BackButton
@onready var game_timer_label: Label = $UIOverlay/GameTimer

# Remove the old status display - now using PlayerHUD
# @onready var player_status: Label = $UIOverlay/PlayerStatus

var players: Array[BasePlayer] = []
var spawned_items: Array[BaseItem] = []
var game_active: bool = false
var game_timer: float = 0.0

# Respawn system
@export var respawn_delay: float = 3.0
var dead_players: Dictionary = {}  # player_id -> respawn_timer
var respawn_pool: Array[Vector2] = []  # Available respawn positions

# Preload scenes
var player_scene = preload("res://scenes/player/base_player.tscn")
var pistol_scene = preload("res://scenes/items/pistol.tscn")
var bat_scene = preload("res://scenes/items/bat.tscn")
var player_hud_scene = preload("res://scenes/ui/player_hud.tscn")

# HUD instance
var player_hud: PlayerHUD = null

func _ready() -> void:
	print("Sudden Death minigame initialized")
	
	# Connect UI signals
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	# Connect to player death events for respawn handling
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_damage_reported.connect(_on_player_damage_reported)
	
	# Create and add the PlayerHUD
	player_hud = player_hud_scene.instantiate()
	add_child(player_hud)
	
	_setup_arena()
	_spawn_players()
	_spawn_items()
	_start_game()

func _process(delta: float) -> void:
	if game_active:
		game_timer += delta
		_update_game_timer_display()
		_handle_respawns(delta)
		_check_victory_condition()

## Update game timer display
func _update_game_timer_display() -> void:
	if game_timer_label:
		var minutes = int(game_timer) / 60
		var seconds = int(game_timer) % 60
		game_timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

## Handle back button press
func _on_back_button_pressed() -> void:
	print("Returning to map view...")
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	GameManager.change_state(GameManager.GameState.MAP_VIEW)

# Removed _on_player_health_changed - now handled by PlayerHUD automatically

func _setup_arena() -> void:
	print("Arena setup complete with platforms and boundaries")
	_setup_respawn_pool()

## Setup the respawn point pool
func _setup_respawn_pool() -> void:
	respawn_pool.clear()
	
	# Collect all respawn points
	for child in respawn_points.get_children():
		if child is Marker2D:
			respawn_pool.append(child.global_position)
	
	print("Respawn pool setup with ", respawn_pool.size(), " points: ", respawn_pool)

func _spawn_players() -> void:
	print("Spawning players...")
	
	# Get spawn point positions
	var spawn_positions: Array[Vector2] = []
	for child in spawn_points.get_children():
		if child is Marker2D:
			spawn_positions.append(child.global_position)
	
	var player_count = 0
	for player_data in GameManager.players.values():
		if player_count < spawn_positions.size():
			# Create player instance
			var player_instance = player_scene.instantiate()
			
			# Set player data BEFORE adding to scene (so _ready() gets correct data)
			player_instance.player_data = player_data
			
			# Now add to scene tree (this triggers _ready())
			add_child(player_instance)
			var spawn_pos = spawn_positions[player_count]
			player_instance.global_position = spawn_pos
			
			# Set the spawn position for respawning
			player_instance.set_spawn_position(spawn_pos)
			
			# Set player color based on ID to match HUD colors
			var player_sprite = player_instance.get_node("Sprite2D/PlayerSprite")
			if player_sprite:
				match player_data.player_id:
					0:
						player_sprite.color = Color(1.0, 0.3, 0.3, 1.0)  # Red (Player 1)
					1:
						player_sprite.color = Color(0.3, 0.3, 1.0, 1.0)  # Blue (Player 2)
					2:
						player_sprite.color = Color(0.3, 1.0, 0.3, 1.0)  # Green (Player 3)
					3:
						player_sprite.color = Color(1.0, 1.0, 0.3, 1.0)  # Yellow (Player 4)
			
			# Configure input controller
			var input_controller = player_instance.get_node("InputController")
			if input_controller:
				input_controller.setup_for_player(player_data.player_id)
			
			# Add to players array
			players.append(player_instance)
			
			print("Spawned player: ", player_data.player_name, " at ", spawn_positions[player_count])
			player_count += 1

func _spawn_items() -> void:
	print("Spawning items...")
	
	# Get item spawn positions
	var item_positions: Array[Vector2] = []
	for child in item_spawn_points.get_children():
		if child is Marker2D:
			item_positions.append(child.global_position)
	
	# Spawn items at each position
	for i in range(item_positions.size()):
		var item_scene_to_spawn = pistol_scene if i % 2 == 0 else bat_scene
		var item_instance = item_scene_to_spawn.instantiate()
		add_child(item_instance)
		item_instance.global_position = item_positions[i]
		spawned_items.append(item_instance)
		
		print("Spawned ", item_instance.item_name, " at ", item_positions[i])

func _start_game() -> void:
	game_active = true
	game_timer = 0.0
	
	# Initialize timer display
	_update_game_timer_display()
	
	EventBus.round_started.emit()
	print("Sudden death game started with ", players.size(), " players!")

func _check_victory_condition() -> void:
	# Count alive players
	var alive_players: Array[BasePlayer] = []
	for player in players:
		if player and player.current_state == BasePlayer.PlayerState.ALIVE:
			alive_players.append(player)
	
	# Check for victory condition
	if alive_players.size() <= 1:
		_end_game()

func _end_game() -> void:
	if not game_active:
		return
		
	game_active = false
	
	# Find winner
	var winner_id = -1
	var winner_name = "No One"
	
	for player in players:
		if player and player.current_state == BasePlayer.PlayerState.ALIVE:
			winner_id = player.player_data.player_id
			winner_name = player.player_data.player_name
			break
	
	var results = {
		"minigame_type": "sudden_death",
		"duration": game_timer,
		"winner_name": winner_name
	}
	
	EventBus.minigame_ended.emit(winner_id, results)
	print("Game ended! Winner: ", winner_name, " (Duration: ", game_timer, "s)") 

## Handle respawn timers and processing
func _handle_respawns(delta: float) -> void:
	var players_to_respawn: Array[int] = []
	
	for player_id in dead_players.keys():
		dead_players[player_id] -= delta
		
		# Emit timer update for UI
		EventBus.emit_player_respawn_timer_updated(player_id, dead_players[player_id])
		
		# Check if ready to respawn
		if dead_players[player_id] <= 0.0:
			players_to_respawn.append(player_id)
	
	# Respawn players whose timers have expired
	for player_id in players_to_respawn:
		_respawn_player(player_id)

## Handle player death - start respawn process if they have lives
func _on_player_died(player_id: int) -> void:
	var player_data = GameManager.get_player_data(player_id)
	if player_data and player_data.current_lives > 0:
		print("⏳ Starting respawn process for Player ", player_id, " in ", respawn_delay, " seconds")
		dead_players[player_id] = respawn_delay
		
		# Make player invisible during respawn
		var player = _get_player_by_id(player_id)
		if player:
			player.visible = false
	else:
		print("💀 Player ", player_id, " is out of lives - no respawn")

## Handle player damage reports from weapons
func _on_player_damage_reported(victim_id: int, attacker_id: int, damage: int, weapon_name: String) -> void:
	print("🎮 Minigame received damage: Player ", attacker_id, " hit Player ", victim_id, " with ", weapon_name, " for ", damage, " damage")
	
	var victim_player = _get_player_by_id(victim_id)
	var victim_data = GameManager.get_player_data(victim_id)
	
	if not victim_player or not victim_data:
		print("❌ Invalid victim player for damage: ", victim_id)
		return
	
	# Only process damage for living players
	if victim_player.current_state == BasePlayer.PlayerState.DEAD:
		print("❌ Attempted to damage dead player: ", victim_id)
		return
	
	# Calculate new health
	var new_health = max(0, victim_data.current_health - damage)
	print("   Health change: ", victim_data.current_health, " -> ", new_health)
	
	# Update player data
	victim_data.current_health = new_health
	
	# Tell the player to update their health
	victim_player.set_health(new_health)
	
	# Emit health change event for UI
	EventBus.emit_player_health_changed(victim_id, new_health)
	
	# Check if player died
	if new_health <= 0:
		_handle_player_death(victim_id)

## Handle player death from health loss
func _handle_player_death(player_id: int) -> void:
	var player = _get_player_by_id(player_id)
	var player_data = GameManager.get_player_data(player_id)
	
	if not player or not player_data:
		return
	
	print("💀 Minigame handling death of Player ", player_id)
	
	# Update player data
	player_data.current_lives -= 1
	player_data.is_alive = false
	player_data.current_health = 0
	
	# Tell player to die
	player.die()
	
	# Emit events
	EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
	EventBus.emit_player_died(player_id)

## Respawn a specific player
func _respawn_player(player_id: int) -> void:
	var player = _get_player_by_id(player_id)
	var player_data = GameManager.get_player_data(player_id)
	
	if player and player_data and respawn_pool.size() > 0:
		# Choose a respawn point from the pool
		var respawn_position = respawn_pool[randi() % respawn_pool.size()]
		
		# Update player's spawn position to the respawn point
		player.set_spawn_position(respawn_position)
		
		# Restore player health and state
		player_data.current_health = player_data.max_health
		player_data.is_alive = true
		
		# Tell player to update their health
		player.set_health(player_data.current_health)
		
		# Respawn the player
		player.respawn()
		
		# Emit health change for UI
		EventBus.emit_player_health_changed(player_id, player_data.current_health)
		
		dead_players.erase(player_id)
		print("✅ Player ", player_id, " respawned by minigame at ", respawn_position, " with ", player_data.current_health, " health")
	else:
		print("❌ Cannot respawn Player ", player_id, " - no player found or no respawn points")

## Get player instance by ID
func _get_player_by_id(player_id: int) -> BasePlayer:
	for player in players:
		if player.player_data.player_id == player_id:
			return player
	return null 