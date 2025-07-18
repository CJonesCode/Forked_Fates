# Steamworks P2P Direct Connect System

**Status**: NYI (Not Yet Implemented)  
**Priority**: High - Core Multiplayer Feature  
**Godot Version**: 4.4.1  
**GodotSteam Version**: 4.15 (GDExtension)  
**Architecture**: Steam P2P direct connections with simple host/join UX

## 🎯 **Implementation Overview**

Forked Fates uses **Steam Multi-Connection System** for flexible, reliable multiplayer:
- **Direct P2P connections** - No relay servers, direct Steam P2P networking
- **Steam Remote Play** - Stream gameplay to friends without requiring game ownership
- **Multiple discovery methods** - LAN discovery, friend connections, join codes, and remote play
- **Unified connection system** - All P2P methods use same infrastructure, Remote Play uses Steam streaming
- **Automatic Steam integration** - Seamless friend and LAN discovery

**Key Insight**: Provide multiple ways to connect (LAN, friends, codes, remote play) covering both networked multiplayer and streaming-based multiplayer for maximum accessibility.

## 🏗️ **Architecture: Steam P2P Direct Connect**

### **Current Direct Connect UI (Already Converted)** ✅
```gdscript
# The codebase already converted Direct Connect UI to use Steam lobbies:
# "UI Conversion: Direct Connect UI now creates/joins Steam lobbies instead of IP connections"

# scripts/ui/direct_connect.gd - Already exists and uses Steam
# scenes/ui/direct_connect.tscn - Already converted to Steam lobby UI
```

### **Design Philosophy: Multiple Connection Methods**
```
Traditional IP Networking:       Steam Multi-Connection System:
- Manual IP addresses           - LAN: Auto-discover games on network  
- Port forwarding required      - Friends: See games in Steam friends list
- Limited to direct IPs         - Codes: Share 6-digit codes anywhere
- All players need game         - Remote Play: Stream to friends (no game needed)
- Manual firewall config        - P2P: No port forwarding (Steam handles NAT)
- No security/authentication    - All: Steam authentication built-in
```

### **User Experience Flows**

#### **Method 1: LAN Discovery** (Automatic)
```
Host Player:                     LAN Players:
1. Click "Host LAN Game"        1. Open "Join Game" tab
2. Game appears on LAN          2. See host's game in LAN list  
3. Friends see game instantly   3. Click "Join" → Connect automatically
```

#### **Method 2: Friend Discovery** (Steam Friends)
```
Host Player:                     Steam Friends:
1. Click "Host Game"            1. See game in Steam friends list
2. Game visible to friends      2. Right-click friend → "Join Game"
3. Set game status in Steam     3. Connect automatically via Steam
```

#### **Method 3: Join Codes** (Universal)
```
Host Player:                     Any Player:
1. Click "Host Private Game"    1. Click "Join by Code"
2. Get code "485720"            2. Enter code: 485720  
3. Share code anywhere          3. Connect directly via Steam P2P
```

#### **Method 4: Steam Remote Play** (Streaming)
```
Host Player:                     Remote Players:
1. Click "Host Remote Play"     1. See "Remote Play" invite in Steam
2. Game shows in Steam as       2. Click "Join via Remote Play"
   "Available for Remote Play"  3. Stream host's game instantly
3. Friends can join instantly   4. Play without owning the game
```

## 📋 **Implementation Phases**

### **Phase 1: Steam Multi-Connection Foundation**
- [ ] Steam lobby system with multiple visibility modes (LAN, Friends, Private)
- [ ] LAN discovery via Steam lobby search
- [ ] Friend integration via Steam rich presence  
- [ ] Join codes for private/direct connections
- [ ] Steam Remote Play integration and session management
- [ ] Unified P2P messaging system

### **Phase 2: Game State Synchronization**  
- [ ] Player state sync over P2P
- [ ] Input prediction and lag compensation
- [ ] Event synchronization via existing EventBus

### **Phase 3: Polish & Robustness**
- [ ] Connection recovery and timeout handling
- [ ] Network debugging and monitoring
- [ ] Performance optimization

## 🔧 **Phase 1: Steam P2P Direct Connect Foundation**

### **1.1 Enhanced Steam Manager - Multi-Connection Support**

```gdscript
# autoloads/steam_manager.gd
extends Node

# Steam P2P Multi-Connection System
var app_id: int = 0  # TODO: Replace with your Steam App ID
var is_steam_enabled: bool = false
var current_lobby_id: int = 0
var is_hosting: bool = false
var connected_peers: Array[int] = []
var lobby_visibility_mode: LobbyVisibility = LobbyVisibility.PRIVATE

enum LobbyVisibility {
    LAN_DISCOVERABLE,    # Visible to LAN players via lobby search
    FRIENDS_ONLY,        # Visible to Steam friends only
    PRIVATE,             # Only accessible via join codes
    REMOTE_PLAY          # Steam Remote Play streaming session
}

# Multi-connection signals
signal steam_initialized()
signal lobby_created(lobby_id: int, visibility: LobbyVisibility)
signal lobby_code_generated(code: String)
signal lan_lobbies_discovered(lobbies: Array)
signal connection_established(peer_id: int)
signal connection_lost(peer_id: int)
signal direct_message_received(peer_id: int, message: Dictionary)

# Steam Remote Play signals
signal remote_play_session_started()
signal remote_play_session_ended()
signal remote_play_player_connected(session_id: int, player_name: String)
signal remote_play_player_disconnected(session_id: int)

func _ready() -> void:
    _initialize_steam()
    _connect_steam_signals()

func _initialize_steam() -> void:
    var init_result = Steam.steamInit()
    if init_result:
        is_steam_enabled = true
        Logger.system("Steam P2P Direct Connect initialized", "SteamManager")
        steam_initialized.emit()
    else:
        Logger.error("Steam initialization failed - multiplayer unavailable", "SteamManager")

func _connect_steam_signals() -> void:
    Steam.lobby_created.connect(_on_lobby_created)
    Steam.lobby_joined.connect(_on_lobby_joined)
    Steam.lobby_match_list.connect(_on_lobby_match_list)  # For LAN discovery
    Steam.join_requested.connect(_on_join_requested)      # For friend invites
    Steam.p2p_session_request.connect(_on_p2p_session_request)
    Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
    
    # Steam Remote Play signals
    Steam.remote_play_session_connected.connect(_on_remote_play_connected)
    Steam.remote_play_session_disconnected.connect(_on_remote_play_disconnected)

# Method 1: Host LAN discoverable game
func start_lan_hosting() -> void:
    lobby_visibility_mode = LobbyVisibility.LAN_DISCOVERABLE
    _create_lobby(Steam.LOBBY_TYPE_PUBLIC, "LAN Game")

# Method 2: Host friends-only game  
func start_friends_hosting() -> void:
    lobby_visibility_mode = LobbyVisibility.FRIENDS_ONLY
    _create_lobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, "Friends Game")

# Method 3: Host private game with join code
func start_private_hosting() -> void:
    lobby_visibility_mode = LobbyVisibility.PRIVATE
    _create_lobby(Steam.LOBBY_TYPE_INVISIBLE, "Private Game")

# Method 4: Host Steam Remote Play session
func start_remote_play_hosting() -> void:
    if not is_steam_enabled:
        Logger.warning("Cannot host Remote Play - Steam not available", "SteamManager")
        return
    
    lobby_visibility_mode = LobbyVisibility.REMOTE_PLAY
    is_hosting = true
    
    # Enable Remote Play for this session
    Steam.setRichPresence("status", "Playing Forked Fates")
    Steam.setRichPresence("steam_display", "#StatusWithPlayers") 
    Steam.setRichPresence("connect", "+remote_play")  # Allow Remote Play connections
    
    remote_play_session_started.emit()
    Logger.system("Remote Play session started - friends can join via streaming", "SteamManager")

# Universal lobby creation
func _create_lobby(lobby_type: int, game_name: String) -> void:
    if not is_steam_enabled:
        Logger.warning("Cannot host - Steam not available", "SteamManager")
        return
    
    is_hosting = true
    Steam.createLobby(lobby_type, 4)  # Max 4 players
    Logger.system("Creating " + game_name + "...", "SteamManager")

# Method 1: Discover LAN games
func discover_lan_games() -> void:
    if not is_steam_enabled:
        Logger.warning("Cannot discover - Steam not available", "SteamManager")
        return
    
    # Search for public lobbies (LAN discoverable)
    Steam.addRequestLobbyListStringFilter("game_name", "Forked_Fates", Steam.LOBBY_COMPARISON_EQUAL)
    Steam.addRequestLobbyListResultCountFilter(10)  # Max 10 results
    Steam.requestLobbyList()
    Logger.system("Searching for LAN games...", "SteamManager")

# Method 2: Join friend's game (called by Steam when friend invites)
func join_friend_game(lobby_id: int) -> void:
    if not is_steam_enabled:
        Logger.warning("Cannot join friend - Steam not available", "SteamManager")
        return
    
    Steam.joinLobby(lobby_id)
    Logger.system("Joining friend's game: " + str(lobby_id), "SteamManager")

# Method 3: Join using lobby code
func join_session_by_code(lobby_code: String) -> void:
    if not is_steam_enabled:
        Logger.warning("Cannot join - Steam not available", "SteamManager")
        return
    
    # Parse 6-digit code back to lobby ID
    var lobby_id: int = _parse_lobby_code(lobby_code)
    if lobby_id > 0:
        Steam.joinLobby(lobby_id)
        Logger.system("Connecting to session: " + lobby_code, "SteamManager")
    else:
        Logger.error("Invalid lobby code: " + lobby_code, "SteamManager")

# Direct P2P messaging (bypasses lobby chat)
func send_direct_message(peer_id: int, message: Dictionary) -> void:
    var data = var_to_bytes(message)
    Steam.sendP2PPacket(peer_id, data, Steam.P2P_SEND_RELIABLE)

func broadcast_message(message: Dictionary) -> void:
    for peer_id in connected_peers:
        send_direct_message(peer_id, message)

# Steam callbacks - multi-connection support
func _on_lobby_created(result: int, lobby_id: int) -> void:
    if result == 1:  # Success
        current_lobby_id = lobby_id
        
        # Set lobby metadata for discovery
        Steam.setLobbyData(lobby_id, "game_name", "Forked_Fates")
        Steam.setLobbyData(lobby_id, "version", "1.0")  # TODO: Use actual game version
        Steam.setLobbyData(lobby_id, "host_name", Steam.getPersonaName())
        
        # Set Steam rich presence for friends
        Steam.setRichPresence("status", "Hosting Forked Fates")
        Steam.setRichPresence("steam_display", "#StatusWithPlayers")
        Steam.setRichPresence("players", "1")  # Update as players join
        
        # Emit appropriate signals based on visibility mode
        match lobby_visibility_mode:
            LobbyVisibility.LAN_DISCOVERABLE:
                Logger.system("LAN game created - discoverable to local players", "SteamManager")
            LobbyVisibility.FRIENDS_ONLY:
                Logger.system("Friends game created - visible to Steam friends", "SteamManager")
            LobbyVisibility.PRIVATE:
                var lobby_code = _generate_lobby_code(lobby_id)
                lobby_code_generated.emit(lobby_code)
                Logger.system("Private game created - Code: " + lobby_code, "SteamManager")
            LobbyVisibility.REMOTE_PLAY:
                Logger.system("Remote Play session ready - friends can join via streaming", "SteamManager")
        
        lobby_created.emit(lobby_id, lobby_visibility_mode)
    else:
        Logger.error("Failed to create lobby. Result: " + str(result), "SteamManager")

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
    if response == 1:  # Success
        current_lobby_id = lobby_id
        var host_id = Steam.getLobbyOwner(lobby_id)
        
        # Establish direct P2P with host
        Steam.acceptP2PSessionWithUser(host_id)
        connected_peers.append(host_id)
        connection_established.emit(host_id)
        Logger.system("Connected to host via P2P", "SteamManager")
    else:
        Logger.error("Failed to join session", "SteamManager")

func _on_p2p_session_request(remote_id: int) -> void:
    # Accept all P2P requests (we trust lobby members)
    Steam.acceptP2PSessionWithUser(remote_id)
    connected_peers.append(remote_id)
    connection_established.emit(remote_id)
    Logger.system("P2P connection established with: " + str(remote_id), "SteamManager")

func _on_p2p_session_connect_fail(steam_id: int, session_error: int) -> void:
    connected_peers.erase(steam_id)
    connection_lost.emit(steam_id)
    Logger.error("P2P connection failed: " + str(steam_id), "SteamManager")

# LAN Discovery callback
func _on_lobby_match_list(lobbies: Array) -> void:
    var lan_games: Array = []
    
    for lobby_id in lobbies:
        var lobby_info = {
            "lobby_id": lobby_id,
            "host_name": Steam.getLobbyData(lobby_id, "host_name"),
            "players": Steam.getNumLobbyMembers(lobby_id),
            "max_players": Steam.getLobbyMemberLimit(lobby_id)
        }
        lan_games.append(lobby_info)
    
    lan_lobbies_discovered.emit(lan_games)
    Logger.system("Found " + str(lan_games.size()) + " LAN games", "SteamManager")

# Friend invite callback (when friend clicks "Join Game" in Steam)
func _on_join_requested(lobby_id: int, friend_id: int) -> void:
    Logger.system("Friend invite from: " + str(friend_id) + " to lobby: " + str(lobby_id), "SteamManager")
    # Auto-join friend's game
    join_friend_game(lobby_id)

# Steam Remote Play callbacks
func _on_remote_play_connected(session_id: int) -> void:
    var player_name = "Remote Player " + str(session_id)  # TODO: Get actual player name if available
    remote_play_player_connected.emit(session_id, player_name)
    Logger.system("Remote Play player connected: " + player_name, "SteamManager")

func _on_remote_play_disconnected(session_id: int) -> void:
    remote_play_player_disconnected.emit(session_id)
    Logger.system("Remote Play player disconnected: " + str(session_id), "SteamManager")

# Generate user-friendly 6-digit codes from lobby IDs
func _generate_lobby_code(lobby_id: int) -> String:
    # Use last 6 digits of lobby ID, pad with zeros if needed
    var code = str(lobby_id % 1000000)
    return code.pad_zeros(6)

func _parse_lobby_code(code: String) -> int:
    # This is simplified - in reality you'd need a more robust mapping system
    # Could store code->lobby_id mapping on a simple backend or use Steam's lobby search
    if code.length() == 6 and code.is_valid_int():
        return code.to_int()
    return 0

# P2P message receiving
func _process(_delta: float) -> void:
    if is_steam_enabled:
        _read_p2p_packets()

func _read_p2p_packets() -> void:
    var packet_size = Steam.getAvailableP2PPacketSize(0)
    while packet_size > 0:
        var packet = Steam.readP2PPacket(packet_size, 0)
        if packet.size() > 0:
            var sender_id = packet["remote_steam_id"]
            var message_data = bytes_to_var(packet["data"])
            direct_message_received.emit(sender_id, message_data)
        
        packet_size = Steam.getAvailableP2PPacketSize(0)
```

### **1.2 Multi-Connection UI Integration**

```gdscript
# scripts/ui/direct_connect.gd - Enhanced for multi-connection Steam P2P

extends Control

# UI References - Host Tab
@onready var host_lan_button: Button = $TabContainer/Host/VBoxContainer/HostLANButton
@onready var host_friends_button: Button = $TabContainer/Host/VBoxContainer/HostFriendsButton  
@onready var host_private_button: Button = $TabContainer/Host/VBoxContainer/HostPrivateButton
@onready var host_remote_play_button: Button = $TabContainer/Host/VBoxContainer/HostRemotePlayButton
@onready var code_display: Label = $TabContainer/Host/VBoxContainer/CodeDisplay

# UI References - Join Tab
@onready var lan_games_list: ItemList = $TabContainer/Join/VBoxContainer/LANGamesList
@onready var refresh_lan_button: Button = $TabContainer/Join/VBoxContainer/RefreshLANButton
@onready var code_input: LineEdit = $TabContainer/Join/VBoxContainer/CodeInput
@onready var join_code_button: Button = $TabContainer/Join/VBoxContainer/JoinCodeButton

# UI References - Status
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
    # Host tab connections
    host_lan_button.pressed.connect(_on_host_lan_pressed)
    host_friends_button.pressed.connect(_on_host_friends_pressed)
    host_private_button.pressed.connect(_on_host_private_pressed)
    host_remote_play_button.pressed.connect(_on_host_remote_play_pressed)
    
    # Join tab connections  
    refresh_lan_button.pressed.connect(_on_refresh_lan_pressed)
    join_code_button.pressed.connect(_on_join_code_pressed)
    lan_games_list.item_selected.connect(_on_lan_game_selected)
    
    # Connect to Steam P2P events
    SteamManager.lobby_created.connect(_on_lobby_created)
    SteamManager.lobby_code_generated.connect(_on_lobby_code_generated)
    SteamManager.lan_lobbies_discovered.connect(_on_lan_lobbies_discovered)
    SteamManager.connection_established.connect(_on_connection_established)
    SteamManager.connection_lost.connect(_on_connection_lost)
    
    # Connect to Steam Remote Play events
    SteamManager.remote_play_session_started.connect(_on_remote_play_session_started)
    SteamManager.remote_play_player_connected.connect(_on_remote_play_player_connected)
    SteamManager.remote_play_player_disconnected.connect(_on_remote_play_player_disconnected)
    
    _update_ui_state()

# Host Methods
func _on_host_lan_pressed() -> void:
    status_label.text = "Creating LAN game..."
    _disable_host_buttons()
    SteamManager.start_lan_hosting()

func _on_host_friends_pressed() -> void:
    status_label.text = "Creating friends game..."
    _disable_host_buttons()
    SteamManager.start_friends_hosting()

func _on_host_private_pressed() -> void:
    status_label.text = "Creating private game..."
    _disable_host_buttons()
    SteamManager.start_private_hosting()

func _on_host_remote_play_pressed() -> void:
    status_label.text = "Starting Remote Play session..."
    _disable_host_buttons()
    SteamManager.start_remote_play_hosting()

# Join Methods
func _on_refresh_lan_pressed() -> void:
    status_label.text = "Searching for LAN games..."
    lan_games_list.clear()
    SteamManager.discover_lan_games()

func _on_join_code_pressed() -> void:
    var code = code_input.text.strip_edges()
    if code.length() != 6:
        status_label.text = "Error: Enter 6-digit code"
        return
    
    status_label.text = "Connecting via code..."
    join_code_button.disabled = true
    SteamManager.join_session_by_code(code)

func _on_lan_game_selected(index: int) -> void:
    var selected_item = lan_games_list.get_item_metadata(index)
    if selected_item:
        var lobby_id = selected_item.get("lobby_id", 0)
        status_label.text = "Joining LAN game..."
        SteamManager.join_friend_game(lobby_id)  # Same method works for LAN

# Event Callbacks
func _on_lobby_created(lobby_id: int, visibility: SteamManager.LobbyVisibility) -> void:
    match visibility:
        SteamManager.LobbyVisibility.LAN_DISCOVERABLE:
            status_label.text = "LAN game ready - players can discover automatically"
        SteamManager.LobbyVisibility.FRIENDS_ONLY:
            status_label.text = "Friends game ready - visible to Steam friends"
        SteamManager.LobbyVisibility.PRIVATE:
            status_label.text = "Private game ready - waiting for join code generation"
        SteamManager.LobbyVisibility.REMOTE_PLAY:
            status_label.text = "Remote Play ready - friends can join via streaming"

func _on_lobby_code_generated(code: String) -> void:
    code_display.text = "Share this code: " + code
    status_label.text = "Private game ready - share code with players"
    
    # TODO: Auto-copy to clipboard for easy sharing
    # DisplayServer.clipboard_set(code)

func _on_lan_lobbies_discovered(lobbies: Array) -> void:
    lan_games_list.clear()
    
    if lobbies.is_empty():
        status_label.text = "No LAN games found"
        return
    
    for lobby_info in lobbies:
        var display_text = "%s (%d/%d players)" % [
            lobby_info.get("host_name", "Unknown"),
            lobby_info.get("players", 0),
            lobby_info.get("max_players", 4)
        ]
        var index = lan_games_list.add_item(display_text)
        lan_games_list.set_item_metadata(index, lobby_info)
    
    status_label.text = "Found " + str(lobbies.size()) + " LAN games"

func _on_connection_established(peer_id: int) -> void:
    status_label.text = "Connected! Starting game..."
    
    # Start the actual game session
    GameManager.network_enabled = true
    GameManager.is_host = SteamManager.is_hosting
    
    # TODO: Transition to game lobby or start minigame selection
    Logger.system("P2P session established - starting game", "DirectConnect")

func _on_connection_lost(peer_id: int) -> void:
    status_label.text = "Connection lost"
    _update_ui_state()

# Remote Play Event Callbacks
func _on_remote_play_session_started() -> void:
    status_label.text = "Remote Play session active - friends can join via Steam"

func _on_remote_play_player_connected(session_id: int, player_name: String) -> void:
    status_label.text = player_name + " joined via Remote Play"
    
    # Start the actual game session (Remote Play uses local multiplayer)
    GameManager.network_enabled = false  # Remote Play doesn't need network sync
    GameManager.is_host = true           # Host always controls Remote Play
    
    # TODO: Add Remote Play player to local multiplayer session
    Logger.system("Remote Play player connected: " + player_name, "DirectConnect")

func _on_remote_play_player_disconnected(session_id: int) -> void:
    status_label.text = "Remote Play player disconnected"
    # TODO: Remove Remote Play player from local multiplayer session

# UI Helper Methods
func _disable_host_buttons() -> void:
    host_lan_button.disabled = true
    host_friends_button.disabled = true
    host_private_button.disabled = true
    host_remote_play_button.disabled = true

func _update_ui_state() -> void:
    # Reset host buttons
    host_lan_button.disabled = false
    host_friends_button.disabled = false
    host_private_button.disabled = false
    host_remote_play_button.disabled = false
    
    # Reset join buttons
    join_code_button.disabled = false
    
    # Reset displays
    code_display.text = ""
    status_label.text = "Ready"
```

### **1.3 GameManager Integration - Direct P2P**

```gdscript
# Add to autoloads/game_manager.gd

# Direct P2P networking state
var connected_players: Dictionary = {}  # steam_id -> PlayerData
var local_steam_id: int = 0

func _ready() -> void:
    # ... existing initialization ...
    
    # Connect to Steam P2P events
    SteamManager.connection_established.connect(_on_p2p_connection_established)
    SteamManager.connection_lost.connect(_on_p2p_connection_lost)
    SteamManager.direct_message_received.connect(_on_direct_message_received)

func _on_p2p_connection_established(peer_id: int) -> void:
    local_steam_id = Steam.getSteamID()
    
    if is_host:
        # Host: Send game state to new peer
        _send_game_state_to_peer(peer_id)
    else:
        # Client: Request game state from host
        _request_game_state(peer_id)
    
    Logger.system("P2P connection established with: " + str(peer_id), "GameManager")

func _on_p2p_connection_lost(peer_id: int) -> void:
    # Remove player from game
    if peer_id in connected_players:
        var player_data = connected_players[peer_id]
        connected_players.erase(peer_id)
        EventBus.network_player_disconnected.emit(peer_id)
        Logger.system("Player disconnected: " + player_data.player_name, "GameManager")

func _on_direct_message_received(peer_id: int, message: Dictionary) -> void:
    var msg_type = message.get("type", "")
    match msg_type:
        "player_data":
            _handle_player_data_message(peer_id, message)
        "game_event":
            _handle_game_event_message(peer_id, message)
        "state_request":
            if is_host:
                _send_game_state_to_peer(peer_id)

func _send_game_state_to_peer(peer_id: int) -> void:
    var game_state = {
        "type": "game_state",
        "players": _serialize_all_players(),
        "current_minigame": current_minigame_type,
        "game_phase": "lobby"  # TODO: Add proper game phase tracking
    }
    SteamManager.send_direct_message(peer_id, game_state)

func _request_game_state(host_id: int) -> void:
    var request = {"type": "state_request"}
    SteamManager.send_direct_message(host_id, request)

func _serialize_all_players() -> Array:
    # TODO: Serialize current player states for network sync
    return []

# Network event forwarding to EventBus
func _handle_game_event_message(peer_id: int, message: Dictionary) -> void:
    var event_type = message.get("event", "")
    match event_type:
        "player_damage":
            EventBus.player_damage_reported.emit(
                message.get("victim_id", -1),
                message.get("attacker_id", -1),
                message.get("damage", 0),
                message.get("weapon", "")
            )
        "player_died":
            EventBus.player_died.emit(message.get("player_id", -1))
```

## 🔧 **Phase 2: Game State Synchronization**

### **2.1 Direct P2P Event Synchronization**

```gdscript
# autoloads/network_sync.gd - New lightweight sync system
extends Node

var sync_rate: float = 1.0 / 20.0  # 20 FPS
var last_sync_time: float = 0.0

func _ready() -> void:
    # Connect to game events for network forwarding
    EventBus.player_damage_reported.connect(_on_player_damage_reported)
    EventBus.player_died.connect(_on_player_died)
    EventBus.minigame_started.connect(_on_minigame_started)

func _process(delta: float) -> void:
    if GameManager.network_enabled and GameManager.is_host:
        last_sync_time += delta
        if last_sync_time >= sync_rate:
            _send_periodic_sync()
            last_sync_time = 0.0

# Forward local events to network peers
func _on_player_damage_reported(victim_id: int, attacker_id: int, damage: int, weapon: String) -> void:
    if GameManager.network_enabled:
        var message = {
            "type": "game_event",
            "event": "player_damage",
            "victim_id": victim_id,
            "attacker_id": attacker_id,
            "damage": damage,
            "weapon": weapon
        }
        SteamManager.broadcast_message(message)

func _on_player_died(player_id: int) -> void:
    if GameManager.network_enabled:
        var message = {
            "type": "game_event", 
            "event": "player_died",
            "player_id": player_id
        }
        SteamManager.broadcast_message(message)

func _on_minigame_started(minigame_type: String) -> void:
    if GameManager.network_enabled and GameManager.is_host:
        var message = {
            "type": "game_event",
            "event": "minigame_started", 
            "minigame_type": minigame_type
        }
        SteamManager.broadcast_message(message)

func _send_periodic_sync() -> void:
    # TODO: Send periodic position/state updates
    var sync_data = {
        "type": "sync_update",
        "timestamp": Time.get_unix_time_from_system(),
        "players": _get_all_player_states()
    }
    SteamManager.broadcast_message(sync_data)

func _get_all_player_states() -> Array:
    # TODO: Collect current player positions/states
    return []
```

### **2.2 Player Network Component - Simple P2P Sync**

```gdscript
# scripts/player/components/network_component.gd
class_name NetworkComponent
extends BaseComponent

var is_local_player: bool = false
var network_position: Vector2
var position_sync_rate: float = 1.0 / 20.0
var last_position_sync: float = 0.0

func _component_ready() -> void:
    super._component_ready()
    is_local_player = (player.player_data.player_id == GameManager.local_player_id)
    
    if not is_local_player:
        NetworkSync.connect("sync_update_received", _on_sync_update_received)

func _component_process(delta: float) -> void:
    if GameManager.network_enabled:
        if is_local_player:
            _send_position_update(delta)
        else:
            _interpolate_network_position(delta)

func _send_position_update(delta: float) -> void:
    last_position_sync += delta
    if last_position_sync >= position_sync_rate:
        var message = {
            "type": "player_update",
            "player_id": player.player_data.player_id,
            "position": player.global_position,
            "velocity": player.velocity
        }
        SteamManager.broadcast_message(message)
        last_position_sync = 0.0

func _interpolate_network_position(delta: float) -> void:
    if network_position != Vector2.ZERO:
        player.global_position = player.global_position.lerp(network_position, 10.0 * delta)

func _on_sync_update_received(sync_data: Dictionary) -> void:
    if not is_local_player:
        var players = sync_data.get("players", [])
        for player_data in players:
            if player_data.get("player_id") == player.player_data.player_id:
                network_position = Vector2(player_data.get("position", Vector2.ZERO))
```

## 🔧 **Phase 3: Polish & Robustness**

### **3.1 Connection Recovery**

```gdscript
# Add to steam_manager.gd

var reconnect_attempts: int = 0
var max_reconnect_attempts: int = 3
var reconnect_delay: float = 2.0

func _handle_connection_lost(peer_id: int) -> void:
    Logger.warning("Connection lost to peer: " + str(peer_id), "SteamManager")
    
    if reconnect_attempts < max_reconnect_attempts:
        Logger.system("Attempting reconnection...", "SteamManager")
        reconnect_attempts += 1
        await get_tree().create_timer(reconnect_delay).timeout
        _attempt_reconnect(peer_id)
    else:
        Logger.error("Max reconnection attempts reached", "SteamManager")
        EventBus.network_session_failed.emit("Connection lost")

func _attempt_reconnect(peer_id: int) -> void:
    # Try to re-establish P2P connection
    Steam.acceptP2PSessionWithUser(peer_id)
```

### **3.2 Network Debug Panel**

```gdscript
# scripts/ui/network_debug.gd - Simple debug overlay
extends Control

@onready var status_label: Label = $VBox/StatusLabel
@onready var peers_label: Label = $VBox/PeersLabel
@onready var messages_label: Label = $VBox/MessagesLabel

var message_count: int = 0

func _ready() -> void:
    SteamManager.direct_message_received.connect(_on_message_received)

func _process(_delta: float) -> void:
    if GameManager.network_enabled:
        status_label.text = "Network: " + ("Host" if GameManager.is_host else "Client")
        peers_label.text = "Peers: " + str(SteamManager.connected_peers.size())
    else:
        status_label.text = "Network: Offline"
        peers_label.text = "Peers: 0"

func _on_message_received(_peer_id: int, _message: Dictionary) -> void:
    message_count += 1
    messages_label.text = "Messages: " + str(message_count)
```

## 🎯 **Key Benefits of Steam P2P Multi-Connection System**

### **Advantages Over Traditional IP Networking**
1. **No Port Forwarding**: Steam handles NAT traversal automatically for all connection types
2. **Better Security**: Steam authentication prevents unauthorized connections  
3. **Reliable Connections**: Steam's infrastructure handles connection reliability
4. **Cross-Platform**: Works on Windows, Mac, Linux without platform-specific code
5. **Multiple Discovery Options**: LAN, friends, and codes provide flexible connection methods

### **Connection Method Benefits**

#### **LAN Discovery** - Best for Local Play
- **Automatic Discovery**: No manual setup, games appear instantly on local network
- **Zero Configuration**: No codes, IPs, or friend requirements
- **Perfect for Events**: LAN parties, tournaments, local multiplayer sessions
- **Fast Connection**: Local network speed, minimal latency

#### **Friend Discovery** - Best for Online Friends  
- **Seamless Integration**: Uses existing Steam friends list
- **Rich Presence**: Friends see you're playing and can join instantly
- **Social Gaming**: Leverages established Steam social connections  
- **One-Click Join**: Friends right-click and join, no codes needed

#### **Join Codes** - Best for Universal Access
- **Universal Access**: Works with anyone, regardless of Steam friendship
- **Private Gaming**: Share codes only with intended players
- **Cross-Platform Sharing**: Share codes via Discord, text, email, etc.
- **Controlled Access**: Host decides who gets the code

#### **Steam Remote Play** - Best for Accessibility
- **No Game Ownership**: Remote players don't need to own the game
- **Instant Access**: Friends can join immediately via Steam streaming
- **Local Multiplayer Online**: Play local co-op games over the internet
- **Low Barrier**: No setup, downloads, or purchases required for joiners

### **Integration with Existing Architecture** ✅
- **EventBus**: Perfect for network event forwarding
- **GameManager**: Already has networking flags and player management
- **Component System**: Easy to add NetworkComponent to players
- **Direct Connect UI**: Already converted to Steam in codebase

## 🚀 **Implementation Priority**

### **Start Here** (Immediate Implementation)
1. **SteamManager**: Basic P2P connection and lobby code generation
2. **Direct Connect UI**: Enhanced with code generation/entry
3. **GameManager Integration**: Basic P2P session management

### **Then Add** (Core Functionality)  
1. **NetworkSync**: Event forwarding via EventBus
2. **NetworkComponent**: Player position synchronization
3. **Basic Testing**: Two-player testing with debug panel

### **Polish Later** (Enhanced Features)
1. **Connection Recovery**: Automatic reconnection attempts
2. **Performance Optimization**: Reduce network traffic
3. **Advanced Debugging**: Network performance monitoring

## 🎮 **Multi-Connection Implementation Flows**

### **LAN Discovery Flow**
```gdscript
# Host flow:
# 1. Player 1 clicks "Host LAN Game"
# 2. Steam creates public lobby with game metadata
# 3. Game appears in local network discovery

# Join flow:  
# 1. Player 2 clicks "Refresh LAN Games"
# 2. Steam searches for public lobbies with "Forked_Fates" metadata
# 3. Player 2 sees "Player1's Game (1/4 players)" in list
# 4. Player 2 clicks game → Auto P2P connection
# 5. Game starts immediately
```

### **Friend Discovery Flow**  
```gdscript
# Host flow:
# 1. Player 1 clicks "Host Friends Game"
# 2. Steam creates friends-only lobby + sets rich presence
# 3. Steam shows "Player1 is playing Forked Fates" to friends

# Join flow:
# 1. Player 2 (Steam friend) sees game status in friends list
# 2. Player 2 right-clicks friend → "Join Game" 
# 3. Steam auto-joins lobby → P2P connection
# 4. Game starts seamlessly
```

### **Join Code Flow**
```gdscript
# Host flow:
# 1. Player 1 clicks "Host Private Game"
# 2. Steam creates invisible lobby
# 3. Player 1 gets code "485720"
# 4. Player 1 shares code via Discord/text/etc.

# Join flow:
# 1. Player 2 enters code "485720" 
# 2. Code parsed to lobby ID → Steam joins lobby
# 3. P2P connection established
# 4. Game starts with privacy
```

### **Steam Remote Play Flow**
```gdscript
# Host flow:
# 1. Player 1 clicks "Host Remote Play"
# 2. Steam sets rich presence with Remote Play availability
# 3. Game shows as "Available for Remote Play" to Steam friends
# 4. Game runs in local multiplayer mode

# Join flow:
# 1. Player 2 (Steam friend) sees "Remote Play Available" status
# 2. Player 2 clicks "Request Remote Play" in Steam friends list
# 3. Steam starts streaming host's game to Player 2
# 4. Player 2 plays via streaming (no download/purchase needed)
# 5. Local multiplayer handles multiple players automatically
```

### **Unified Technical Flow** (All Methods)

#### **P2P Methods** (LAN, Friends, Join Codes)
```gdscript
# 1. Steam creates lobby (public/friends/invisible based on method)
# 2. Lobby metadata set for discovery (LAN) or rich presence (friends)
# 3. Players connect via their chosen method
# 4. P2P connections established between all players
# 5. Game events forwarded via P2P messages
# 6. EventBus re-emits network events locally
# 7. All P2P methods use same underlying networking code
```

#### **Remote Play Method** (Streaming)
```gdscript
# 1. Steam sets rich presence with Remote Play availability
# 2. Host runs game in local multiplayer mode (no P2P needed)
# 3. Remote players connect via Steam streaming infrastructure
# 4. Remote players' input streamed to host, video/audio streamed back
# 5. Game treats remote players as local controllers
# 6. No EventBus networking needed - everything is local on host
```

**This approach provides maximum flexibility with four connection methods - three using Steam P2P networking for true multiplayer, plus Steam Remote Play for streaming-based accessibility without requiring game ownership!** 🎯 