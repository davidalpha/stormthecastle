extends CanvasLayer

@export var initial_time: float = 30.0
@export var extends_timer: bool = true
@export var extend_amount: float = 2.0
@export var group_name: String = "coin"

@onready var label: Label = $Label

var active: bool = false

func _ready() -> void:
	PickupManager.register_group(group_name, initial_time, extends_timer, extend_amount)
	PickupManager.pickup_collected.connect(_on_pickup_collected)
	PickupManager.timer_started.connect(_on_timer_started)
	PickupManager.timer_updated.connect(_on_timer_updated)
	PickupManager.group_completed.connect(_on_group_completed)
	PickupManager.group_failed.connect(_on_group_failed)
	label.visible = false

func _on_timer_started(group: String, time: float) -> void:
	if group != group_name:
		return
	active = true
	label.visible = true

func _on_pickup_collected(group: String, collected: int, total: int) -> void:
	if group != group_name:
		return
	_update_label(collected, total, PickupManager.group_timers[group_name])

func _on_timer_updated(group: String, time_remaining: float) -> void:
	if group != group_name:
		return
	var collected: int = PickupManager.group_collected[group_name]
	var total: int = PickupManager.group_totals[group_name]
	_update_label(collected, total, time_remaining)

func _on_group_completed(group: String) -> void:
	if group != group_name:
		return
	active = false
	label.text = "%s: ALL COLLECTED!" % group_name.capitalize()

func _on_group_failed(group: String) -> void:
	if group != group_name:
		return
	active = false
	label.text = "%s: TIME'S UP!" % group_name.capitalize()

func _update_label(collected: int, total: int, time_remaining: float) -> void:
	label.text = "%s: %d/%d  -  Time: %.1fs" % [group_name.capitalize(), collected, total, max(time_remaining, 0.0)]
