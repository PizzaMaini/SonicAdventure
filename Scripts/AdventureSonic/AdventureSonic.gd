class_name AdventureSonic extends Node

@export_group("Components")
@export var player: SonicPhysics
@export var camera: Node3D

@export_group("Movement Settings")
@export_subgroup("Walking")
@export var walk_acc: float
@export var walk_dcc: float
@export var walk_frc: float
@export var air_acc: float
@export var walk_top_speed: float
@export var walk_running_speed: float
@export var walk_slope_factor: float
@export var walk_max_forward_angle: float
@export var walk_max_forward_angle_walk: float
@export var walk_turn_rate: float
@export var walk_turn_rate_running: float
@export var turn_min_speed: float
@export var turn_max_speed: float
@export var walk_turn_decel_mult: float
@export_subgroup("Rolling")
@export var roll_slope_up_factor: float
@export var roll_slope_down_factor: float
@export var roll_frc: float
@export var roll_dcc: float
@export var roll_stop_speed: float
@export var roll_turn_speed: float
@export_subgroup("Air")
@export var air_lateral_frc: float
@export var gravity_force: float
@export_subgroup("Actions")
@export var jump_speed: float
@export var jump_decel_speed: float
@export var jump_gravity: float

var state_mac: PlayerStateMachine

var input_dir: Vector2
var input_force: float
var input_dir_world: Vector3 
var input_jump: bool
var input_roll: bool

var delta_time: float
var is_brake: bool

var turn_max_forw_angle: float
var acc_on_dir: bool

func _do_input() -> void:
	input_dir.x = Input.get_axis("move_l", "move_r")
	input_dir.y = Input.get_axis("move_u", "move_d")
	
	
	input_dir = input_dir.normalized();
	input_force = input_dir.length();
	
	
	if (Input.is_action_pressed("jump")):
		input_jump = true
	else:
		input_jump=false
	
	if (Input.is_action_pressed("roll")):
		input_roll = true
	else:
		input_roll=false
		
	var input_forw: Vector3 = SonicLib.vector3_project(camera.basis.z, player.avr_floor_nor)
	
	if(input_forw.is_zero_approx()):
		input_forw = SonicLib.vector3_project(camera.basis.y, player.avr_floor_nor)
		
	if(input_forw.is_zero_approx()):
		input_forw = SonicLib.vector3_project(camera.basis.x, player.avr_floor_nor)
	
	var input_rgt: Vector3 = player.avr_floor_nor.cross(input_forw)
	
	input_dir_world = (input_forw * input_dir.y + input_rgt * input_dir.x).normalized();
	
	DebugDraw3D.draw_line(player.position+player.basis.y, player.position+player.basis.y+input_dir_world, Color(1, 0, 1));
	

func _on_bef_col() -> void:
	state_mac.call_bef_col(delta_time)
	
func _on_bef_phys() -> void:
	state_mac.call_bef_phys(delta_time)
	
func _on_aft_phys() -> void:
	state_mac.call_aft_phys(delta_time)

# Called when the node enters the scene tree for the first time.
func _ready():
	state_mac = PlayerStateMachine.new(self)
	player.before_col.connect(_on_bef_col)
	player.before_phys.connect(_on_bef_phys)
	player.after_phys.connect(_on_aft_phys)
	
	state_mac.add_initial_state(AdventureSonic_walk.new(state_mac))
	state_mac.start_machine()
	
	is_brake = true;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	delta_time = delta
	_do_input()
	
	state_mac.call_process(delta_time)

func _physics_process(delta):
	delta_time = delta
	

func walk_damizean(acc:float, dcc:float, side_frc:float, top_speed:float):
	if(input_force > 0):
		var local_input: Vector3 = player.basis.inverse() * input_dir_world
		var local_vel: PackedVector3Array = SonicLib.node3d_separate_speed(player, player.velocity)
		var forw_speed:float = local_vel[0].dot(local_input)
		var forw_vel:Vector3 = local_input * forw_speed
		var side_vel: Vector3 =  local_vel[0]-forw_vel
		
		if(forw_speed < top_speed):
			if(forw_speed > 0):
				forw_speed += acc * delta_time
			else:
				forw_speed += dcc * delta_time
			
			forw_speed = min(forw_speed, top_speed)
			forw_vel = local_input * forw_speed
		
		side_vel = side_vel.move_toward(Vector3.ZERO, side_frc * delta_time)
		player.velocity = player.basis * (forw_vel + side_vel + local_vel[1])
		
func walk_turnrt(acc:float, dcc:float, top_speed:float, turn_rate:float, min_speed:float, speed_loss_factor:float):
	if(input_force > 0):
		var local_input: Vector3 = player.basis.inverse() * input_dir_world
		var local_vel: PackedVector3Array = SonicLib.node3d_separate_speed(player, player.velocity)
		
		var forw_speed:float = local_vel[0].dot(local_input)
		var dir_dif:float = local_vel[0].dot(local_input)
		var curr_speed:float = local_vel[0].length()
		
		# Gets the current direction the player is moving. Input direciont if not moving
		var curr_rota:= Basis.looking_at(local_vel[0].normalized() if (local_vel[0].length_squared() > 0) else local_input)
		#Gets the desired direction
		var to_rota:= Basis.looking_at(local_input)
		#The player can turn if the desired direction isnt opposite to the current, otherwise, brakes.
		var can_turn: bool = (dir_dif > cos(deg_to_rad(turn_max_forw_angle)))
		
		#If the player can turn and they arent braking, turns toward the desired direction based on the rate.
		var new_dir = curr_rota.slerp(to_rota if(can_turn && !is_brake) else curr_rota, turn_rate * delta_time) * Vector3.FORWARD
		
		# Loses the speed that isnt found in the new direction, multiplied by the speed_loss_factor
		curr_speed -= abs(curr_speed - new_dir.dot(local_vel[0]))*speed_loss_factor
		
		if(forw_speed < 0 && (!can_turn||is_brake)):
			if(!is_brake && curr_speed > min_speed):
				is_brake = true
		
		#Add speed instantly on the desired direction, rather than wait for turn
		if(acc_on_dir):
			local_vel[0] = (new_dir * curr_speed) + local_input * ((dcc if is_brake else (acc if (forw_speed < top_speed) else 0.0)) * delta_time)
		else:
			if(is_brake):
				curr_speed -= dcc * delta_time
			else: if(curr_speed < delta_time):
				curr_speed += acc * delta_time
				
			local_vel[0] = new_dir * curr_speed
			
		player.velocity = player.basis * (local_vel[0] + local_vel[1])
		
		
