# scripts/CameraController.gd
class_name CameraController
extends Camera3D

signal block_tapped(x: int, y: int, z: int)
signal gizmo_tapped(axis: int)

const TAP_THRESHOLD := 10.0
const ORBIT_SENSITIVITY := 0.007
const PINCH_SENSITIVITY := 0.015
const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 18.0

var _theta := PI / 6.0    # horizontal angle
var _phi := PI / 3.5      # vertical angle
var _distance := 9.0
var _target := Vector3.ZERO

var _touches: Dictionary = {}     # index → Vector2
var _touch0_start := Vector2.ZERO
var _pinch_start_dist := 0.0
var _is_pinching := false

func _ready() -> void:
	reset_transform()

func reset_transform() -> void:
	_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if event.index == 0:
			_touch0_start = event.position
		if _touches.size() == 2:
			_is_pinching = true
			_pinch_start_dist = _touches[0].distance_to(_touches[1])
	else:
		if not _is_pinching and event.index == 0:
			var moved := event.position.distance_to(_touch0_start)
			if moved < TAP_THRESHOLD:
				_do_raycast(event.position)
		_touches.erase(event.index)
		if _touches.size() < 2:
			_is_pinching = false

func _on_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _is_pinching and _touches.size() == 2:
		var new_dist: float = (_touches[0] as Vector2).distance_to(_touches[1] as Vector2)
		var delta := new_dist - _pinch_start_dist
		_distance = clamp(_distance - delta * PINCH_SENSITIVITY, MIN_DISTANCE, MAX_DISTANCE)
		_pinch_start_dist = new_dist
		_update_camera()
	elif not _is_pinching and event.index == 0:
		_theta -= event.relative.x * ORBIT_SENSITIVITY
		_phi = clamp(_phi - event.relative.y * ORBIT_SENSITIVITY, 0.15, PI - 0.15)
		_update_camera()

func _update_camera() -> void:
	var x := _distance * sin(_phi) * cos(_theta)
	var y := _distance * cos(_phi)
	var z := _distance * sin(_phi) * sin(_theta)
	position = _target + Vector3(x, y, z)
	look_at(_target, Vector3.UP)

func _do_raycast(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
	var origin := project_ray_origin(screen_pos)
	var direction := project_ray_normal(screen_pos)
	var params := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	params.collision_mask = 3  # layer 1 (blocks) + layer 2 (gizmo)
	var hit := space.intersect_ray(params)
	if not hit:
		return
	var collider := hit.collider
	if collider.has_meta("grid_pos"):
		var gp := collider.get_meta("grid_pos") as Vector3i
		block_tapped.emit(gp.x, gp.y, gp.z)
	elif collider.has_meta("gizmo_axis"):
		gizmo_tapped.emit(collider.get_meta("gizmo_axis") as int)
