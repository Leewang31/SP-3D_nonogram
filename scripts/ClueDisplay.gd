# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.06   # 블록 표면에서 띄우는 거리
const SIGN_POS := 1
const SIGN_NEG := -1
const SUPERSCRIPT_DIGITS := {2: "²", 3: "³", 4: "⁴", 5: "⁵", 6: "⁶", 7: "⁷", 8: "⁸", 9: "⁹"}

var _model: PuzzleModel

# 라벨을 그리드 바깥 경계가 아니라 각 블록 표면에 직접 부착 — 블록이 depth 필터/제거로
# 숨겨지면 자식인 라벨도 자동으로 같이 숨겨져(Node3D visible 상속) "허공에 뜬 숫자" 문제가
# 구조적으로 발생하지 않음. 같은 라인의 다른 블록에는 같은 클루가 중복 부착되지만
# 항상 그 라인에서 가장 앞쪽(카메라 쪽) 노출 블록만 불투명 큐브에 가려지지 않고 보임.
func setup(model: PuzzleModel, grid: BlockGrid) -> void:
	_model = model
	var n := model.size
	for z in n:
		for y in n:
			for x in n:
				var block := grid.get_block(x, y, z)
				_add_block_labels(block, 0, y, z)
				_add_block_labels(block, 1, x, z)
				_add_block_labels(block, 2, x, y)

func _add_block_labels(block: Node3D, axis: int, a: int, b: int) -> void:
	var clue := _model.get_clue(axis, a, b)
	var groups := _model.get_group_count(axis, a, b)
	var text := _format_clue_text(clue, groups)
	for sign: int in [SIGN_POS, SIGN_NEG]:
		var label := _make_label(text)
		_apply_face_orientation(label, axis, sign)

		var offset := sign * (BlockGrid.BLOCK_SIZE / 2.0 + LABEL_OFFSET)
		match axis:
			0: label.position = Vector3(offset, 0, 0)
			1: label.position = Vector3(0, offset, 0)
			2: label.position = Vector3(0, 0, offset)

		block.add_child(label)

# Label3D의 가독면은 로컬 +Z(기존 Z+/기본 케이스로 검증된 기준). X/Z 측면 라벨은
# looking_at()으로 바깥쪽 법선을 향해 견고하게 정렬 — 기존에 축별로 손으로 유도한
# 오일러각 공식이 X-/Z- 면에서 라벨 뒷면(거울에 비친 좌우反전 글자)을 보여주는
# 버그를 유발해(2026-07-18 QA 스크린샷 제보), looking_at 기반으로 교체.
# Y(상/하)면은 법선이 world up과 평행해 looking_at의 up 기준이 성립하지 않으므로
# 기존 X축 회전 방식을 그대로 유지.
func _apply_face_orientation(label: Label3D, axis: int, sign: int) -> void:
	if axis == 1:
		label.rotation = Vector3(-PI / 2.0 * sign, 0, 0)
		return
	var normal := Vector3(sign, 0, 0) if axis == 0 else Vector3(0, 0, sign)
	var t := label.transform
	t.basis = Basis.looking_at(-normal, Vector3.UP)
	label.transform = t

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
