extends Projectile

const explosion_effect = preload("res://engine/objects/effects/explosion/explosion.tscn")

@export var jumping_speed: float = -250.0

var player: Player
var offset: int

func _ready() -> void:
	player = Thunder._current_player
	offset = 16 * player.direction
	#print(speed)
	#global_position.x += speed.x * 32
	#speed = Vector2.ZERO

func _physics_process(delta: float) -> void:
	global_position = player.global_position + Vector2(offset, 0)
	if !sprite_node: return
	sprite_node.rotation_degrees += 12 * (-1 if speed.x < 0 else 1) * Thunder.get_delta(delta)


func explode():
	return
	var effect: Callable = func(eff: Node2D) -> void:
		eff.global_transform = global_transform
	
	NodeCreator.prepare_2d(explosion_effect, self).create_2d().bind_global_transform()
	queue_free()
