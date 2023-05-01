extends ByNodeScript

signal glided

var player: Player
var suit: PlayerSuit
var config: PlayerConfig

const tail_sound = preload("res://modules/raccoon/objects/players/prefabs/sounds/tail.wav")

var _has_jumped: bool
var jump_glide_timer: float

var fly_max_walk_speed: float = 150


func _ready() -> void:
	player = node as Player
	suit = node.suit
	config = suit.physics_config
	if !player.has_user_signal("glided"):
		player.add_user_signal("glided")
	player.underwater.got_into_water.connect(player.set.bind(&"is_underwater", true), CONNECT_REFERENCE_COUNTED)
	player.underwater.got_out_of_water.connect(player.set.bind(&"is_underwater", false), CONNECT_REFERENCE_COUNTED)


func _physics_process(delta: float) -> void:
	delta = player.get_physics_process_delta_time()
	# Control
	player.control_process()
	# Shape
	_shape_process()
	if player.warp != Player.Warp.NONE: return
	
	# Head
	_head_process()
	# Body
	_body_process()
	# Movement
	_movement_x(delta)
	_movement_y(delta)
	player.motion_process(delta)
	if player.is_on_wall():
		player.speed.x = 0


#= Movement
func _accelerate(to: float, acce: float, delta: float) -> void:
	player.speed.x = move_toward(player.speed.x, to * player.direction, abs(acce) * delta)


func _decelerate(dece: float, delta: float) -> void:
	_accelerate(0, dece, delta)


func _movement_x(delta: float) -> void:
	if player.is_crouching || player.left_right == 0 || player.completed:
		_decelerate(config.walk_deceleration, delta)
		return
	# Initial speed
	if player.left_right != 0 && player.speed.x == 0:
		player.direction = player.left_right
		player.speed.x = player.direction * config.walk_initial_speed
	# Acceleration
	if player.left_right == player.direction:
		var max_speed: float
		if !suit.extra_vars.p_flying:
			max_speed = config.underwater_walk_max_walking_speed if player.is_underwater else (config.walk_max_running_speed if player.running else config.walk_max_walking_speed)
		else:
			max_speed = (config.walk_max_walking_speed if player.running else fly_max_walk_speed)
		_accelerate(max_speed, config.walk_acceleration, delta)
	elif player.left_right == -player.direction:
		_decelerate(config.walk_turning_acce, delta)
		if player.speed.x == 0:
			player.direction *= -1 


func _movement_y(delta: float) -> void:
	if player.is_crouching && !ProjectSettings.get_setting("application/thunder_settings/player/jumpable_when_crouching", false):
		return
	if player.completed: return
	
	# Swimming
	if player.is_underwater:
		suit.extra_vars.p_flying = false
		if player.jumped:
			player.jump(config.swim_out_speed if player.is_underwater_out else config.swim_speed)
			player.swam.emit()
			Audio.play_sound(config.sound_swim, player, false, {pitch = suit.sound_pitch})
		if player.speed.y < -abs(config.swim_max_speed) && !player.is_underwater_out:
			player.speed.y = lerp(player.speed.y, -abs(config.swim_max_speed), 0.125)
	# Jumping
	else:
		# Normal Jumping
		if player.is_on_floor():
			if player.jumping > 0 && !_has_jumped:
				_has_jumped = true
				player.jump(config.jump_speed)
				Audio.play_sound(config.sound_jump, player, false, {pitch = suit.sound_pitch})
		# Raccoon Glide
		elif player.jumped:
			if suit.extra_vars.can_fly:
				suit.extra_vars.p_flying = true
			if (!suit.extra_vars.can_fly && player.speed.y > -50) || \
				suit.extra_vars.p_flying:
					jump_glide_timer = 0.4
					player.emit_signal(&"glided")
					_play_tail_sound()
		# Jump Buffer
		elif player.jumping > 0 && player.speed.y < 0:
			var buff: float = config.jump_buff_dynamic if abs(player.speed.x) > 10 else config.jump_buff_static
			player.speed.y -= abs(buff) * delta
		# Raccoon Gliding in process
		if !player.is_on_floor() && jump_glide_timer > 0:
			# Do not glide if not falling
			if !suit.extra_vars.p_flying || !suit.extra_vars.p_running:
				player.vel_set_y(min(75, player.speed.y))
				if player.speed.y < -50:
					jump_glide_timer = 0
					return
			else:
				player.vel_set_y(min(-fly_max_walk_speed, player.speed.y))
			jump_glide_timer = max(jump_glide_timer - delta, 0)
			
	if !player.jumping:
		_has_jumped = false
	# Reset Raccoon Gliding
	if player.is_on_floor():
		suit.extra_vars.p_flying = false
		suit.extra_vars.can_fly = false
		jump_glide_timer = 0


var delay: bool = false
func _play_tail_sound() -> void:
	if delay: return
	Audio.play_sound(tail_sound, player, false)
	delay = true
	await player.get_tree().create_timer(0.3, false).timeout
	if !is_instance_valid(self): return
	delay = false


#= Shape
func _shape_process() -> void:
	var shaper: Shaper2D = suit.physics_shaper_crouch if player.is_crouching && player.warp == Player.Warp.NONE else suit.physics_shaper
	if !shaper: return
	shaper.install_shape_for(player.collision_shape)
	shaper.install_shape_for_caster(player.body)
	
	if player.collision_shape.shape is RectangleShape2D:
		player.head.position.y = player.collision_shape.position.y - player.collision_shape.shape.size.y / 2 - 2


#= Head
func _head_process() -> void:
	player.is_underwater_out = true
	for i in player.head.get_collision_count():
		var collider: Node2D = player.head.get_collider(i) as Node2D
		if collider && collider.is_in_group(&"#water"):
			player.is_underwater_out = false

#= Body
func _body_process() -> void:
	if !player.body.shape: return
	
	player.body.target_position = player.speed.normalized() * 4
	for i in player.body.get_collision_count():
		var collider: Node2D = player.body.get_collider(i) as Node2D
		if !is_instance_valid(collider):
			continue
		if !collider.has_node("EnemyAttacked"): return
		
		var enemy_attacked: Node = collider.get_node("EnemyAttacked")
		var result: Dictionary = enemy_attacked.got_stomped(player)
		if result.is_empty(): return
		if result.result == true:
			jump_glide_timer = 0
			if player.jumping > 0:
				player.speed.y = -result.jumping_max * config.jump_stomp_multiplicator
			else:
				player.speed.y = -result.jumping_min * config.jump_stomp_multiplicator
		else:
			player.hurt(enemy_attacked.get_meta(&"stomp_tags", {}))
