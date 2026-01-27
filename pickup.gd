extends Area3D
class_name Pickup

@export var pickup_group: String = "coin"
@export var pickup_mesh: Mesh
@export var rotation_speed: float = 2.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group(pickup_group)
	if pickup_mesh:
		mesh_instance.mesh = pickup_mesh
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	mesh_instance.rotate_y(rotation_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is Car:
		PickupManager.collect(self, pickup_group)
		queue_free()
