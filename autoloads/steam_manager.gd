extends Node

# Steam initialization - Using Spacewar App ID 480 for development
var app_id: int = 480  # Spacewar development App ID
var is_steam_enabled: bool = false

# Lobby management
var current_lobby_id: int = 0
var lobby_members: Array[int] = []
var max_lobby_size: int = 4

# Steam networking signals
signal steam_initialized()
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int) 
signal lobby_left(lobby_id: int)
signal player_joined_lobby(steam_id: int)
signal player_left_lobby(steam_id: int)
signal network_message_received(sender_id: int, message: PackedByteArray)

func _ready() -> void:
	_initialize_steam()
	_connect_steam_signals()

func _initialize_steam() -> void:
	# Try to initialize Steam directly (skip OS.has_feature check as it may not work with GDExtensions)
	Logger.debug("Attempting Steam initialization...", "SteamManager")
	
	# Check if Steam class exists
	if not ClassDB.class_exists("Steam"):
		Logger.warning("Steam class not found - GDExtension may not be loaded", "SteamManager")
		return
	
	# Try to initialize Steam with Spacewar App ID
	var init_result = Steam.steamInit()
	
	if init_result:
		is_steam_enabled = true
		Logger.system("Steam initialized successfully with App ID " + str(app_id), "SteamManager")
		steam_initialized.emit()
	else:
		Logger.error("Steam initialization failed - check if Steam client is running", "SteamManager")

func _connect_steam_signals() -> void:
	if not is_steam_enabled:
		Logger.warning("Cannot connect Steam signals - Steam not enabled", "SteamManager")
		return
		
	# Connect Steam lobby callbacks
	if not Steam.lobby_created.is_connected(_on_lobby_created):
		Steam.lobby_created.connect(_on_lobby_created)
		Logger.debug("Connected lobby_created signal", "SteamManager")
	
	if not Steam.lobby_joined.is_connected(_on_lobby_joined):
		Steam.lobby_joined.connect(_on_lobby_joined)
		Logger.debug("Connected lobby_joined signal", "SteamManager")
	
	if not Steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		Steam.lobby_chat_update.connect(_on_lobby_chat_update)
		Logger.debug("Connected lobby_chat_update signal", "SteamManager")
	
	if not Steam.p2p_session_request.is_connected(_on_p2p_session_request):
		Steam.p2p_session_request.connect(_on_p2p_session_request)
		Logger.debug("Connected p2p_session_request signal", "SteamManager")
	
	if not Steam.p2p_session_connect_fail.is_connected(_on_p2p_session_connect_fail):
		Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
		Logger.debug("Connected p2p_session_connect_fail signal", "SteamManager")
	
	Logger.system("All Steam signals connected successfully", "SteamManager")

# Lobby Creation
func create_lobby() -> void:
	if not is_steam_enabled:
		Logger.warning("Cannot create lobby - Steam not initialized", "SteamManager")
		return
	
	# Verify signal is connected before creating lobby
	if not Steam.lobby_created.is_connected(_on_lobby_created):
		Logger.warning("lobby_created signal not connected - reconnecting", "SteamManager")
		Steam.lobby_created.connect(_on_lobby_created)
	
	Logger.system("Creating Steam lobby with type FRIENDS_ONLY, max size: " + str(max_lobby_size), "SteamManager")
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_lobby_size)
	
	# Add a timeout to detect if lobby creation fails (match LobbyBrowser timeout)
	lobby_creation_timer = get_tree().create_timer(15.0)
	lobby_creation_timer.timeout.connect(_on_lobby_creation_timeout)

# Lobby Joining  
func join_lobby(lobby_id: int) -> void:
	if not is_steam_enabled:
		Logger.warning("Cannot join lobby - Steam not initialized", "SteamManager")
		return
		
	Steam.joinLobby(lobby_id)
	Logger.system("Joining lobby: " + str(lobby_id), "SteamManager")

# Leave current lobby
func leave_lobby() -> void:
	if not is_steam_enabled or current_lobby_id == 0:
		return
		
	Steam.leaveLobby(current_lobby_id)
	Logger.system("Leaving lobby: " + str(current_lobby_id), "SteamManager")

# P2P Message Sending
func send_message_to_all(message: PackedByteArray) -> void:
	if not is_steam_enabled:
		return
		
	for member_id in lobby_members:
		if member_id != Steam.getSteamID():
			Steam.sendP2PPacket(member_id, message, Steam.P2P_SEND_RELIABLE)

func send_message_to_player(player_id: int, message: PackedByteArray) -> void:
	if not is_steam_enabled:
		return
		
	Steam.sendP2PPacket(player_id, message, Steam.P2P_SEND_RELIABLE)

# Timeout handling
var lobby_creation_timer: SceneTreeTimer

func _on_lobby_creation_timeout() -> void:
	# Only log error if lobby creation actually failed
	if current_lobby_id == 0:
		Logger.error("Lobby creation timed out after 15 seconds", "SteamManager")
	else:
		Logger.debug("Lobby creation timeout fired, but lobby was already created successfully", "SteamManager")
	
	# Clean up timer reference
	lobby_creation_timer = null

# Steam Callbacks
func _on_lobby_created(result: int, lobby_id: int) -> void:
	Logger.debug("Received lobby_created callback: result=" + str(result) + ", lobby_id=" + str(lobby_id), "SteamManager")
	
	# Clear timeout timer if it exists
	if lobby_creation_timer:
		lobby_creation_timer = null
	
	if result == 1:  # k_EResultOK
		current_lobby_id = lobby_id
		lobby_created.emit(lobby_id)
		Logger.system("Lobby created successfully: " + str(lobby_id), "SteamManager")
	else:
		var error_msg = _get_steam_result_string(result)
		Logger.error("Failed to create lobby. Result: " + str(result) + " (" + error_msg + ")", "SteamManager")

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if response == 1:  # k_EChatRoomEnterResponseSuccess
		current_lobby_id = lobby_id
		_update_lobby_members()
		lobby_joined.emit(lobby_id)
		Logger.system("Joined lobby successfully: " + str(lobby_id), "SteamManager")
	else:
		Logger.error("Failed to join lobby. Response: " + str(response), "SteamManager")

func _on_lobby_chat_update(lobby_id: int, changed_id: int, making_change_id: int, chat_state: int) -> void:
	# Handle player joining/leaving lobby
	_update_lobby_members()
	
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		player_joined_lobby.emit(changed_id)
		Logger.system("Player joined lobby: " + str(changed_id), "SteamManager")
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		player_left_lobby.emit(changed_id)
		Logger.system("Player left lobby: " + str(changed_id), "SteamManager")

func _update_lobby_members() -> void:
	lobby_members.clear()
	var member_count = Steam.getNumLobbyMembers(current_lobby_id)
	for i in range(member_count):
		var member_id = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		lobby_members.append(member_id)

func _on_p2p_session_request(remote_id: int) -> void:
	# Accept all P2P session requests from lobby members
	if remote_id in lobby_members:
		Steam.acceptP2PSessionWithUser(remote_id)
		Logger.system("Accepted P2P session with: " + str(remote_id), "SteamManager")

func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
	Logger.error("P2P session failed with " + str(steam_id) + " Error: " + str(session_error), "SteamManager")

# Message receiving and callback processing (called each frame)
func _process(_delta: float) -> void:
	if is_steam_enabled:
		# CRITICAL: Process Steam callbacks each frame
		Steam.run_callbacks()
		_read_p2p_packets()

func _read_p2p_packets() -> void:
	var packet_size = Steam.getAvailableP2PPacketSize(0)
	while packet_size > 0:
		var packet = Steam.readP2PPacket(packet_size, 0)
		if packet.size() > 0:
			var sender_id = packet["remote_steam_id"]
			var message = packet["data"]
			network_message_received.emit(sender_id, message)
		
		packet_size = Steam.getAvailableP2PPacketSize(0)

# Utility functions
func get_player_name(steam_id: int) -> String:
	if not is_steam_enabled:
		return "Player"
	return Steam.getFriendPersonaName(steam_id)

func get_local_steam_id() -> int:
	if not is_steam_enabled:
		return 0
	return Steam.getSteamID()

func is_lobby_owner() -> bool:
	if not is_steam_enabled or current_lobby_id == 0:
		return false
	var owner_id = Steam.getLobbyOwner(current_lobby_id)
	return owner_id == Steam.getSteamID()

# Helper function to translate Steam result codes
func _get_steam_result_string(result: int) -> String:
	match result:
		1: return "OK"
		2: return "Fail"
		3: return "NoConnection"
		5: return "InvalidPassword"
		6: return "LoggedInElsewhere"
		7: return "InvalidProtocolVer"
		8: return "InvalidParam"
		9: return "FileNotFound"
		10: return "Busy"
		11: return "InvalidState"
		12: return "InvalidName"
		13: return "InvalidEmail"
		14: return "DuplicateName"
		15: return "AccessDenied"
		16: return "Timeout"
		17: return "Banned"
		18: return "AccountNotFound"
		19: return "InvalidSteamID"
		20: return "ServiceUnavailable"
		21: return "NotLoggedOn"
		22: return "Pending"
		23: return "EncryptionFailure"
		24: return "InsufficientPrivilege"
		25: return "LimitExceeded"
		26: return "Revoked"
		27: return "Expired"
		28: return "AlreadyRedeemed"
		29: return "DuplicateRequest"
		30: return "AlreadyOwned"
		31: return "IPNotFound"
		32: return "PersistFailed"
		33: return "LockingFailed"
		34: return "LogonSessionReplaced"
		35: return "ConnectFailed"
		36: return "HandshakeFailed"
		37: return "IOFailure"
		38: return "RemoteDisconnect"
		39: return "ShoppingCartNotFound"
		40: return "Blocked"
		41: return "Ignored"
		42: return "NoMatch"
		43: return "AccountDisabled"
		_: return "Unknown (" + str(result) + ")" 