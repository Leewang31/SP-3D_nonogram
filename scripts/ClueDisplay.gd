# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.06   # 그리드 바깥쪽 경계에서 떨어진 거리
const SIGN_POS := 1
const SIGN_NEG := -1
const SUPERSCRIPT_DIGITS := {2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷", 8: "⁸", 9: "⁹"}

var _model: PuzzleModel

func setup(model: PuzzleModel) -> void:
	_model = model
	var n := model.size
	var half := (n - 1) * BlockGrid.STEP / 2.0
	var edge := half + BlockGrid.BLOCK_SIZE / 2.0

	for z in n:
		for y in n:
			_add_label(0, y, z, half, edge)
	for z in n:
		for x in n:
			_add_label(1, x, z, half, edge)
	for y in n:
		for x in n:
			_add_label(2, x, y, half, edge)

func on_block_removed(_x: int, _y: int, _z: int) -> void:
	pass   # 클루 위치는 그리드 바깥 경계에 고정 — 블록 상태와 무관해 갱신 불필요

func _add_label(axis: int, a: int, b: int, half: float, edge: float) -> void:
	var clue := _model.get_clue(axis, a, b)
	var groups := _model.get_group_count(axis, a, b)
	var text := _format_clue_text(clue, groups)
	for sign: int in [SIGN_POS, SIGN_NEG]:
		var label := _make_label(text)
		label.rotation = _face_rotation(axis, sign)

		var face := sign * (edge + LABEL_OFFSET)
		match axis:
			0: label.position = Vector3(face, a * BlockGrid.STEP - half, b * BlockGrid.STEP - half)
			1: label.position = Vector3(a * BlockGrid.STEP - half, face, b * BlockGrid.STEP - half)
			2: label.position = Vector3(a * BlockGrid.STEP - half, b * BlockGrid.STEP - half, face)

		add_child(label)

func _face_rotation(axis: int, sign: int) -> Vector3:
	match axis:
		0: return Vector3(0, PI / 2.0 * sign, 0)                       # X+/X- 면을 바라보도록 회전
		1: return Vector3(-PI / 2.0 * sign, 0, 0)                      # Y+/Y- 면을 바라보도록 회전
		_: return Vector3.ZERO if sign > 0 else Vector3(0, PI, 0)      # Z+ (기본) / Z-

func _format_clue_text(clue: int, groups: int) -> String:
	if groups < 2:
		return str(clue)
	return str(clue) + SUPERSCRIPT_DIGITS.get(groups, "⁺")   # 덩어리 2개 이상이면 위첨자로 정확한 개수 표시

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
