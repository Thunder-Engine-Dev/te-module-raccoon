extends Powerup

var init: bool = false
var init2: bool = false
var pos: float

func appear_process(delta: float) -> void:
	if init2: return
	init2 = true
	
	var tw = create_tween()
	tw.tween_property(self, "global_position", position + Vector2(0, -100), 1.0) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		appear_distance = 0
	)
	
	#appear_distance = max(appear_distance - appear_speed * delta, 0)
	#position -= Vector2(0, appear_speed).rotated(global_rotation) * delta
	
func motion_process(delta: float, _slide: bool = false) -> void:
	if init: return
	init = true
	
	var tw = create_tween()
	tw.tween_callback(func():
		$Sprite.flip_h = false
		self.pos += 16
	)
	tw.tween_property(self, "position", position + Vector2(96, pos), 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		$Sprite.flip_h = true
		self.pos += 16
	)
	tw.tween_property(self, "position", position + Vector2(0, pos), 0.6) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	tw.set_loops()
