# Forked Fates - Agent Context

## Commands
- **Run Game**: `/Applications/Godot.app/Contents/MacOS/Godot --path .` 
- **Test with temp scene**: `/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_ui_test.tscn --headless`
- **Headless test**: `/Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 3`
- No formal test framework - use temporary test scenes and clean up after

## Architecture
**Godot 4.4** multiplayer party game with component-based architecture. Core systems:
- **Player System**: Component-based with MovementComponent, HealthComponent, ItemComponent, InputComponent, RagdollComponent, ObjectIndicatorManager
- **Minigame Framework**: BaseMinigame → PhysicsMinigame/UIMinigame/TurnBasedMinigame with automatic UI cleanup
- **Factory Pattern**: PlayerFactory, ItemFactory, MinigameFactory, UIFactory for all object creation
- **ID-Based Architecture**: Use `player_id: int` + `PlayerManager.get_player(id)` to avoid circular dependencies
- **Configuration System**: Lazy-loaded .tres configs via ConfigManager (PlayerConfig, ItemConfig, MinigameConfig)
- **Autoloads**: EventBus, GameManager, SteamManager, UIManager, PoolManager, ConfigManager, PlayerManager

## Code Style (from .cursorrules)
- **Typing**: Strict typing required (`var name: String`, function parameters typed)
- **Naming**: snake_case files/variables/functions, PascalCase classes/nodes, ALL_CAPS constants
- **Signals**: snake_case past tense (`health_depleted`, `enemy_defeated`)
- **Modern Godot 4.x**: Use `super.method()` not `super().method()`, @onready instead of direct node refs
- **Components**: Extend BaseComponent, implement lifecycle methods (_component_ready, _component_process)

## Key Patterns
- **Weapon System**: Configuration-driven via ItemConfig .tres files, event-based positioning via EventBus
- **UI Creation**: Always use UIFactory.create_ui_element() + UIManager for screens/overlays, never manual Label.new()
- **Object Pooling**: PoolManager.get_item("bullet") for frequently spawned objects, mark with is_pooled = true
- **Signal Safety**: Check `if not signal.is_connected(method):` before connecting (important for pooled objects)
- **Damage System**: Unified `take_damage(damage, source, attacker_id, source_name)` for all damage sources
- **ExtResource IDs**: Use descriptive names like "pistol_scene" not numeric "2_scene" in .tres files
