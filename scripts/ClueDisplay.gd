# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.06   # 노출 표면 바깥쪽 거리
const SIGN_POS := 1
const SIGN_NEG := -1

var _model: PuzzleModel
var _labels: Dictionary   # "axis,a,b,sign" -> Label3D

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
	for sign: int in [SIGN_POS, SIGN_NEG]:
		var key := "%d,%d,%d,%d" % [axis, a, b, sign]
		var clue := _model.get_clue(axis, a, b)
		var label := _make_label(str(clue))
		label.rotation = _face_rotation(axis, sign)
		add_child(label)
		_labels[key] = label

	_reposition(axis, a, b)

func _face_rotation(axis: int, sign: int) -> Vector3:
	match axis:
		0: return Vector3(0, PI / 2.0 * sign, 0)                       # X+/X- 면을 바라보도록 회전
		1: return Vector3(-PI / 2.0 * sign, 0, 0)                      # Y+/Y- 면을 바라보도록 회전
		_: return Vector3.ZERO if sign > 0 else Vector3(0, PI, 0)      # Z+ (기본) / Z-

func _reposition(axis: int, a: int, b: int) -> void:
	var n := _model.size
	var half := (n - 1) * BlockGrid.STEP / 2.0

	for sign: int in [SIGN_POS, SIGN_NEG]:
		var key := "%d,%d,%d,%d" % [axis, a, b, sign]
		var label: Label3D = _labels[key]

		var idx := _frontmost_intact(axis, a, b) if sign == SIGN_POS else _backmost_intact(axis, a, b)
		label.visible = idx != -1
		if idx == -1:
			continue   # 라인 전부 제거됨 — 붙을 표면 없음, 숨김

		var base := idx * BlockGrid.STEP - half + sign * BlockGrid.BLOCK_SIZE / 2.0
		var face := base + sign * LABEL_OFFSET

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

func _backmost_intact(axis: int, a: int, b: int) -> int:
	var n := _model.size
	for i in range(n):
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
	label.font_size = 96
	label.pixel_size = 0.0045
	label.modulate = Color.WHITE                       # 어떤 블록 색 위에서도 밝게 튀도록
	label.outline_modulate = Color(0.05, 0.04, 0.03, 1.0)
	label.outline_size = 18                             # 굵은 아웃라인 — 배경 칩 없이도 가독성 확보
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return label
