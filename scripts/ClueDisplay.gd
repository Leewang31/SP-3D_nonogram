# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 0.08   # 노출 표면 바깥쪽 거리
const CHIP_OFFSET := 0.02    # 칩은 라벨보다 안쪽 (표면에 더 밀착) — 간격을 넉넉히 벌려 완만한 각도에서 z-fighting 방지
const CHIP_SIZE := 0.46
const SIGN_POS := 1
const SIGN_NEG := -1

static var _chip_texture: ImageTexture

var _model: PuzzleModel
var _labels: Dictionary   # "axis,a,b,sign" -> Label3D
var _chips: Dictionary    # "axis,a,b,sign" -> MeshInstance3D

static func _get_chip_texture() -> ImageTexture:
	if _chip_texture == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size / 2.0, size / 2.0)
		var radius := size / 2.0 - 2.0
		var border := 4.0
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
				var col := Color(0, 0, 0, 0)
				if d <= radius:
					# 불투명한 흰 배경 + 진한 테두리 — 어떤 블록 색 위에서도 대비 확보
					col = Color(0.18, 0.14, 0.08, 0.95) if d >= radius - border else Color(1.0, 0.99, 0.96, 0.98)
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
	for sign: int in [SIGN_POS, SIGN_NEG]:
		var key := "%d,%d,%d,%d" % [axis, a, b, sign]
		var clue := _model.get_clue(axis, a, b)
		var label := _make_label(str(clue))
		label.rotation = _face_rotation(axis, sign)
		add_child(label)
		_labels[key] = label

		var chip := _make_chip()
		chip.rotation = _face_rotation(axis, sign)
		add_child(chip)
		_chips[key] = chip

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
		var chip: MeshInstance3D = _chips[key]

		var idx := _frontmost_intact(axis, a, b) if sign == SIGN_POS else _backmost_intact(axis, a, b)
		label.visible = idx != -1
		chip.visible = idx != -1
		if idx == -1:
			continue   # 라인 전부 제거됨 — 붙을 표면 없음, 숨김

		var base := idx * BlockGrid.STEP - half + sign * BlockGrid.BLOCK_SIZE / 2.0
		var face := base + sign * LABEL_OFFSET
		var chip_face := base + sign * CHIP_OFFSET

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
	label.font_size = 64
	label.pixel_size = 0.0052
	label.modulate = Color(0.12, 0.1, 0.08)     # 밝은 칩 배경 위 진한 텍스트 — 대비 강화
	label.outline_modulate = Color(1.0, 1.0, 1.0, 0.9)
	label.outline_size = 10
	label.render_priority = 1   # 칩(배경 원판)보다 항상 나중에 그려지도록 강제 — 완만한 각도에서 깊이 정렬 흔들림 방지
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return label
