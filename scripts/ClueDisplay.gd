# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.05   # 노출 표면 바깥쪽 거리

var _model: PuzzleModel
var _labels: Dictionary   # "axis,a,b" -> Label3D

func setup(model: PuzzleModel) -> void:
	_model = model
	_labels = {}
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
	var clue := _model.get_clue(axis, a, b)
	var label := _make_label(str(clue))
	label.rotation = _face_rotation(axis)
	add_child(label)
	_labels["%d,%d,%d" % [axis, a, b]] = label
	_reposition(axis, a, b)

func _face_rotation(axis: int) -> Vector3:
	match axis:
		0: return Vector3(0, PI / 2.0, 0)   # X+ 면을 바라보도록 회전
		1: return Vector3(-PI / 2.0, 0, 0)  # Y+ 면을 바라보도록 회전
		_: return Vector3.ZERO              # Z+ 면 (기본 방향과 일치)

func _reposition(axis: int, a: int, b: int) -> void:
	var label: Label3D = _labels["%d,%d,%d" % [axis, a, b]]
	var n := _model.size
	var half := (n - 1) * BlockGrid.STEP / 2.0

	var front := _frontmost_intact(axis, a, b)
	var depth := front if front != -1 else n - 1   # 전부 제거되면 바깥 경계로 폴백
	var face := depth * BlockGrid.STEP - half + BlockGrid.BLOCK_SIZE / 2.0 + LABEL_OFFSET

	match axis:
		0: label.position = Vector3(face, a * BlockGrid.STEP - half, b * BlockGrid.STEP - half)
		1: label.position = Vector3(a * BlockGrid.STEP - half, face, b * BlockGrid.STEP - half)
		2: label.position = Vector3(a * BlockGrid.STEP - half, b * BlockGrid.STEP - half, face)

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

func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.005
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	return label
