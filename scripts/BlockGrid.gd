# scripts/BlockGrid.gd
class_name BlockGrid
extends Node3D

const BLOCK_SIZE := 1.0
const BLOCK_GAP := 0.1
const STEP := BLOCK_SIZE + BLOCK_GAP
const DEFAULT_COLOR := Color(0.3, 0.5, 0.9)
const CONFIRMED_COLOR := Color(0.85, 0.65, 0.15)

const FACE_SHADE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec3 n = normalize(NORMAL);
	float shade = 0.72;
	if (n.y > 0.5) {
		shade = 1.00;
	} else if (n.y < -0.5) {
		shade = 0.60;
	} else if (n.x > 0.5) {
		shade = 0.80;
	} else if (n.x < -0.5) {
		shade = 0.66;
	} else if (n.z > 0.5) {
		shade = 0.90;
	} else {
		shade = 0.72;
	}
	ALBEDO = albedo.rgb * shade;
}
"""

static var _face_shade_shader: Shader

var _model: PuzzleModel
var _blocks: Array   # [z][y][x] = Node3D
var _filter_axis := -1
var _filter_depth := -1

static func _get_face_shade_shader() -> Shader:
	if _face_shade_shader == null:
		_face_shade_shader = Shader.new()
		_face_shade_shader.code = FACE_SHADE_SHADER_CODE
	return _face_shade_shader

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
	var mat := ShaderMaterial.new()
	mat.shader = _get_face_shade_shader()
	mat.set_shader_parameter("albedo", DEFAULT_COLOR)
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

func get_block(x: int, y: int, z: int) -> Node3D:
	return _blocks[z][y][x]

func remove_block_visual(x: int, y: int, z: int) -> void:
	var block: Node3D = _blocks[z][y][x]
	block.visible = false
	var body := block.get_child(1) as StaticBody3D
	body.collision_layer = 0

func set_block_confirmed(x: int, y: int, z: int, confirmed: bool) -> void:
	var mesh := _blocks[z][y][x].get_child(0) as MeshInstance3D
	var mat := mesh.material_override as ShaderMaterial
	mat.set_shader_parameter("albedo", CONFIRMED_COLOR if confirmed else DEFAULT_COLOR)

func flash_block_red(x: int, y: int, z: int) -> void:
	var mesh := _blocks[z][y][x].get_child(0) as MeshInstance3D
	var mat := mesh.material_override as ShaderMaterial
	var original: Color = mat.get_shader_parameter("albedo")
	mat.set_shader_parameter("albedo", Color(0.9, 0.2, 0.2))
	await get_tree().create_timer(0.3).timeout
	mat.set_shader_parameter("albedo", original)

func set_depth_filter(axis: int, depth: int) -> void:
	if depth == -1:
		_filter_axis = -1
		_filter_depth = -1
		# show all non-removed blocks
		var n := _model.size
		for z in n:
			for y in n:
				for x in n:
					if _model.get_block_state(x, y, z) == PuzzleModel.BlockState.REMOVED:
						continue
					_set_block_visible(x, y, z, true)
		return
	_filter_axis = axis
	_filter_depth = depth
	var n := _model.size
	for z in n:
		for y in n:
			for x in n:
				if _model.get_block_state(x, y, z) == PuzzleModel.BlockState.REMOVED:
					continue
				_set_block_visible(x, y, z, _is_visible(x, y, z))

func _set_block_visible(x: int, y: int, z: int, vis: bool) -> void:
	var block: Node3D = _blocks[z][y][x]
	block.visible = vis
	var body := block.get_child(1) as StaticBody3D
	body.collision_layer = 1 if vis else 0

func _is_visible(x: int, y: int, z: int) -> bool:
	if _filter_axis == -1:
		return true
	match _filter_axis:
		0: return x <= _filter_depth
		1: return y <= _filter_depth
		2: return z <= _filter_depth
		_: return true
