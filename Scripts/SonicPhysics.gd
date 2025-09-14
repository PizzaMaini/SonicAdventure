class_name SonicPhysics
## Base class for Sonic physics.
##
## Base class for Sonic physics. The velocity gets modified by another script
## according to player input, and this class reacts physically. Also provides
## signals for various events.

extends CharacterBody3D

enum {GROUND_METHOD_RAY, GROUND_METHOD_FROMBALL, GROUND_METHOD_BALL}
var direction = "F"
var animation = ""
@export_group("Components")
@export var camera: Node3D
@export var _shape: CollisionShape3D

@export_group("Movement")
## Current ground friction
@export var ground_frc: float = 6
@export var control_lock_time: float = 0.5
@export var do_friction: bool = true
## Min speed at which Sonic slips when not running on uneven terrain
@export var min_slip_speed: float = 5
## Slope factor. This is how much a slope pulls down on Sonic
@export var slope_factor: float = 6
## The minimum vertical velocity before airdrag kicks in
@export var airdrag_vert_limit: float = 6
## The minimum hor velocity before airdrag kicks in
@export var airdrag_hor_limit: float = 0.46875
## The air drag factor applied when Sonic is on the air.
@export var airdrag_factor: float = 0.0625
@export var do_airddrag: bool = true
@export var stop_on_cei: bool = true
@export var stop_on_wall: bool = true

@export_group("Collision")
## The maximum angle between sonic and a surface before it stops being floor.
@export var max_floor_angle: float = 50
## The minimuym angle between sonic and a surface before it stops being a ceiling
@export var min_cei_angle: float = 140
## The maximum angle between sonic and a surface before he cant stand without being dragged
@export var max_stand_angle: float = 10
## The minimum angle where Sonic can slip from a surface when he stops running.
@export var min_slip_angle: float = 40
## Method for getting ground angle
@export_enum("Ray", "Ray From Capsule", "Capsule") var ground_method: int = 2

@export_group("Gravity")
@export var gravity_dir:= Vector3.DOWN
@export var gravity_force: float = 30
@export var max_gravity_force: float = 300
@export var do_gravity: bool = true
## Multiplies horizontal speed when landing.
@export var air_ground_mult: float = 1

@export_group("Callbacks")
signal before_col(delta: float)
signal after_col(delta: float)
signal before_phys(delta: float)
signal after_phys(delta: float)

var delta_time: float = 1.0/60.0
var skip_next_col: bool = false;
var do_control_lock: bool = false; 

var control_lock: float = 0

var capsule: CapsuleShape3D;

var _keep_rota_frames: int = 0
var _cmax_floor_angle: float = 0;
var _cmin_cei_angle: float = 0;
var _cmax_stand_angle: float = 0;
var _cmin_slip_angle: float = 0;

var grounded: bool = false; 

var space_state: PhysicsDirectSpaceState3D;

var old_floor_nor := Vector3.UP;
var avr_floor_nor := Vector3.UP;
var avr_floor_pos := Vector3.ZERO;

var slope_dir := Vector3.DOWN;

var avr_cei_nor := Vector3.DOWN;
var avr_cei_pos := Vector3.ZERO;

var avr_wall_nor := Vector3.BACK;
var avr_wall_pos := Vector3.ZERO;

var col_floor_count: int = 0;
var col_ceil_count: int = 0;
var col_wall_count: int = 0;

func deg_to_cos_params() -> void:
	_cmax_floor_angle = cos(deg_to_rad(max_floor_angle));
	_cmin_cei_angle = cos(deg_to_rad(min_cei_angle));
	_cmax_stand_angle = cos(deg_to_rad(max_stand_angle));
	_cmin_slip_angle = cos(deg_to_rad(min_slip_angle));
	return

func _process_collision(collision: KinematicCollision3D) -> void:
	if(collision == null):
		return;
		
	var cache_count: int = collision.get_collision_count();
	for i in range(cache_count):
		var curr_normal = collision.get_normal(i);
		var ply_surf_dot = basis.y.dot(curr_normal);
		if(ply_surf_dot > _cmax_floor_angle):
			avr_floor_nor += curr_normal
			avr_floor_pos += collision.get_position(i)
			col_floor_count+=1;
		else: if(ply_surf_dot < _cmin_cei_angle):
			avr_cei_nor += curr_normal
			avr_cei_pos += collision.get_position(i)
			col_ceil_count+=1;
			
			var speed_to_cei: float = velocity.dot(-curr_normal)
			if(speed_to_cei > 0):
				velocity += curr_normal * speed_to_cei;
			
		else: 
			avr_wall_nor += curr_normal
			avr_wall_pos += collision.get_position(i)
			col_wall_count+=1;
			
			var flat_wall_col: Vector3 = SonicLib.vector3_project(curr_normal, basis.y).normalized();
			var speed_to_wall: float = velocity.dot(-flat_wall_col)
			if(speed_to_wall > 0):
				velocity += flat_wall_col * speed_to_wall;
	
	if(col_floor_count > 0):
		avr_floor_nor /= col_floor_count
		avr_floor_pos /= col_floor_count
		
	if(col_wall_count > 0):
		avr_wall_nor /= col_wall_count
		avr_wall_pos /= col_wall_count
		
	if(col_ceil_count > 0):
		avr_cei_nor /= col_ceil_count
		avr_cei_pos /= col_ceil_count
	
	avr_floor_nor = avr_floor_nor.normalized()
	avr_cei_nor = avr_cei_nor.normalized()
	avr_wall_nor = avr_wall_nor.normalized()
	
	return

func _reset_col() -> void: 
	col_ceil_count=0
	col_floor_count=0
	col_wall_count=0
	
func _clear_col() -> void:
		if(col_floor_count == 0):
			avr_floor_nor = -gravity_dir
			avr_floor_pos = position
		if(col_wall_count == 0):
			avr_wall_pos = position
			avr_wall_nor = quaternion * Vector3.FORWARD
		if(col_ceil_count == 0):
			avr_cei_pos = position
			avr_cei_nor = gravity_dir

func _col_by_ray(ray: Vector3) -> bool:
	avr_floor_nor = -gravity_dir;
	avr_floor_pos = global_position;
	col_floor_count = 0;
	
	var col_query:=PhysicsRayQueryParameters3D.create(global_position+(-ray*0.1), global_position+(ray*0.2))
	col_query.exclude = [self]
	var result:Dictionary = space_state.intersect_ray(col_query);
	if(!result.is_empty()):
		if(result["normal"].dot(basis.y) > _cmax_floor_angle):
			avr_floor_nor = result["normal"];
			avr_floor_pos = result["position"];
			col_floor_count = 1;
			return true;
	
	return false;

func _do_floor_col():
	match ground_method:
		GROUND_METHOD_RAY:
			_col_by_ray(-basis.y);
		GROUND_METHOD_FROMBALL:
			_col_by_ray(avr_floor_nor);

func _normal_collision_checks():
	var will_ground: bool = false;
	
	
	
	if(!skip_next_col):
		_do_floor_col();
		
		if(col_floor_count > 0):
			if(grounded):
				velocity = Quaternion(old_floor_nor, avr_floor_nor) * velocity;
			will_ground=true;
		else: if(grounded):
			up_direction = basis.y
			apply_floor_snap()
			will_ground = _col_by_ray(-basis.y)
		
	grounded = will_ground
	
	print("Floor col count: %s , grounded?: %s" % [col_floor_count,  grounded])
	DebugDraw3D.draw_line(position+basis.y, position+basis.y+avr_floor_nor, Color(0, 0, 1));
	DebugDraw3D.draw_line(position, position+velocity, Color(1, 0, 0));
	
	if(grounded):
		## Projects gravity to floor, giving us slope dir
		slope_dir = SonicLib.vector3_project(gravity_dir, avr_floor_nor).normalized()
		
		DebugDraw3D.draw_line(position, position+slope_dir, Color(1, 0, 1));
		
		# DebugDraw3D.draw_line(position+basis.y, position+basis.y+basis.y, Color(1, 0, 1));
		
		quaternion = Quaternion(Vector3.UP, avr_floor_nor);
		old_floor_nor = avr_floor_nor;
		_keep_rota_frames = 0;
		if(do_control_lock && control_lock > 0):
			control_lock-=delta_time
	else:
		_keep_rota_frames+=1
		if(_keep_rota_frames<5):
			quaternion = Quaternion(Vector3.UP, old_floor_nor);
		else:
			quaternion = Quaternion(Vector3.UP, avr_floor_nor);


func _do_slopes() -> void:
	var slope_dot:=(-gravity_dir).dot(avr_floor_nor)
	if(slope_dot < _cmax_stand_angle || control_lock > 0):
		#print("is sloping! %s " % (slope_factor * (abs(sin((-gravity_dir).angle_to(avr_floor_nor) )))))
		velocity+= slope_dir * (slope_factor * (abs(sin((-gravity_dir).angle_to(avr_floor_nor) )))) * delta_time
	
	if(velocity.length() < min_slip_speed && control_lock <= 0 && slope_factor < _cmin_slip_angle):
		grounded = false
		col_floor_count = 0
		control_lock = control_lock_time
		if(slope_dot < _cmax_floor_angle):
			quaternion = Quaternion(Vector3.UP, -gravity_dir)
			old_floor_nor = -gravity_dir
			global_position=avr_floor_pos+(avr_floor_nor*capsule.height)

func _normal_physics() -> void:
	
	#Slope Physics
	if(grounded):
		_do_slopes()
	
	var broke_vel:PackedVector3Array=SonicLib.node3d_separate_speed(self, velocity);
	
	
	
	if(grounded):
		if(do_friction): 
			broke_vel[0]=broke_vel[0].move_toward(Vector3.ZERO, ground_frc*delta_time)
			#print("frictioning. %s, %s" % [broke_vel[0], broke_vel[1]])
		broke_vel[1]=Vector3.ZERO;
	else:
		if(do_airddrag):
			var v_magn = broke_vel[1].dot(basis.inverse() * -gravity_dir);
			if(broke_vel[0].length() > airdrag_hor_limit && 0 < v_magn && v_magn < airdrag_vert_limit):
				broke_vel[0]=broke_vel[0]*pow(airdrag_factor,delta_time)
		if(do_gravity):
			if(broke_vel[1].dot(basis.inverse() * gravity_dir) < max_gravity_force):
				var broke_fal_vel:PackedVector3Array=SonicLib.node3d_separate_speed(self, gravity_dir*gravity_force*delta_time);
				
				broke_vel[0]+=broke_fal_vel[0]
				broke_vel[1]+=broke_fal_vel[1]
				
	velocity = transform.basis * (broke_vel[0] + broke_vel[1])


func _ready():
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING;
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING;
	deg_to_cos_params();
	capsule = _shape.shape as CapsuleShape3D
	#remove_child(camera)
	#get_tree().get_root().add_child(camera)

func _physics_process(delta):
	delta_time = delta
	space_state = get_world_3d().direct_space_state;
	var p_fwd = -camera.global_transform.basis.z
	var fwd = global_transform.basis.z
	var left = global_transform.basis.x
	var l_dot = left.dot(p_fwd)
	var f_dot = fwd.dot(p_fwd)
	
	if f_dot < -0.85:
		direction = "F"
	elif f_dot > 0.85:
		direction = "B"
	else:
		$Visuals/AnimatedSprite3D.flip_h = l_dot > 0
		if abs(f_dot) < 0.3:
			direction = "S"
		elif f_dot < 8:
			direction = "NE"
		else:
			direction = "NS"
	
	before_col.emit()
	
	if(skip_next_col):
		_reset_col()
	
	_clear_col()
	
	_normal_collision_checks()
	
	skip_next_col = false
	print(round(velocity.length()))
	before_phys.emit()
	if(grounded):
		if(round(velocity.length()) == 0):
			animation = "Idle"
		else:
			if(round(velocity.length()) > 15):
				animation = "Run Fast"
			elif(round(velocity.length()) > 5):
				animation = "Run"
			else:
				animation = "Walk"
	else:
		animation = "Jump"
	_normal_physics()
	$Visuals/AnimatedSprite3D.play(animation + direction)
	after_phys.emit()
	
	_reset_col()

	var vel_cache: Vector3 = velocity

	move_and_slide()
	
	velocity = vel_cache
	
	_process_collision(get_last_slide_collision())
	
	camera.position = position
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	# var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	
