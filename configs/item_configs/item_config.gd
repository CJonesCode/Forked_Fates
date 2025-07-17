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
