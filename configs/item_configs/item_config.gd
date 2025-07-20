class_name ItemConfig
extends Resource

enum ItemType {
	WEAPON,
	UTILITY,
	CONSUMABLE,
	PROJECTILE
}

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.UTILITY
@export var item_scene: PackedScene
@export var scene_path: String = ""
@export var use_pooling: bool = false
@export var damage_amount: int = 0
@export var use_duration: float = 0.0
@export var rarity: int = 1
@export var description: String = ""

# Weapon-specific properties (only used when item_type == WEAPON)
@export_group("Weapon Properties")
@export var fire_rate: float = 1.0
@export var ammo_capacity: int = -1  # -1 for infinite ammo
@export var bullet_speed: float = 800.0
@export var throw_damage_multiplier: float = 1.5
@export var max_throw_force: float = 600.0
@export var can_ricochet: bool = false
@export var max_ricochets: int = 2
@export var recoil_force: float = 150.0
@export var spread_angle: float = 0.0
@export var bullets_per_shot: int = 1
@export var muzzle_flash_duration: float = 0.1

# Magazine-based ammo system
@export_group("Ammo System")
@export var auto_reload: bool = false  # Auto-reload when magazine is empty
@export var infinite_total_ammo: bool = false  # Infinite total ammo (but limited magazine)
@export var magazine_size: int = -1  # Shots per magazine (-1 uses ammo_capacity)
@export var reload_time: float = 1.0  # Time to reload in seconds

# Melee weapon properties (for bat-style weapons)
@export_group("Melee Properties")
@export var swing_range: float = 80.0
@export var swing_damage: int = 3
@export var knockback_force: float = 300.0 
