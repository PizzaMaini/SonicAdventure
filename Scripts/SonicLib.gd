class_name SonicLib
## Method Library
##
## Several Methods to make work easier.

extends Object

## As the following function is documented, even though its name starts with
## an underscore, it will appear in the help window.
static func vector3_project(vec: Vector3, on_norm: Vector3) -> Vector3:
	return Plane(on_norm, 0).project(vec)

## Separates velocity into horizontal and vertical components
## based on node rotation. [0] is horizontal, [1] is vertical
static func node3d_separate_speed(transform: Node3D, velocity: Vector3) -> PackedVector3Array:
	var returnArr:= PackedVector3Array()
	velocity = transform.transform.basis.inverse() * velocity;
	var hor_vel:=Vector3(velocity.x, 0.0, velocity.z);
	var ver_vel:=Vector3(0.0, velocity.y, 0.0);
	returnArr.append(hor_vel);
	returnArr.append(ver_vel);
	return returnArr;
	

