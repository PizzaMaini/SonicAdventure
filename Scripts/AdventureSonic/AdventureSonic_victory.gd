class_name AdventureSonic_victory extends PlayerStateMachine.State

var is_jumping: bool = false

func get_name()-> String:
	return "Victory"

func _bef_col(delta: float):
	get_player().player.velocity = Vector3.ZERO

func _bef_phys(delta: float):
	if(get_player().finished_anim):
		can_transition("Walk")
