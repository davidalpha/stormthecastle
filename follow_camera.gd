extends Camera3D
class_name FollowCamera

@export var target: Node3D
@export var follow_distance: float = 8.0
@export var follow_height: float = 3.0
@export var position_smoothing: float = 5.0  # Lower = more lag
@export var rotation_smoothing: float = 8.0  # Lower = more lag
@export var look_ahead: float = 2.0  # Look slightly ahead of the car

func _physics_process(delta: float) -> void:
	if not target:
		return

	# Calculate target position behind the car
	var target_pos := target.global_position
	var target_forward := -target.global_transform.basis.z

	# Position camera behind and above the car
	var desired_position := target_pos - target_forward * follow_distance + Vector3.UP * follow_height

	# Smoothly move camera toward desired position
	global_position = global_position.lerp(desired_position, position_smoothing * delta)

	# Look at a point slightly ahead of the car
	var look_target := target_pos + target_forward * look_ahead

	# Smoothly rotate to look at target
	var current_basis := global_transform.basis
	look_at(look_target, Vector3.UP)
	var target_basis := global_transform.basis
	global_transform.basis = current_basis.slerp(target_basis, rotation_smoothing * delta)
