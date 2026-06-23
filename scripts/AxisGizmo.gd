# scripts/AxisGizmo.gd
class_name AxisGizmo
extends Node3D

signal depth_changed(axis: int, depth: int)

var _puzzle_size: int
var _depths: Array[int] = [-1, -1, -1]   # X, Y, Z

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

func on_axis_tapped(axis: int) -> void:
	var d := _depths[axis]
	if d == -1:
		d = 0
	elif d >= _puzzle_size - 1:
		d = -1
	else:
		d += 1
	_depths[axis] = d
	depth_changed.emit(axis, d)
