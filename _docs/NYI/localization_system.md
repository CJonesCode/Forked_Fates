# Localization System Implementation Plan

**Status**: Not Yet Implemented  
**Priority**: Low-Medium  
**Estimated Effort**: 3-4 development sessions  
**Dependencies**: UI System, ConfigManager, GameManager

## System Overview

Comprehensive localization system using Godot's TranslationServer with centralized translation management, hot-reloading, and cultural adaptation support for global accessibility.

## Core Components

### 1. LocalizationManager Autoload
```gdscript
# autoloads/localization_manager.gd
enum SupportedLanguage { EN_US, ES, FR, DE, PT, JA, ZH_CN, RU }
var current_language: SupportedLanguage = SupportedLanguage.EN_US
var fallback_language: SupportedLanguage = SupportedLanguage.EN_US
var translations_loaded: Dictionary = {}  # language -> bool

func set_language(language: SupportedLanguage) -> void
func get_text(key: String, params: Dictionary = {}) -> String
func get_text_with_fallback(key: String, params: Dictionary = {}) -> String
func reload_translations() -> void  # Hot-reload for development
func validate_translations() -> Array[String]  # Missing key detection
```

### 2. Translation Key Management
```gdscript
# Centralized translation keys to prevent typos
class TranslationKeys:
    # UI Navigation
    const MENU_START_GAME = "menu.start_game"
    const MENU_SETTINGS = "menu.settings"
    const MENU_QUIT = "menu.quit"
    
    # Minigame Content
    const MINIGAME_SUDDEN_DEATH_NAME = "minigame.sudden_death.name"
    const MINIGAME_SUDDEN_DEATH_DESC = "minigame.sudden_death.description"
    const MINIGAME_TUTORIAL_OBJECTIVE = "minigame.tutorial.objective"
    
    # Player Feedback
    const PLAYER_HEALTH_LOW = "player.health.low"
    const PLAYER_ELIMINATED = "player.eliminated"
    const VICTORY_MESSAGE = "game.victory.message"
```

### 3. Enhanced UI Integration
```gdscript
# Base class for localizable UI elements
class_name LocalizableLabel extends Label

@export var translation_key: String = ""
@export var translation_params: Dictionary = {}

func _ready() -> void:
    LocalizationManager.language_changed.connect(_update_text)
    _update_text()

func _update_text() -> void:
    if translation_key.is_empty():
        return
    text = LocalizationManager.get_text(translation_key, translation_params)

func set_translation_key(key: String, params: Dictionary = {}) -> void:
    translation_key = key
    translation_params = params
    _update_text()
```

## File Structure and Organization

### Translation Files (.po/.csv format)
```
localization/
├── translations/
│   ├── base.pot              # Template file with all keys
│   ├── en_us.po              # US English (primary)
│   ├── es.po                 # Spanish
│   ├── fr.po                 # French
│   ├── de.po                 # German
│   ├── pt.po                 # Portuguese
│   ├── ja.po                 # Japanese
│   ├── zh_cn.po              # Chinese Simplified
│   └── ru.po                 # Russian
├── fonts/
│   ├── latin_font.ttf        # Western languages
│   ├── cjk_font.ttf          # Chinese/Japanese/Korean
│   └── cyrillic_font.ttf     # Russian/Cyrillic
└── cultural/
    ├── date_formats.json     # Date/time formatting
    ├── number_formats.json   # Number formatting
    └── color_meanings.json   # Cultural color associations
```

### Generated Translation Resources
```gdscript
# Auto-generated .tres files for runtime
res://localization/generated/
├── translation_en_us.tres
├── translation_es.tres
└── ...
```

## Implementation Phases

### Phase 1: Core Infrastructure
1. Create LocalizationManager autoload
2. Set up TranslationServer integration
3. Implement basic translation key system
4. Create US English base translations
5. Add language switching functionality

### Phase 2: UI Integration
1. Create LocalizableLabel/Button base classes
2. Update existing UI scenes with translation keys
3. Implement parameter substitution system
4. Add font switching for different character sets
5. Create translation validation tools

### Phase 3: Content Localization
1. Extract all hardcoded strings to translation files
2. Localize minigame content (names, descriptions, tutorials)
3. Localize player feedback messages
4. Implement pluralization support
5. Add context information for translators

### Phase 4: Advanced Features
1. Add pseudolocalization for testing text expansion
2. Implement right-to-left language support
3. Create localization asset pipeline
4. Add cultural adaptation features
5. Implement translation memory system

## Translation Best Practices

### Key Naming Convention
```
category.subcategory.specific_element
ui.menu.start_game
minigame.sudden_death.tutorial.objective
player.status.health_critical
notification.item.pickup_success
```

### Parameter Substitution
```gdscript
# Translation file entry
"player.score.current" = "Player {player_name} has {score} points"

# Usage in code
LocalizationManager.get_text("player.score.current", {
    "player_name": "Alice",
    "score": 1250
})
# Result: "Player Alice has 1250 points"
```

### Context Information
```po
# Translation entry with context
#. Context: Button text for starting a new game session
#: scenes/ui/main_menu.tscn:45
msgid "ui.menu.start_game"
msgstr "Start Game"

#. Context: Tooltip shown when hovering over start button
#: scenes/ui/main_menu.tscn:46
msgid "ui.menu.start_game.tooltip"
msgstr "Begin a new multiplayer session"
```

## Cultural Adaptation Features

### Date and Time Formatting
```gdscript
func format_date(timestamp: float) -> String:
    var format = LocalizationManager.get_date_format(current_language)
    return Time.get_datetime_string_from_unix_time(timestamp, format)
```

### Number Formatting
```gdscript
func format_score(score: int) -> String:
    var format = LocalizationManager.get_number_format(current_language)
    return format_number(score, format.thousands_separator, format.decimal_separator)
```

### Text Direction Support
```gdscript
func apply_text_direction(control: Control) -> void:
    var is_rtl = LocalizationManager.is_rtl_language(current_language)
    control.set_layout_direction(
        Control.LAYOUT_DIRECTION_RTL if is_rtl else Control.LAYOUT_DIRECTION_LTR
    )
```

## Development Tools

### Translation Extraction Tool
```gdscript
# tools/translation_extractor.gd
# Scans codebase for LocalizationManager.get_text() calls
# Generates .pot template file with all translation keys
# Validates existing translations for missing keys
```

### Pseudolocalization
```gdscript
# Generates fake translations for testing text expansion
# English: "Start Game" -> Pseudolocalized: "[Şťàŕť Ğàmé àáâãäåāăąççćĉċ]"
# Tests UI layout with longer text and special characters
```

### Hot-Reload System
```gdscript
func _on_translation_file_changed() -> void:
    LocalizationManager.reload_translations()
    EventBus.translations_reloaded.emit()
    # All LocalizableLabel elements automatically update
```

## Testing Framework

### Validation Tests
- [ ] All translation keys exist in all supported languages
- [ ] Parameter substitution works correctly
- [ ] Text fits in UI elements across all languages
- [ ] Font rendering supports all character sets
- [ ] Right-to-left languages display correctly

### Automated Checks
```gdscript
# Automated translation validation
func validate_all_translations() -> Array[String]:
    var errors: Array[String] = []
    
    for language in SupportedLanguage.values():
        var missing_keys = check_missing_keys(language)
        var invalid_params = check_parameter_validity(language)
        var font_issues = check_font_coverage(language)
        
        errors.append_array(missing_keys)
        errors.append_array(invalid_params)
        errors.append_array(font_issues)
    
    return errors
```

## Integration Points

### GameManager Integration
```gdscript
# Save/load language preference
func save_language_preference(language: SupportedLanguage) -> void:
    var save_data = SaveSystem.load_user_preferences()
    save_data.language = language
    SaveSystem.save_user_preferences(save_data)

func load_language_preference() -> SupportedLanguage:
    var save_data = SaveSystem.load_user_preferences()
    return save_data.get("language", SupportedLanguage.EN_US)
```

### Settings Menu Integration
```gdscript
# Language selection dropdown in settings
@onready var language_option: OptionButton = $LanguageOption

func _ready() -> void:
    _populate_language_options()
    language_option.selected = LocalizationManager.current_language

func _populate_language_options() -> void:
    language_option.clear()
    for lang in LocalizationManager.SupportedLanguage.values():
        language_option.add_item(LocalizationManager.get_language_name(lang))
```

### Minigame Content Integration
```gdscript
# BaseMinigame tutorial localization
func get_tutorial_data() -> Dictionary:
    return {
        "rules": _get_localized_rules(),
        "controls": _get_localized_controls(),
        "objective": LocalizationManager.get_text(tutorial_objective_key),
        "tips": _get_localized_tips()
    }

func _get_localized_rules() -> Array[String]:
    var localized_rules: Array[String] = []
    for rule_key in tutorial_rule_keys:
        localized_rules.append(LocalizationManager.get_text(rule_key))
    return localized_rules
```

## Performance Considerations

### Translation Caching
```gdscript
# Cache translated strings to avoid repeated lookups
var translation_cache: Dictionary = {}  # key+params -> translated_text

func get_text_cached(key: String, params: Dictionary = {}) -> String:
    var cache_key = key + str(params.hash())
    if not translation_cache.has(cache_key):
        translation_cache[cache_key] = _translate_text(key, params)
    return translation_cache[cache_key]
```

### Lazy Loading
```gdscript
# Load translations only when needed
func ensure_language_loaded(language: SupportedLanguage) -> void:
    if not translations_loaded.get(language, false):
        _load_language_translation(language)
        translations_loaded[language] = true
```

## EventBus Signal Extensions

```gdscript
# New localization signals
signal language_changed(new_language: SupportedLanguage)
signal translations_reloaded()
signal translation_error(error_message: String)
signal font_changed(new_font: Font)
```

## Launch Readiness Checklist

### Core System
- [ ] LocalizationManager autoload implemented
- [ ] TranslationServer integration working
- [ ] Language switching functional
- [ ] Translation key validation system active

### Content
- [ ] All UI text extracted to translation files
- [ ] US English translations complete and reviewed
- [ ] Minigame content localized
- [ ] Player feedback messages localized

### Quality Assurance
- [ ] Text fits in UI across all target languages
- [ ] Fonts support all required character sets
- [ ] Parameter substitution tested extensively
- [ ] Cultural adaptations verified

### Development Workflow
- [ ] Translation extraction tool functional
- [ ] Hot-reload system working
- [ ] Validation tests passing
- [ ] Documentation complete for translators

## Notes

- **Default Language**: Defaults to US English (EN_US) with US cultural conventions
- **English Variants**: Can be extended to support EN_GB, EN_CA, EN_AU if needed
- **Scalability**: System designed for easy addition of new languages
- **Maintainability**: Centralized key management prevents inconsistencies
- **Quality**: Validation tools ensure translation completeness
- **Performance**: Caching and lazy loading optimize runtime efficiency
- **Cultural Sensitivity**: Adaptation features respect local conventions
- **Developer Experience**: Hot-reload and validation tools streamline workflow 