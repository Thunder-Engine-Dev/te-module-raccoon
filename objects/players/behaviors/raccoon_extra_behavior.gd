extends ByNodeScript

var player: Player
var suit: PlayerSuit
var config: PlayerConfig

var p_counter: float = 0.0
var p_fly_counter: float = 0.0
var hud: Control
var hud_progress: TextureProgressBar
var hud_fly_icon: TextureRect

func _ready() -> void:
	player = node as Player
	suit = node.suit
	config = suit.physics_config
	
	# Adding P meter to HUD
	await player.get_tree().physics_frame
	hud = suit.extra_vars.hud.instantiate()
	Thunder._current_hud.add_child(hud)
	Effect.flash(hud, 0.8)
	
	hud_progress = hud.get_node("TextureProgressBar")
	hud_fly_icon = hud_progress.get_node("TextureRect")
	hud_fly_icon.texture.speed_scale = 0
	hud_fly_icon.texture.current_frame = 0

func _physics_process(delta: float) -> void:
	delta = player.get_physics_process_delta_time()
	_p_meter_process(delta)


func _p_meter_process(delta: float) -> void:
	# When p_speed is at max
	if suit.extra_vars.p_running:
		if hud:
			hud_fly_icon.texture.speed_scale = 1
			hud_progress.value = 6
		if !suit.extra_vars.p_flying:
			if !player.running || abs(player.speed.x) < config.walk_max_walking_speed:
				p_counter -= 1
				suit.extra_vars.p_running = false
			if !player.is_on_floor():
				suit.extra_vars.can_fly = true
				p_fly_counter = 175 # about 3.5 seconds of free flying time
			else:
				if !player.running:
					p_counter = 80
				suit.extra_vars.can_fly = false
		else:
			p_fly_counter = max(p_fly_counter - 50 * delta, 0)
			if p_fly_counter < 1:
				suit.extra_vars.p_flying = false
				if !player.is_on_floor():
					suit.extra_vars.p_running = false
					p_counter = 1
				
		return
	
	# When p_speed is below max
	if (player.running &&
		player.is_on_floor() &&
		abs(player.speed.x) >= config.walk_max_walking_speed + 50
	):
		p_counter += 100 * delta
	else:
		p_counter = max(p_counter - 40 * delta, 0)
	
	# Initialize P run
	if p_counter > 102:
		suit.extra_vars.p_running = true
		p_fly_counter = 0
		_p_meter_sound_loop()
	
	# HUD behavior
	if !hud: return
	hud_progress.value = ceili(p_counter / 17)
	hud_fly_icon.texture.speed_scale = 0
	hud_fly_icon.texture.current_frame = 0


func _p_meter_sound_loop() -> void:
	if !suit.extra_vars.p_running: return
	
	Audio.play_1d_sound(preload("res://modules/raccoon/components/hud/p_meter.wav"))
	await player.get_tree().create_timer(0.10, false, true).timeout
	_p_meter_sound_loop()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	if hud && is_instance_valid(hud): hud.free()
