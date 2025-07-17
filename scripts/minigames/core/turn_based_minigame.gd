class_name TurnBasedMinigame
extends BaseMinigame

## Base class for turn-based minigames
## Handles turn order, move validation, and discrete game phases
## Example: Strategy games, board games, card games, puzzle games

# Turn-based configuration
@export var turn_time_limit: float = 30.0
@export var max_turns: int = 50
@export var allow_undo: bool = false
@export var randomize_turn_order: bool = true

# Turn management
var current_turn: int = 0
var current_player_id: int = -1
var turn_order: Array[int] = []
var turn_timer: float = 0.0
var moves_history: Array[Dictionary] = []

# Game board/state
@onready var game_board: Control = $GameBoard
@onready var turn_display: Label = $TurnDisplay
@onready var move_timer_label: Label = $MoveTimerLabel

# Turn-based signals
signal turn_started(player_id: int, turn_number: int)
signal turn_ended(player_id: int, move_data: Dictionary)
signal move_made(player_id: int, move_data: Dictionary)
signal turn_timeout(player_id: int)
signal game_phase_changed(new_phase: GamePhase)

enum GamePhase {
	SETUP,
	PLAYING,
	WAITING_FOR_MOVE,
	MOVE_VALIDATION,
	END_GAME
}

var current_phase: GamePhase = GamePhase.SETUP

func _ready() -> void:
	super()
	minigame_name = "Turn-Based Minigame"
	minigame_type = "turn_based"
	minigame_description = "Discrete turn-based gameplay with move validation"
	tags = ["turn_based", "strategy"]
	
	# Default tutorial content for turn-based minigames
	tutorial_objective = "Make strategic moves to defeat your opponents!"
	tutorial_controls = {
		"Select": "Mouse Click",
		"Confirm Move": "Enter / Space",
		"Undo": "Backspace (if allowed)"
	}
	tutorial_tips = [
		"Think ahead and plan your moves",
		"Watch the turn timer",
		"Consider your opponents' strategies"
	]

## Initialize turn-based minigame
func _on_initialize(minigame_context: MinigameContext) -> void:
	Logger.system("Initializing TurnBasedMinigame", "TurnBasedMinigame")
	
	# Disable real-time systems we don't need
	context.disable_system("player_spawner")
	context.disable_system("item_spawner")
	context.disable_system("physics")
	context.disable_system("respawn_manager")
	
	# Setup turn order
	_setup_turn_order()
	
	# Initialize game board
	_setup_game_board()
	
	# Setup UI elements
	_setup_turn_ui()
	
	# Set initial phase
	_change_phase(GamePhase.SETUP)
	
	# Hook for subclass setup
	_on_turn_based_initialize()

## Start turn-based minigame
func _on_start() -> void:
	Logger.game_flow("Starting TurnBasedMinigame", "TurnBasedMinigame")
	
	# Begin first turn
	_change_phase(GamePhase.PLAYING)
	_start_next_turn()
	
	# Hook for subclass start logic
	_on_turn_based_start()

## End turn-based minigame
func _on_end(result: MinigameResult) -> void:
	Logger.game_flow("Ending TurnBasedMinigame", "TurnBasedMinigame")
	
	_change_phase(GamePhase.END_GAME)
	
	# Add turn-based statistics to result
	result.statistics["total_turns"] = current_turn
	result.statistics["moves_made"] = moves_history.size()
	result.statistics["turn_order"] = turn_order.duplicate()
	
	# Hook for subclass cleanup
	_on_turn_based_end(result)

## Process turn timer
func _process(delta: float) -> void:
	if not is_active or is_paused or current_phase != GamePhase.WAITING_FOR_MOVE:
		return
	
	# Update turn timer
	if turn_time_limit > 0 and turn_timer > 0:
		turn_timer -= delta
		_update_timer_display()
		
		# Check for timeout
		if turn_timer <= 0:
			_on_turn_timeout()

## Setup turn order for players
func _setup_turn_order() -> void:
	turn_order = context.get_player_ids()
	
	if randomize_turn_order:
		turn_order.shuffle()
	
	Logger.system("Turn order established: " + str(turn_order), "TurnBasedMinigame")

## Setup game board (virtual - override in subclasses)
func _setup_game_board() -> void:
	Logger.system("Setting up turn-based game board", "TurnBasedMinigame")
	# Hook for subclass board setup
	_on_setup_board()

## Setup turn-based UI elements
func _setup_turn_ui() -> void:
	if turn_display:
		turn_display.visible = true
	
	if move_timer_label and turn_time_limit > 0:
		move_timer_label.visible = true

## Change game phase
func _change_phase(new_phase: GamePhase) -> void:
	var old_phase: GamePhase = current_phase
	current_phase = new_phase
	Logger.system("Phase changed: " + GamePhase.keys()[old_phase] + " -> " + GamePhase.keys()[new_phase], "TurnBasedMinigame")
	game_phase_changed.emit(new_phase)

## Start the next turn
func _start_next_turn() -> void:
	current_turn += 1
	
	# Check for max turns
	if max_turns > 0 and current_turn > max_turns:
		_end_game_max_turns()
		return
	
	# Get next player
	var player_index: int = (current_turn - 1) % turn_order.size()
	current_player_id = turn_order[player_index]
	
	# Start turn timer
	turn_timer = turn_time_limit
	
	# Update display
	_update_turn_display()
	
	# Change to waiting for move phase
	_change_phase(GamePhase.WAITING_FOR_MOVE)
	
	Logger.game_flow("Turn " + str(current_turn) + " started for Player " + str(current_player_id), "TurnBasedMinigame")
	turn_started.emit(current_player_id, current_turn)
	
	# Hook for subclass turn start
	_on_turn_start(current_player_id, current_turn)

## Make a move for the current player
func make_move(player_id: int, move_data: Dictionary) -> bool:
	if current_phase != GamePhase.WAITING_FOR_MOVE:
		Logger.warning("Move attempted outside of move phase", "TurnBasedMinigame")
		return false
	
	if player_id != current_player_id:
		Logger.warning("Move attempted by non-current player: " + str(player_id), "TurnBasedMinigame")
		return false
	
	Logger.system("Move attempted by Player " + str(player_id) + ": " + str(move_data), "TurnBasedMinigame")
	
	# Validate move
	_change_phase(GamePhase.MOVE_VALIDATION)
	var is_valid: bool = _validate_move(player_id, move_data)
	
	if is_valid:
		# Apply the move
		_apply_move(player_id, move_data)
		
		# Record move in history
		var move_record: Dictionary = {
			"player_id": player_id,
			"turn": current_turn,
			"move_data": move_data.duplicate(),
			"timestamp": Time.get_unix_time_from_system()
		}
		moves_history.append(move_record)
		
		# Emit signals
		move_made.emit(player_id, move_data)
		turn_ended.emit(player_id, move_data)
		
		# Check for victory conditions
		var winner_id: int = _check_victory_conditions()
		if winner_id != -1:
			_end_game_victory(winner_id)
			return true
		
		# Start next turn
		_start_next_turn()
		return true
	else:
		# Invalid move, return to waiting phase
		_change_phase(GamePhase.WAITING_FOR_MOVE)
		Logger.warning("Invalid move by Player " + str(player_id), "TurnBasedMinigame")
		return false

## Handle turn timeout
func _on_turn_timeout() -> void:
	Logger.game_flow("Turn timeout for Player " + str(current_player_id), "TurnBasedMinigame")
	turn_timeout.emit(current_player_id)
	
	# Apply default move or skip turn
	var default_move: Dictionary = _get_default_move(current_player_id)
	if not default_move.is_empty():
		make_move(current_player_id, default_move)
	else:
		# Skip turn
		turn_ended.emit(current_player_id, {})
		_start_next_turn()

## Update turn display
func _update_turn_display() -> void:
	if turn_display:
		var player_data: PlayerData = context.get_player_data(current_player_id)
		var player_name: String = player_data.player_name if player_data else "Player " + str(current_player_id)
		turn_display.text = "Turn " + str(current_turn) + ": " + player_name

## Update timer display
func _update_timer_display() -> void:
	if move_timer_label:
		var seconds: int = int(turn_timer)
		move_timer_label.text = "Time: " + str(seconds) + "s"

## End game due to max turns reached
func _end_game_max_turns() -> void:
	Logger.game_flow("Game ended due to max turns reached", "TurnBasedMinigame")
	
	# Determine winner based on score or other criteria
	var winner_data: Dictionary = _determine_winner_by_score()
	var result: MinigameResult
	
	if winner_data.has("winner_id"):
		result = MinigameResult.create_victory_result(
			winner_data.winner_id,
			context.get_player_ids(),
			minigame_name,
			0.0
		)
	else:
		result = MinigameResult.create_draw_result(
			winner_data.get("tied_players", []),
			context.get_player_ids(),
			minigame_name,
			0.0
		)
	
	end_minigame(result)

## End game due to victory condition
func _end_game_victory(winner_id: int) -> void:
	Logger.game_flow("Game ended with victory by Player " + str(winner_id), "TurnBasedMinigame")
	
	var result: MinigameResult = MinigameResult.create_victory_result(
		winner_id,
		context.get_player_ids(),
		minigame_name,
		0.0
	)
	
	end_minigame(result)

## Undo last move (if allowed)
func undo_last_move() -> bool:
	if not allow_undo or moves_history.is_empty():
		return false
	
	var last_move: Dictionary = moves_history.pop_back()
	Logger.system("Undoing move by Player " + str(last_move.player_id), "TurnBasedMinigame")
	
	# Hook for subclass undo implementation
	_on_undo_move(last_move)
	
	return true

# Virtual methods for subclasses to implement turn-based logic

## Called during turn-based initialization
func _on_turn_based_initialize() -> void:
	pass

## Called when turn-based minigame starts
func _on_turn_based_start() -> void:
	pass

## Called when turn-based minigame ends
func _on_turn_based_end(result: MinigameResult) -> void:
	pass

## Called during board setup
func _on_setup_board() -> void:
	pass

## Called when a turn starts
func _on_turn_start(player_id: int, turn_number: int) -> void:
	pass

## Called to validate a move (must be implemented by subclasses)
func _validate_move(player_id: int, move_data: Dictionary) -> bool:
	Logger.warning("_validate_move not implemented in subclass", "TurnBasedMinigame")
	return false

## Called to apply a validated move (must be implemented by subclasses)
func _apply_move(player_id: int, move_data: Dictionary) -> void:
	Logger.warning("_apply_move not implemented in subclass", "TurnBasedMinigame")
	pass

## Called to check victory conditions (must be implemented by subclasses)
func _check_victory_conditions() -> int:
	# Return player_id of winner, or -1 if no winner yet
	return -1

## Called to get default move for timeout (override in subclasses)
func _get_default_move(player_id: int) -> Dictionary:
	return {}

## Called to determine winner by score (override in subclasses)
func _determine_winner_by_score() -> Dictionary:
	return {"tied_players": context.get_player_ids()}

## Called to undo a move (override in subclasses if undo is supported)
func _on_undo_move(move_data: Dictionary) -> void:
	pass 