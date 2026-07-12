# tests/test_axis_gizmo.gd
extends SceneTree

const AxisGizmo = preload("res://scripts/AxisGizmo.gd")

var _passed := 0
var _failed := 0

func _init() -> void:
	_test_single_step_forward()
	_test_carries_remainder()
	_test_accumulates_across_calls()
	_test_single_step_backward()
	_test_no_step_below_threshold()
	_test_multi_step_in_one_call()

	print("\nResults: %d passed, %d failed" % [_passed, _failed])
	quit(_failed)

func _assert(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		print("FAIL: " + name)

func _test_single_step_forward() -> void:
	var r := AxisGizmo._consume_steps(0.0, 65.0, 60.0)
	_assert(r["steps"] == 1, "65px delta with 60px step -> 1 step")
	_assert(is_equal_approx(r["remainder"], 5.0), "remainder carries the leftover 5px")

func _test_carries_remainder() -> void:
	var r := AxisGizmo._consume_steps(5.0, 58.0, 60.0)
	_assert(r["steps"] == 1, "accumulated 5+58=63px -> 1 step")
	_assert(is_equal_approx(r["remainder"], 3.0), "remainder is 3px after the step")

func _test_accumulates_across_calls() -> void:
	var accum := 0.0
	var total_steps := 0
	for delta in [20.0, 20.0, 25.0]:
		var r := AxisGizmo._consume_steps(accum, delta, 60.0)
		accum = r["remainder"]
		total_steps += r["steps"]
	_assert(total_steps == 1, "three small drags summing 65px -> 1 step total")
	_assert(is_equal_approx(accum, 5.0), "5px remainder left after the step")

func _test_single_step_backward() -> void:
	var r := AxisGizmo._consume_steps(0.0, -65.0, 60.0)
	_assert(r["steps"] == -1, "-65px delta -> -1 step")
	_assert(is_equal_approx(r["remainder"], -5.0), "remainder is -5px")

func _test_no_step_below_threshold() -> void:
	var r := AxisGizmo._consume_steps(0.0, 40.0, 60.0)
	_assert(r["steps"] == 0, "40px delta below 60px threshold -> 0 steps")
	_assert(is_equal_approx(r["remainder"], 40.0), "remainder equals the full delta")

func _test_multi_step_in_one_call() -> void:
	var r := AxisGizmo._consume_steps(0.0, 145.0, 60.0)
	_assert(r["steps"] == 2, "145px delta -> 2 steps in a single call (fast flick)")
	_assert(is_equal_approx(r["remainder"], 25.0), "remainder is 25px after 2 steps")
