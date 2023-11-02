class_name AdventureSonic_walk extends PlayerStateMachine.State

var is_jumping: bool = false

func get_name()-> String:
	return "Walk"

func _bef_col(delta: float):
	if(is_jumping && get_player().player.grounded):
		is_jumping = false
		
	if(is_jumping && !get_player().player.grounded && ((-get_player().player.gravity_dir).dot(get_player().player.velocity) > get_player().jump_decel_speed) && !get_player().input_jump):
		var hor_speed: Vector3 = SonicLib.vector3_project(get_player().player.velocity, -get_player().player.gravity_dir)
		print("New jump speed! %s" % (hor_speed + (-get_player().player.gravity_dir) * get_player().jump_decel_speed));
		get_player().player.velocity = hor_speed + (-get_player().player.gravity_dir) * get_player().jump_decel_speed;
		
		
	if(get_player().input_jump && get_player().player.grounded && !is_jumping):
		get_player().player.position += (get_player().player.avr_floor_nor) * 0.2
		get_player().player.skip_next_col = true
		is_jumping = true
		var hor_speed: Vector3 = SonicLib.vector3_project(get_player().player.velocity, -get_player().player.gravity_dir)
		get_player().player.velocity = hor_speed + (-get_player().player.gravity_dir) * get_player().jump_speed;
	print("Up speed! %s" % (-get_player().player.gravity_dir).dot(get_player().player.velocity));
	

func _bef_phys(delta: float):
	if(get_player().input_force > 0):
		get_player().player.do_friction = false
		get_player().walk_damizean(get_player().walk_acc, get_player().walk_dcc, get_player().air_lateral_frc, get_player().walk_top_speed);
	else:
		get_player().player.do_friction = true
		
