# Tutorial System Refactor Implementation Plan

**Status**: Not Yet Implemented  
**Priority**: Medium-High  
**Estimated Effort**: 4-5 development sessions  
**Dependencies**: BaseMinigame, UI System, Animation System, GameSettings

## System Overview

Mario Party-style tutorial system with full-screen visual demonstrations, animated gameplay examples, and interactive voting mechanics. Replaces current text-only tutorial system with rich multimedia presentation.

## Current State Analysis

### Existing Tutorial System
```gdscript
# BaseMinigame - Basic tutorial properties
@export var tutorial_rules: Array[String] = []
@export var tutorial_controls: Dictionary = {}
@export var tutorial_objective: String = ""
@export var tutorial_tips: Array[String] = []
@export var tutorial_duration: float = 5.0

# TutorialUI - Simple text display
func show_tutorial(minigame: BaseMinigame) -> void
func _setup_tutorial_content(tutorial_data: Dictionary) -> void
```

### Limitations to Address
- ❌ **Text-only presentation** - No visual demonstration
- ❌ **Small UI space** - Doesn't occupy full screen
- ❌ **Static content** - No animation or interaction
- ❌ **No voting system** - Can't skip based on player preference
- ❌ **No history tracking** - Doesn't remember seen tutorials

## New Tutorial Architecture

### 1. Enhanced Tutorial System Core
```gdscript
# autoloads/tutorial_manager.gd
class_name TutorialManager extends Node

enum TutorialState {
    HIDDEN,
    PRESENTING,
    VOTING,
    COUNTDOWN,
    SKIPPED
}

var current_tutorial_state: TutorialState = TutorialState.HIDDEN
var seen_tutorials: Dictionary = {}  # minigame_id -> times_seen
var tutorial_settings: TutorialSettings
var active_tutorial: TutorialPresentation = null

func show_tutorial(minigame: BaseMinigame) -> void
func handle_skip_vote(player_id: int) -> void  
func check_auto_skip(minigame_id: String) -> bool
func mark_tutorial_seen(minigame_id: String) -> void
```

### 2. Visual Tutorial Presentation System
```gdscript
# scripts/tutorials/tutorial_presentation.gd
class_name TutorialPresentation extends Control

# Full-screen tutorial components
@onready var background_video: VideoStreamPlayer = $BackgroundVideo
@onready var gameplay_demo: AnimationPlayer = $GameplayDemo
@onready var instruction_overlay: TutorialInstructionOverlay = $InstructionOverlay
@onready var timer_bar: TutorialTimerBar = $TimerBar
@onready var voting_panel: TutorialVotingPanel = $VotingPanel

# Tutorial content data
var tutorial_data: TutorialData
var animation_sequence: TutorialAnimationSequence
var presentation_timer: float = 0.0
var auto_advance: bool = true
```

### 3. Tutorial Content Definition System
```gdscript
# scripts/tutorials/tutorial_data.gd
class_name TutorialData extends Resource

@export var minigame_id: String = ""
@export var title: String = ""
@export var background_video_path: String = ""  # Gameplay background loop
@export var demonstration_scenes: Array[DemonstrationScene] = []
@export var instruction_blocks: Array[InstructionBlock] = []
@export var estimated_duration: float = 15.0
@export var skippable_after: float = 3.0  # Minimum time before skip voting
@export var requires_player_readiness: bool = false

# Visual demonstration components
class DemonstrationScene extends Resource:
    @export var scene_name: String = ""
    @export var animation_path: String = ""
    @export var duration: float = 3.0
    @export var instruction_text: String = ""
    @export var highlight_areas: Array[Rect2] = []  # UI highlight regions
    @export var player_avatars: Array[Vector2] = []  # Show player positions
    @export var item_demonstrations: Array[String] = []  # Show item usage

class InstructionBlock extends Resource:
    @export var title: String = ""
    @export var description: String = ""
    @export var control_hints: Dictionary = {}  # Action -> key binding
    @export var tips: Array[String] = []
    @export var display_time: float = 2.0
    @export var fade_transition: bool = true
```

## Tutorial Presentation Flow

### Phase 1: Tutorial Detection & Auto-Skip Check
```gdscript
func show_tutorial(minigame: BaseMinigame) -> void:
    var tutorial_data = _load_tutorial_data(minigame.minigame_name)
    
    # Check auto-skip conditions
    if _should_auto_skip(tutorial_data):
        _skip_to_minigame()
        return
    
    # Initialize full-screen presentation
    _begin_tutorial_presentation(tutorial_data)
```

### Phase 2: Visual Demonstration Sequence
```gdscript
# 1. Background Setup
# - Load gameplay video loop or animated background
# - Set up simulated game environment overlay

# 2. Animated Demonstrations
# - Show player movement with animated avatars
# - Demonstrate item usage with visual effects
# - Highlight UI elements and controls
# - Show win/lose conditions with examples

# 3. Interactive Elements
# - Animated arrows pointing to important areas
# - Pulsing highlights on key UI elements
# - Mock gameplay scenarios with predictable outcomes
```

### Phase 3: Timer System & Voting Integration
- **Timer Bar Display** with visual feedback for remaining time
- **Skip Voting Integration** using universal voting system (see `voting_system.md`)
- **Player Input Collection** with clear voting interface
- **Automatic Advancement** when timer expires or vote completes

## Enhanced Tutorial Content Examples

### Physics Minigame Tutorials
- **Player Movement Demonstration** with animated avatars and control overlays
- **Interaction System Showcase** showing item pickup and usage mechanics
- **Combat Mechanics Display** demonstrating weapon systems and effects
- **Physics Demonstration** showing unique physics behaviors
- **Victory Condition Explanation** with clear success criteria visualization

### UI Minigame Tutorials
- **Interface Overview** showing game UI elements and layout
- **Interaction Demonstration** with sample gameplay sequences
- **Feedback System Display** showing success and failure indicators
- **Scoring Mechanics** with point accumulation and leaderboard systems
- **Win Condition Presentation** explaining victory requirements

## Settings Integration

### Tutorial Preferences
- **Auto-skip settings** for familiar content based on view history
- **Skip threshold configuration** determining when tutorials become skippable
- **Tutorial speed controls** allowing faster or slower presentation
- **Voting requirement settings** for unanimous vs majority skip decisions
- **Minimum viewing duration** to ensure adequate tutorial exposure
- **Tutorial history tracking** for persistent skip decision data

### Auto-Skip Logic Framework
- **Settings-based skip determination** using configurable thresholds
- **View count tracking** for tutorial familiarity assessment
- **Automatic settings persistence** for consistent user experience
- **Integration with voting system** for group skip decisions

## Implementation Phases

### Phase 1: Core Tutorial System
1. Create TutorialManager autoload
2. Design TutorialData resource structure  
3. Implement TutorialPresentation base class
4. Add tutorial settings to GameSettings
5. Create tutorial state management

### Phase 2: Visual Components
1. Implement TutorialTimerBar with smooth animations
2. Create TutorialVotingPanel with player vote tracking
3. Design TutorialInstructionOverlay for text content
4. Implement demonstration animation system
5. Add visual effect components (highlights, arrows, etc.)

### Phase 3: Content Creation Tools
1. Create tutorial content editor (future dev tool)
2. Implement animation recording system  
3. Add demonstration scene composer
4. Create preview and testing utilities
5. Build content validation system

### Phase 4: Integration & Polish
1. Integrate with existing minigame lifecycle
2. Add localization support for tutorial content
3. Implement accessibility features (colorblind support)
4. Add performance optimization for animations
5. Create comprehensive tutorial content for all minigames

## File Structure

```
scripts/
├── tutorials/
│   ├── tutorial_manager.gd           # Main system controller
│   ├── tutorial_presentation.gd      # Full-screen presentation
│   ├── tutorial_data.gd              # Content data structures
│   ├── tutorial_animation_sequence.gd # Animation management
│   ├── components/
│   │   ├── tutorial_timer_bar.gd     # Timer display
│   │   ├── tutorial_voting_panel.gd  # Skip voting UI
│   │   ├── tutorial_instruction_overlay.gd # Text overlays
│   │   └── tutorial_demonstration_area.gd  # Gameplay demo
│   └── effects/
│       ├── highlight_effect.gd       # UI highlighting
│       ├── arrow_pointer.gd          # Directional indicators
│       └── player_avatar_demo.gd     # Animated demonstrations

resources/
├── tutorials/
│   ├── sudden_death_tutorial.tres    # Sudden Death content
│   ├── ui_minigame_tutorial.tres     # UI game template
│   └── turn_based_tutorial.tres      # Turn-based template

scenes/
├── tutorials/
│   ├── tutorial_presentation.tscn    # Main presentation scene
│   ├── components/
│   │   ├── timer_bar.tscn           
│   │   ├── voting_panel.tscn        
│   │   └── instruction_overlay.tscn  
│   └── demonstrations/
│       ├── physics_demo.tscn         # Physics gameplay demo
│       ├── ui_demo.tscn              # UI interaction demo
│       └── turn_based_demo.tscn      # Turn-based demo
```

## EventBus Signal Extensions

```gdscript
# New tutorial signals
signal tutorial_started(minigame_id: String)
signal tutorial_skipped(minigame_id: String, reason: String)
signal tutorial_completed(minigame_id: String, duration: float)
signal tutorial_vote_cast(player_id: int, vote_type: String)
signal tutorial_settings_changed(settings: TutorialSettings)
```

## Integration with Existing Systems

### BaseMinigame Integration
```gdscript
# Enhanced BaseMinigame tutorial hooks
func _on_tutorial_shown() -> void:
    # Load and present visual tutorial
    TutorialManager.show_tutorial(self)

func _on_tutorial_finished() -> void:
    # Mark tutorial as seen and increment counter
    TutorialManager.mark_tutorial_seen(minigame_name)
    
    # Proceed to gameplay
    _start_gameplay()
```

### Minigame-Specific Tutorial Content Framework
- **Tutorial data structure** for defining minigame-specific content
- **Background video integration** for immersive presentation context
- **Demonstration scene composition** with multiple animated sequences
- **Instructional text overlays** providing clear gameplay guidance
- **Duration management** for paced tutorial presentation
- **Content validation** ensuring tutorial completeness and accuracy

## Accessibility Integration

Tutorial system designed with comprehensive accessibility support including visual, auditory, motor, and cognitive accessibility features. Full accessibility implementation details available in `accessibility_features.md`.

## Testing Requirements

Tutorial system testing integrated with comprehensive testing framework covering automated validation, performance testing, and quality assurance. Detailed testing strategies and implementation available in `testing_framework.md`.

## Performance Considerations

### Optimization Strategies
- **Preload tutorial content** during minigame loading
- **Pool demonstration objects** to avoid instantiation overhead
- **Cache animation data** to prevent repeated file loading
- **Compress video backgrounds** for faster loading
- **Lazy-load tutorial content** only when needed

### Memory Management
- **Release tutorial resources** immediately after completion
- **Limit concurrent animation objects** to prevent memory bloat
- **Use compressed textures** for demonstration sprites
- **Stream video content** rather than loading entirely into memory

## Notes

- **User Experience**: Mario Party-style presentation creates engaging, memorable tutorials
- **Visual Learning**: Animated demonstrations are more effective than text-only instructions
- **Respect Player Time**: Auto-skip and voting systems prevent repetitive experiences
- **Accessibility First**: Design includes multiple ways to consume tutorial content
- **Performance Conscious**: System designed to minimize impact on game loading times
- **Content Scalable**: Framework supports easy addition of new tutorial content
- **Settings Integration**: Tutorial preferences save automatically and persist across sessions 