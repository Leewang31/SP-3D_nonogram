# scripts/BlockGrid.gd
class_name BlockGrid
extends Node3D

const BLOCK_SIZE := 1.0
const BLOCK_GAP := 0.1
const STEP := BLOCK_SIZE + BLOCK_GAP

var _model: PuzzleModel
var _blocks: Array   # [z][y][x] = Node3D
var _filter_axis := -1
var _filter_depth := -1

func setup(model: PuzzleModel) -> void:
	_model = model
	_create_blocks()

func _create_blocks() -> void:
	var n := _model.size
	var half := (n - 1) * STEP / 2.0
	for z in n:
		var layer: Array = []
		for y in n:
			var row: Array = []
			for x in n:
				var block := _make_block(x, y, z, half)
				add_child(block)
				row.append(block)
			layer.append(row)
		_blocks.append(layer)

func _make_block(x: int, y: int, z: int, half: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x * STEP - half, y * STEP - half, z * STEP - half)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 0.9)
	mesh.material_override = mat
	root.add_child(mesh)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	col.shape = shape
	body.add_child(col)
	body.set_meta("grid_pos", Vector3i(x, y, z))
	body.set_meta("is_block", true)
	root.add_child(body)

	return root

func remove_block_visual(x: int, y: int, z: int) -> void:
	_blocks[z][y][x].visible = false

func flash_block_red(x: int, y: int, z: int) -> void:
	var mesh := _blocks[z][y][x].get_child(0) as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	var original := mat.albedo_color
	mat.albedo_color = Color(0.9, 0.2, 0.2)
	await get_tree().create_timer(0.3).timeout
	mat.albedo_color = original

func set_depth_filter(axis: int, depth: int) -> void:
	_filter_axis = axis
	_filter_depth = depth
	var n := _model.size
	for z in n:
		for y in n:
			for x in n:
				if _model.get_block_state(x, y, z) == PuzzleModel.BlockState.REMOVED:
					continue
				_blocks[z][y][x].visible = _is_visible(x, y, z)

func _is_visible(x: int, y: int, z: int) -> bool:
	if _filter_axis == -1:
		return true
	match _filter_axis:
		0: return x <= _filter_depth
		1: return y <= _filter_depth
		2: return z <= _filter_depth
	return true
