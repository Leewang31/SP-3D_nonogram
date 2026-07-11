# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.05   # 노출 표면 바깥쪽 거리
const CHIP_OFFSET := 0.035   # 칩은 라벨보다 살짝 안쪽 (표면에 더 밀착)
const CHIP_SIZE := 0.42

static var _chip_texture: ImageTexture

var _model: PuzzleModel
var _labels: Dictionary   # "axis,a,b" -> Label3D
var _chips: Dictionary    # "axis,a,b" -> MeshInstance3D

static func _get_chip_texture() -> ImageTexture:
	if _chip_texture == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size / 2.0, size / 2.0)
		var radius := size / 2.0 - 2.0
		var border := 2.5
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
				var col := Color(0, 0, 0, 0)
				if d <= radius:
					col = Color(0.47, 0.37, 0.22, 0.55) if d >= radius - border else Color(1.0, 0.99, 0.96, 0.72)
				img.set_pixel(x, y, col)
		_chip_texture = ImageTexture.create_from_image(img)
	return _chip_texture

func setup(model: PuzzleModel) -> void:
	_model = model
	_labels = {}
	_chips = {}
	var n := model.size

	for z in n:
		for y in n:
			_add_label(0, y, z)
	for z in n:
		for x in n:
			_add_label(1, x, z)
	for y in n:
		for x in n:
			_add_label(2, x, y)

func on_block_removed(x: int, y: int, z: int) -> void:
	_reposition(0, y, z)
	_reposition(1, x, z)
	_reposition(2, x, y)

func _add_label(axis: int, a: int, b: int) -> void:
	var key := "%d,%d,%d" % [axis, a, b]
	var clue := _model.get_clue(axis, a, b)
	var label := _make_label(str(clue))
	label.rotation = _face_rotation(axis)
	add_child(label)
	_labels[key] = label

	var chip := _make_chip()
	chip.rotation = _face_rotation(axis)
	add_child(chip)
	_chips[key] = chip

	_reposition(axis, a, b)

func _face_rotation(axis: int) -> Vector3:
	match axis:
		0: return Vector3(0, PI / 2.0, 0)   # X+ 면을 바라보도록 회전
		1: return Vector3(-PI / 2.0, 0, 0)  # Y+ 면을 바라보도록 회전
		_: return Vector3.ZERO              # Z+ 면 (기본 방향과 일치)

func _reposition(axis: int, a: int, b: int) -> void:
	var key := "%d,%d,%d" % [axis, a, b]
	var label: Label3D = _labels[key]
	var chip: MeshInstance3D = _chips[key]
	var n := _model.size
	var half := (n - 1) * BlockGrid.STEP / 2.0

	var front := _frontmost_intact(axis, a, b)
	label.visible = front != -1
	chip.visible = front != -1
	if front == -1:
		return   # 라인 전부 제거됨 — 붙을 표면 없음, 숨김

	var base := front * BlockGrid.STEP - half + BlockGrid.BLOCK_SIZE / 2.0
	var face := base + LABEL_OFFSET
	var chip_face := base + CHIP_OFFSET

	match axis:
		0:
			label.position = Vector3(face, a * BlockGrid.STEP - half, b * BlockGrid.STEP - half)
			chip.position = Vector3(chip_face, a * BlockGrid.STEP - half, b * BlockGrid.STEP - half)
		1:
			label.position = Vector3(a * BlockGrid.STEP - half, face, b * BlockGrid.STEP - half)
			chip.position = Vector3(a * BlockGrid.STEP - half, chip_face, b * BlockGrid.STEP - half)
		2:
			label.position = Vector3(a * BlockGrid.STEP - half, b * BlockGrid.STEP - half, face)
			chip.position = Vector3(a * BlockGrid.STEP - half, b * BlockGrid.STEP - half, chip_face)

func _frontmost_intact(axis: int, a: int, b: int) -> int:
	var n := _model.size
	for i in range(n - 1, -1, -1):
		var state: PuzzleModel.BlockState
		match axis:
			0: state = _model.get_block_state(i, a, b)
			1: state = _model.get_block_state(a, i, b)
			2: state = _model.get_block_state(a, b, i)
		if state == PuzzleModel.BlockState.INTACT:
			return i
	return -1

func _make_chip() -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(CHIP_SIZE, CHIP_SIZE)
	mesh_inst.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _get_chip_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	return mesh_inst

func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.005
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	return label
