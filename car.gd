extends RigidBody3D
class_name Car

@export var engine_power: float = 800.0
@export var turn_speed: float = 3.0
@export var max_speed: float = 30.0

# Grip & Drift
@export var normal_grip: float = 0.9      # High grip when driving normally
@export var drift_grip: float = 0.4       # Low grip when drifting
@export var drift_speed_threshold: float = 8.0  # Min speed to drift
@export var steering_speed_scale: float = 0.5   # How much speed reduces steering (0 = no reduction)
@export var max_tilt_angle: float = 0.7  # Max roll/pitch in radians (~40 degrees)
@export var air_control: float = 1.5  # Air rotation strength (fraction of ground control)

# Suspension
@export var wheel_radius: float = 0.3
@export var suspension_rest: float = 0.3
@export var suspension_travel: float = 0.2

# Raycasts
@onready var ray_fl: RayCast3D = $RayFL
@onready var ray_fr: RayCast3D = $RayFR
@onready var ray_rl: RayCast3D = $RayRL
@onready var ray_rr: RayCast3D = $RayRR

# Wheels
@onready var wheel_fl: = $WheelFL
@onready var wheel_fr: = $WheelFR
@onready var wheel_rl: = $WheelRL
@onready var wheel_rr: = $WheelRR

# Effects
@onready var drift_smoke_effect: GPUParticles3D = $drift_smoke_effect

# Car body mesh for visual squat
@onready var car_body: Node3D = $rally_car_prototype_small

# Jump
@export var jump_force: float = 400.0
@export var squat_amount: float = 0.3  # How far the mesh lowers when charging

var wheel_spin: float = 0.0
var current_steer_angle: float = 0.0
var is_drifting: bool = false
var drift_amount: float = 0.0  # 0-1, for visual feedback
var is_squatting: bool = false
var car_body_rest_y: float = 0.0

func _ready() -> void:
	for ray in [ray_fl, ray_fr, ray_rl, ray_rr]:
		ray.add_exception(self)
	car_body_rest_y = car_body.position.y


func _physics_process(delta: float) -> void:
	var grounded := _any_wheel_grounded()

	# Jump: squat while holding, launch on release
	var jump_held := Input.is_physical_key_pressed(KEY_SHIFT)
	if jump_held and grounded:
		is_squatting = true
		car_body.position.y = lerp(car_body.position.y, car_body_rest_y - squat_amount, delta * 10.0)
	elif is_squatting:
		# Released jump key (or became airborne) — spring up
		is_squatting = false
		if grounded:
			linear_velocity.y = jump_force / mass
		car_body.position.y = car_body_rest_y
	else:
		car_body.position.y = lerp(car_body.position.y, car_body_rest_y, delta * 10.0)

	if not grounded:
		is_drifting = false
		drift_smoke_effect.emitting = false
		# Air control: yaw only (left/right)
		var air_steer := 0.0
		if Input.is_action_pressed("move_left"):
			air_steer = 1.0
		elif Input.is_action_pressed("move_right"):
			air_steer = -1.0
		angular_velocity.y = air_steer * air_control
		_clamp_rotation()
		return

	var speed := linear_velocity.length()
	var braking := Input.is_action_pressed("brake")

	# Steering input
	var turn_input := 0.0
	if Input.is_action_pressed("move_left"):
		turn_input = 1.0
	elif Input.is_action_pressed("move_right"):
		turn_input = -1.0

	# Detect drift: brake + steer + speed
	var wants_drift: bool = braking and abs(turn_input) > 0.1 and speed > drift_speed_threshold
	is_drifting = wants_drift or (is_drifting and abs(turn_input) > 0.1 and speed > drift_speed_threshold * 0.5)

	# Smooth drift amount for effects
	var target_drift := 1.0 if is_drifting else 0.0
	drift_amount = lerp(drift_amount, target_drift, delta * 5.0)

	# Throttle
	if Input.is_action_pressed("move_forward"):
		apply_central_force(-global_transform.basis.z * engine_power)
	elif Input.is_action_pressed("move_backward"):
		apply_central_force(global_transform.basis.z * engine_power)

	# Speed-based steering reduction
	var speed_factor: float = 1.0 - clamp(speed / max_speed, 0.0, 1.0) * steering_speed_scale
	var effective_turn_speed: float = turn_speed * speed_factor

	# Boost turn speed slightly when drifting for tighter control
	if is_drifting:
		effective_turn_speed *= 1.3
		drift_smoke_effect.emitting = true
	else:
		drift_smoke_effect.emitting = false

	# Only steer when moving
	if speed > 1.0:
		var forward_dot := -global_transform.basis.z.dot(linear_velocity.normalized())
		if forward_dot < 0:
			turn_input = -turn_input
		angular_velocity.y = turn_input * effective_turn_speed
	else:
		angular_velocity.y = 0.0

	# Brake (stronger when not drifting)
	if braking:
		if is_drifting:
			linear_velocity *= 0.98  # Light brake during drift
		else:
			linear_velocity *= 0.95  # Normal brake

	# Dynamic grip based on drift state
	var current_grip: float = lerpf(normal_grip, drift_grip, drift_amount)

	if speed > 0.5:
		# Grip only affects horizontal movement, preserve vertical velocity
		var vel_y := linear_velocity.y
		var forward_dir := -global_transform.basis.z
		forward_dir.y = 0.0
		forward_dir = forward_dir.normalized()
		# Use the direction the car is actually traveling (forward or reverse)
		var horizontal_vel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
		var h_speed := horizontal_vel.length()
		if h_speed > 0.5:
			var forward_dot := forward_dir.dot(horizontal_vel.normalized())
			var grip_dir := forward_dir if forward_dot >= 0.0 else -forward_dir
			var current_dir := horizontal_vel.normalized()
			var new_dir := current_dir.lerp(grip_dir, current_grip * delta * 10.0).normalized()
			linear_velocity = new_dir * h_speed
			linear_velocity.y = vel_y

	# Update wheel visuals
	_update_wheels(delta, turn_input, speed)

	# Clamp roll/pitch to prevent flipping
	_clamp_rotation()

func _any_wheel_grounded() -> bool:
	return ray_fl.is_colliding() or ray_fr.is_colliding() or ray_rl.is_colliding() or ray_rr.is_colliding()

func _clamp_rotation() -> void:
	var rot := rotation
	rot.x = clamp(rot.x, -max_tilt_angle, max_tilt_angle)
	rot.z = clamp(rot.z, -max_tilt_angle, max_tilt_angle)
	rotation = rot

	# Also dampen angular velocity if we're near the limit
	if abs(rotation.x) > max_tilt_angle * 0.9:
		angular_velocity.x *= 0.8
	if abs(rotation.z) > max_tilt_angle * 0.9:
		angular_velocity.z *= 0.8

func _update_wheels(delta: float, steer_input: float, _speed: float) -> void:
	# Wheel spin based on forward speed
	var forward_speed := -global_transform.basis.z.dot(linear_velocity)
	wheel_spin += forward_speed * delta / wheel_radius

	# Steer angle for front wheels
	current_steer_angle = lerp(current_steer_angle, steer_input * 0.4, delta * 10.0)

	# Update each wheel (FL/FR at Z=-1.4 are front, RL/RR at Z=+1.4 are rear)
	_update_single_wheel(wheel_fl, ray_fl, true)
	_update_single_wheel(wheel_fr, ray_fr, true)
	_update_single_wheel(wheel_rl, ray_rl, false)
	_update_single_wheel(wheel_rr, ray_rr, false)

func _update_single_wheel(wheel: Node3D, ray: RayCast3D, is_front: bool) -> void:
	var base_pos := ray.position

	var wheel_y := suspension_rest

	# Suspension: move wheel based on ground distance
	if ray.is_colliding():
		var hit_point := ray.get_collision_point()
		var ray_origin := ray.global_position
		var distance := ray_origin.y - hit_point.y
		wheel_y = clamp(base_pos.y - distance + wheel_radius, suspension_rest - suspension_travel, suspension_rest + suspension_travel)

	# Set wheel position
	var wheel_pos := Vector3(base_pos.x, wheel_y, base_pos.z)

	# Build rotation: spin around X, steer around Y for front wheels
	var spin_basis := Basis(Vector3.RIGHT, wheel_spin)
	var steer_basis := Basis.IDENTITY
	if is_front:
		steer_basis = Basis(Vector3.UP, current_steer_angle)

	# Rotate to lay cylinder on its side (Z-axis rotation)
	var side_basis := Basis(Vector3.FORWARD, PI / 1)

	# Flip right side wheels
	if base_pos.x > 0:
		side_basis = Basis(Vector3.FORWARD, -PI / 1)

	# Set position and rotation
	wheel.position = wheel_pos
	wheel.basis = steer_basis * spin_basis * side_basis
