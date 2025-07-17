class_name ItemFactory
extends RefCounted

enum ItemType {
	WEAPON,
	CONSUMABLE,
	UTILITY,
	PROJECTILE
}

# Static factory methods for item creation
static func create_item(item_id: String) -> BaseItem:
	var config_path: String = "res://configs/item_configs/" + item_id + ".tres"
	
	if not ResourceLoader.exists(config_path):
		Logger.error("Failed to load item config for: " + item_id, "ItemFactory")
		return null
	
	var config: ItemConfig = load(config_path) as ItemConfig
	if not config:
		return null
	
	# Create item from scene
	var item: BaseItem = config.item_scene.instantiate()
	
	# Configure item properties
	_configure_item(item, config, Vector2.ZERO)
	
	return item

static func create_item_from_config(config: ItemConfig, spawn_position: Vector2 = Vector2.ZERO) -> BaseItem:
	if not config:
		return null
	
	var item: BaseItem
	
	if config.use_pooling and PoolManager:
		item = PoolManager.get_pooled_object(config.scene_path)
	else:
		item = config.item_scene.instantiate()
	
	if item:
		_configure_item(item, config, spawn_position)
	
	return item

# Simplified weapon creation using ItemConfig
static func create_weapon(weapon_id: String, spawn_position: Vector2 = Vector2.ZERO) -> BaseItem:
	return create_item_from_config(_load_item_config(weapon_id), spawn_position)

# Simplified projectile creation using ItemConfig and object pooling
static func create_projectile(projectile_id: String, launch_position: Vector2, direction: Vector2, owner_id: int = -1) -> BaseItem:
	var config: ItemConfig = _load_item_config(projectile_id)
	if not config:
		Logger.error("Failed to load projectile config for: " + projectile_id, "ItemFactory")
		return null
	
	var projectile: BaseItem
	
	# Projectiles typically use pooling for performance
	if config.use_pooling and PoolManager:
		projectile = PoolManager.get_pooled_object(config.scene_path)
	else:
		projectile = config.item_scene.instantiate()
	
	if projectile:
		_configure_item(projectile, config, launch_position)
		
		# Apply projectile-specific initialization
		if projectile.has_method("initialize"):
			var velocity = direction * 800.0  # Default bullet speed
			var damage = config.damage_amount if config.damage_amount > 0 else 1
			var owner_player: BasePlayer = null
			
			# Find the owner player by ID if provided
			if owner_id >= 0 and GameManager:
				var players = GameManager.get_all_players()
				for player in players:
					if player.player_data and player.player_data.player_id == owner_id:
						owner_player = player
						break
			
			projectile.initialize(velocity, damage, owner_player)
	
	return projectile

static func _load_item_config(item_id: String) -> ItemConfig:
	var config_path: String = "res://configs/item_configs/" + item_id + ".tres"
	return load(config_path) as ItemConfig

static func _configure_item(item: BaseItem, config: ItemConfig, spawn_position: Vector2) -> void:
	if not item or not config:
		return
	
	# Set basic item properties (checking if properties exist)
	if item.has_method("set") and config.item_name:
		item.item_name = config.item_name
	
	item.position = spawn_position
	
	# Apply configuration settings if the item has these properties
	if config.damage_amount > 0 and item.has_method("set"):
		# Try to set damage property if it exists
		if "damage" in item:
			item.damage = config.damage_amount
		elif "damage_amount" in item:
			item.damage_amount = config.damage_amount
	
	if config.use_duration > 0.0 and "use_duration" in item:
		item.use_duration = config.use_duration