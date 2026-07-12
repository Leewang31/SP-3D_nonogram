# scripts/AxisGizmo.gd
class_name AxisGizmo
extends Node3D

signal depth_changed(axis: int, depth: int)
signal axis_lock_changed(is_locked: bool)

const STEP_PIXELS := 60.0

var _puzzle_size: int
var _depths: Array[int] = [-1, -1, -1]   # X, Y, Z
var _roots: Array[Node3D] = [null, null, null]
var _bodies: Array[StaticBody3D] = [null, null, null]
var _active_axis := -1
var _drag_accum := 0.0

static func _consume_steps(accum: float, delta: float, step_pixels: float) -> Dictionary:
	var total := accum + delta
	var steps := int(total / step_pixels)
	var remainder := total - float(steps) * step_pixels
	return {"remainder": remainder, "steps": steps}

func setup(puzzle_size: int) -> void:
	_puzzle_size = puzzle_size
	var half := (puzzle_size - 1) * BlockGrid.STEP / 2.0
	var edge := half + BlockGrid.BLOCK_SIZE / 2.0

	_add_arrow(0, Vector3(edge + 1.5, 0.0, 0.0), Color.RED,   Vector3(0, 0, -PI/2))
	_add_arrow(1, Vector3(0.0, edge + 1.5, 0.0), Color.GREEN, Vector3.ZERO)
	_add_arrow(2, Vector3(0.0, 0.0, edge + 1.5), Color.BLUE,  Vector3(PI/2, 0, 0))

func _add_arrow(axis: int, pos: Vector3, color: Color, rotation_euler: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.8
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.18
	mesh.mesh = cyl
	mesh.rotation = rotation_euler
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	root.add_child(mesh)

	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.8
	shape.radius = 0.18
	col.shape = shape
	col.rotation = rotation_euler
	body.add_child(col)
	body.set_meta("gizmo_axis", axis)
	root.add_child(body)

	add_child(root)
	_roots[axis] = root
	_bodies[axis] = body

func begin_drag(axis: int) -> void:
	if _active_axis != -1:
		return   # 이미 다른 축이 활성 — 새 grab 무시
	_active_axis = axis
	_drag_accum = 0.0
	for a in 3:
		if a != axis:
			_roots[a].visible = false
			_bodies[a].collision_layer = 0
	axis_lock_changed.emit(true)

func update_drag(screen_delta: Vector2) -> void:
	if _active_axis == -1:
		return
	var dir := _screen_direction(_active_axis)
	if dir == Vector2.ZERO:
		return
	var scalar := screen_delta.dot(dir)
	var result := _consume_steps(_drag_accum, scalar, STEP_PIXELS)
	var remainder: float = result["remainder"]
	var steps: int = result["steps"]
	if steps == 0:
		_drag_accum = remainder
		return
	var current := _depths[_active_axis]
	var target := current + steps
	var clamped := clampi(target, 0, _puzzle_size - 1)
	_drag_accum = 0.0 if clamped != target else remainder
	if clamped != current:
		_depths[_active_axis] = clamped
		depth_changed.emit(_active_axis, clamped)
		if clamped == _puzzle_size - 1:
			_unlock()   # 최상단(=전체 표시와 시각적으로 동일) 도달 — 자동으로 잠금 해제

func end_drag() -> void:
	_drag_accum = 0.0

func reset() -> void:
	if _active_axis == -1:
		return
	var axis := _active_axis
	_depths[axis] = -1
	depth_changed.emit(axis, -1)
	_unlock()

func _unlock() -> void:
	for a in 3:
		_roots[a].visible = true
		_bodies[a].collision_layer = 2
	_active_axis = -1
	_drag_accum = 0.0
	axis_lock_changed.emit(false)

func _screen_direction(axis: int) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var root := _roots[axis]
	var world_dir: Vector3 = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)][axis]
	var p0 := cam.unproject_position(root.global_position)
	var p1 := cam.unproject_position(root.global_position + world_dir * 0.5)
	var d := p1 - p0
	if d.length() < 0.001:
		return Vector2.ZERO
	return d.normalized()
