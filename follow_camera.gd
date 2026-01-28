extends Camera3D
class_name FollowCamera

enum State { SWOOP, ORBIT, GAMEPLAY }

@export var target: Node3D

# Follow camera settings
@export var follow_distance: float = 8.0
@export var follow_height: float = 3.0
@export var position_smoothing: float = 5.0
@export var rotation_smoothing: float = 8.0
@export var look_ahead: float = 2.0

# Intro settings
@export var swoop_duration: float = 2.0
@export var orbit_speed: float = 0.8
@export var orbit_distance: float = 10.0
@export var orbit_height: float = 2.0

var state: State = State.SWOOP
var intro_time: float = 0.0
var swoop_start_pos: Vector3
var swoop_end_pos: Vector3

# UI
var prompt_canvas: CanvasLayer
var prompt_label: Label

func _ready() -> void:
	if target:
		var car_pos := target.global_position
		swoop_start_pos = car_pos + Vector3(15, 10, 0)
		swoop_end_pos = car_pos + Vector3(orbit_distance, orbit_height, 0)
		global_position = swoop_start_pos
		look_at(car_pos, Vector3.UP)

	# Create prompt UI
	prompt_canvas = CanvasLayer.new()
	get_tree().root.add_child.call_deferred(prompt_canvas)
	prompt_label = Label.new()
	prompt_label.text = "Press Enter to Start"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.visible = false
	prompt_canvas.add_child(prompt_label)

func _physics_process(delta: float) -> void:
	if not target:
		return

	var car_pos := target.global_position
	intro_time += delta

	match state:
		State.SWOOP:
			_process_swoop(delta, car_pos)
		State.ORBIT:
			_process_orbit(delta, car_pos)
		State.GAMEPLAY:
			_process_gameplay(delta, car_pos)

func _process_swoop(_delta: float, car_pos: Vector3) -> void:
	var t: float = clamp(intro_time / swoop_duration, 0.0, 1.0)
	# Smooth ease-in-out
	t = t * t * (3.0 - 2.0 * t)
	global_position = swoop_start_pos.lerp(swoop_end_pos, t)
	look_at(car_pos, Vector3.UP)

	if intro_time >= swoop_duration:
		state = State.ORBIT
		intro_time = 0.0
		prompt_label.visible = true

func _process_orbit(_delta: float, car_pos: Vector3) -> void:
	var angle := intro_time * orbit_speed
	var orbit_pos := car_pos + Vector3(
		cos(angle) * orbit_distance,
		orbit_height,
		sin(angle) * orbit_distance
	)
	global_position = orbit_pos
	look_at(car_pos, Vector3.UP)

	if Input.is_action_just_pressed("ui_accept"):
		state = State.GAMEPLAY
		prompt_label.visible = false
		prompt_canvas.queue_free()
		if target is Car:
			target.input_enabled = true

func _process_gameplay(delta: float, car_pos: Vector3) -> void:
	var target_forward := -target.global_transform.basis.z
	var desired_position := car_pos - target_forward * follow_distance + Vector3.UP * follow_height
	global_position = global_position.lerp(desired_position, position_smoothing * delta)

	var look_target := car_pos + target_forward * look_ahead
	var current_basis := global_transform.basis
	look_at(look_target, Vector3.UP)
	var target_basis := global_transform.basis
	global_transform.basis = current_basis.slerp(target_basis, rotation_smoothing * delta)
