class_name DirectConnect
extends Control

## Steam Lobby UI for Steamworks multiplayer
## Create and join Steam lobbies for multiplayer sessions

# UI References
@onready var local_steam_label: Label = $MainContainer/Header/LocalIPPanel/LocalIPContainer/LocalIPValue
@onready var host_button: Button = $MainContainer/ContentStack/HostPanel/HostContainer/HostButton
@onready var join_button: Button = $MainContainer/ContentStack/JoinPanel/JoinContainer/JoinInputContainer/JoinButton
@onready var lobby_input: LineEdit = $MainContainer/ContentStack/JoinPanel/JoinContainer/JoinInputContainer/IPInput
@onready var back_button: Button = $MainContainer/Footer/BackButton
@onready var status_message: Label = $MainContainer/Footer/StatusMessage

# State machine
enum ConnectionState {
	DISCONNECTED,
	HOSTING,
	CONNECTING,
	CONNECTED,
	ERROR
}

var current_state: ConnectionState = ConnectionState.DISCONNECTED : set = _set_state
var previous_state: ConnectionState = ConnectionState.DISCONNECTED

# Steam data
var local_steam_id: int = 0
var local_steam_name: String = ""

# Retry/timeout handling
var retry_handler: RetryHandler
var connection_timer: SceneTreeTimer

# Inner class for retry logic
class RetryHandler:
	var max_retries: int = 3
	var current_attempt: int = 0
	var retry_delay: float = 2.0
	var parent: DirectConnect
	var operation_type: String = ""
	var operation_data: Dictionary = {}
	
	func _init(parent_node: DirectConnect):
		parent = parent_node
		max_retries = 3
		retry_delay = 2.0
	
	func attempt_operation(operation: String, data: Dictionary = {}) -> void:
		operation_type = operation
		operation_data = data
		current_attempt = 0
		_try_operation()
	
	func _try_operation() -> void:
		current_attempt += 1
		Logger.debug("Attempt " + str(current_attempt) + "/" + str(max_retries) + " for " + operation_type, "RetryHandler")
		
		match operation_type:
			"join":
				var lobby_id = operation_data.get("lobby_id", 0)
				if SteamManager and SteamManager.is_steam_enabled:
					SteamManager.join_lobby(lobby_id)
					Logger.system("Lobby join attempt started for " + str(lobby_id), "RetryHandler")
					_start_timeout()
				else:
					_on_operation_failed("Steam not available")
			"host":
				if SteamManager and SteamManager.is_steam_enabled:
					SteamManager.create_lobby()
					Logger.system("Lobby creation attempt started", "RetryHandler")
					_start_timeout()
				else:
					_on_operation_failed("Steam not available")
	
	func _start_timeout() -> void:
		var timeout_duration = 15.0  # Default timeout for Steam operations
		
		parent.connection_timer = parent.get_tree().create_timer(timeout_duration)
		parent.connection_timer.timeout.connect(_on_timeout)
	
	func _on_timeout() -> void:
		Logger.warning("Steam operation timed out", "RetryHandler")
		_on_operation_failed("Operation timed out")
	
	func _on_operation_failed(error_message: String) -> void:
		if current_attempt < max_retries:
			parent._update_status_message("Attempt " + str(current_attempt) + " failed: " + error_message + ". Retrying in " + str(retry_delay) + "s...", Color.ORANGE)
			
			# Schedule retry
			var retry_timer = parent.get_tree().create_timer(retry_delay)
			retry_timer.timeout.connect(_try_operation)
		else:
			parent._update_status_message("Failed after " + str(max_retries) + " attempts: " + error_message, Color.RED)
			parent.current_state = DirectConnect.ConnectionState.ERROR
			_reset()
	
	func _on_operation_succeeded() -> void:
		Logger.system("Operation '" + operation_type + "' succeeded on attempt " + str(current_attempt), "RetryHandler")
		_reset()
	
	func cancel_operation() -> void:
		Logger.debug("Cancelling operation: " + operation_type, "RetryHandler")
		if parent.connection_timer:
			parent.connection_timer = null
		_reset()
	
	func _reset() -> void:
		current_attempt = 0
		operation_type = ""
		operation_data.clear()

func _ready() -> void:
	# Connect UI signals
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	lobby_input.text_submitted.connect(_on_lobby_id_submitted)
	
	# Connect to Steam events
	if SteamManager:
		SteamManager.lobby_created.connect(_on_lobby_created)
		SteamManager.lobby_joined.connect(_on_lobby_joined)
		SteamManager.lobby_left.connect(_on_lobby_left)
		
	# Connect to GameManager events
	if GameManager:
		GameManager.network_session_started.connect(_on_network_session_started)
		GameManager.network_session_ended.connect(_on_network_session_ended)
	
	# Get and display Steam info
	_update_steam_info()
	
	# Initialize retry handler
	retry_handler = RetryHandler.new(self)
	
	Logger.system("Steam lobby UI initialized", "DirectConnect")

func _set_state(new_state: ConnectionState) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	
	Logger.debug("Connection state changed: " + str(previous_state) + " -> " + str(current_state), "DirectConnect")
	_on_state_changed(previous_state, current_state)

func _on_state_changed(old_state: ConnectionState, new_state: ConnectionState) -> void:
	_update_ui_for_state(new_state)

func _update_ui_for_state(state: ConnectionState) -> void:
	# Update UI elements based on current state
	match state:
		ConnectionState.DISCONNECTED:
			host_button.text = "🏠 Host Game"
			host_button.disabled = false
			join_button.disabled = false
			lobby_input.editable = true
		ConnectionState.HOSTING:
			host_button.text = "🛑 Stop Hosting"
			host_button.disabled = false
			join_button.disabled = true
			lobby_input.editable = false
		ConnectionState.CONNECTING:
			host_button.disabled = true
			join_button.disabled = true
			lobby_input.editable = false
		ConnectionState.CONNECTED:
			host_button.disabled = true
			join_button.disabled = true
			lobby_input.editable = false
		ConnectionState.ERROR:
			host_button.disabled = false
			join_button.disabled = false
			lobby_input.editable = true

func _update_steam_info() -> void:
	if SteamManager and SteamManager.is_steam_enabled:
		local_steam_id = SteamManager.get_local_steam_id()
		local_steam_name = SteamManager.get_player_name(local_steam_id)
		if local_steam_label:
			local_steam_label.text = local_steam_name
		
		Logger.system("Steam info updated: ID=" + str(local_steam_id) + ", Name=" + local_steam_name, "DirectConnect")
	else:
		if local_steam_label:
			local_steam_label.text = "Steam not available"
		Logger.warning("Steam not available for info update", "DirectConnect")

## UI Event Handlers

func _on_host_button_pressed() -> void:
	if current_state == ConnectionState.HOSTING:
		_stop_hosting()
	else:
		_start_hosting()

func _on_join_button_pressed() -> void:
	_attempt_join()

func _on_lobby_id_submitted(text: String) -> void:
	_attempt_join()

func _on_back_button_pressed() -> void:
	_close_direct_connect()

## Network Operations

func _start_hosting() -> void:
	if current_state != ConnectionState.DISCONNECTED:
		return
	
	current_state = ConnectionState.HOSTING
	_update_status_message("Starting host server...", Color.YELLOW)
	
	# Use retry handler for robust server starting
	retry_handler.attempt_operation("host")

func _stop_hosting() -> void:
	if current_state != ConnectionState.HOSTING:
		return
	
	_update_status_message("Stopping server...", Color.YELLOW)
	
	if SteamManager:
		SteamManager.leave_lobby()
	
	current_state = ConnectionState.DISCONNECTED
	_update_status_message("Server stopped", Color.WHITE)
	Logger.system("Stopped hosting", "DirectConnect")

func _attempt_join() -> void:
	if current_state != ConnectionState.DISCONNECTED:
		return
	
	var lobby_id = lobby_input.text.strip_edges().to_int()
	if lobby_id == 0:
		_update_status_message("Please enter a valid lobby ID", Color.RED)
		lobby_input.grab_focus()
		return
	
	current_state = ConnectionState.CONNECTING
	_update_status_message("Connecting to lobby " + str(lobby_id) + "...", Color.YELLOW)
	
	# Use retry handler for robust connection
	retry_handler.attempt_operation("join", {"lobby_id": lobby_id})

func _update_status_message(message: String, color: Color = Color.WHITE) -> void:
	if status_message:
		status_message.text = message
		status_message.modulate = color

## Steam Event Handlers

func _on_lobby_created(lobby_id: int) -> void:
	Logger.system("Steam lobby created: " + str(lobby_id), "DirectConnect")
	current_state = ConnectionState.HOSTING
	_update_status_message("Lobby created! ID: " + str(lobby_id) + " - Share this with friends!", Color.GREEN)
	
	# Notify retry handler of success
	if retry_handler:
		retry_handler._on_operation_succeeded()

func _on_lobby_joined(lobby_id: int) -> void:
	Logger.system("Joined Steam lobby: " + str(lobby_id), "DirectConnect")
	current_state = ConnectionState.CONNECTED
	_update_status_message("Connected to lobby: " + str(lobby_id), Color.GREEN)
	
	# Notify retry handler of success
	if retry_handler:
		retry_handler._on_operation_succeeded()
	
	# Transition to game
	await get_tree().create_timer(1.0).timeout
	GameManager.transition_to_map_view()
	_close_direct_connect()

func _on_lobby_left(lobby_id: int) -> void:
	Logger.system("Left Steam lobby: " + str(lobby_id), "DirectConnect")
	current_state = ConnectionState.DISCONNECTED
	_update_status_message("Left lobby", Color.WHITE)

## Network Event Handlers

func _on_network_session_started() -> void:
	Logger.system("Network session started", "DirectConnect")
	
	# Cancel any ongoing retry operations since we succeeded
	if retry_handler:
		retry_handler.cancel_operation()
	
	if current_state == ConnectionState.HOSTING:
		_update_status_message("Hosting Steam Lobby - Share lobby ID with friends!", Color.GREEN)
		
		# Notify retry handler of success
		if retry_handler:
			retry_handler._on_operation_succeeded()
	else:
		current_state = ConnectionState.CONNECTED
		_update_status_message("Connected successfully!", Color.GREEN)
		
		# Notify retry handler of success
		if retry_handler:
			retry_handler._on_operation_succeeded()
		
		# Transition to game
		await get_tree().create_timer(1.0).timeout
		GameManager.transition_to_map_view()
		_close_direct_connect()

func _on_network_session_ended() -> void:
	Logger.system("Network session ended", "DirectConnect")
	_update_status_message("Connection ended", Color.WHITE)
	
	# Reset to disconnected state
	current_state = ConnectionState.DISCONNECTED

## Close the direct connect interface
func _close_direct_connect() -> void:
	Logger.system("Closing direct connect interface", "DirectConnect")
	
	# Cancel any ongoing retry operations
	if retry_handler:
		retry_handler.cancel_operation()
	
	# Clean up any active connections based on state
	match current_state:
		ConnectionState.HOSTING:
			_stop_hosting()
		ConnectionState.CONNECTING, ConnectionState.CONNECTED:
			if SteamManager:
				SteamManager.leave_lobby()
	
	# Remove from scene tree
	queue_free() 
