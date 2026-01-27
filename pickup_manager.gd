extends Node

signal pickup_collected(group: String, collected: int, total: int)
signal timer_started(group: String, time: float)
signal timer_updated(group: String, time_remaining: float)
signal group_completed(group: String)
signal group_failed(group: String)

# Config per group: { initial_time, extends_timer, extend_amount }
var group_configs: Dictionary = {}
var group_timers: Dictionary = {}
var group_collected: Dictionary = {}
var group_totals: Dictionary = {}
var active_groups: Array = []

func register_group(group_name: String, initial_time: float, extends_timer: bool = false, extend_amount: float = 0.0) -> void:
	group_configs[group_name] = {
		"initial_time": initial_time,
		"extends_timer": extends_timer,
		"extend_amount": extend_amount,
	}
	group_collected[group_name] = 0

func collect(pickup: Node, group_name: String) -> void:
	if group_name not in group_configs:
		push_warning("PickupManager: group '%s' not registered" % group_name)
		return

	var config: Dictionary = group_configs[group_name]

	# On first collect, count total from group and start timer
	if group_name not in active_groups:
		group_totals[group_name] = get_tree().get_nodes_in_group(group_name).size()
		group_timers[group_name] = config["initial_time"]
		active_groups.append(group_name)
		timer_started.emit(group_name, config["initial_time"])

	group_collected[group_name] += 1
	var collected: int = group_collected[group_name]
	var total: int = group_totals[group_name]

	# Extend timer if configured
	if config["extends_timer"] and collected > 1:
		group_timers[group_name] += config["extend_amount"]

	pickup_collected.emit(group_name, collected, total)

	# Check win condition
	if collected >= total:
		active_groups.erase(group_name)
		group_completed.emit(group_name)

func _process(delta: float) -> void:
	for group_name in active_groups.duplicate():
		group_timers[group_name] -= delta
		var time_left: float = group_timers[group_name]
		timer_updated.emit(group_name, time_left)

		if time_left <= 0.0:
			active_groups.erase(group_name)
			group_failed.emit(group_name)
