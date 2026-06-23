# scripts/ClueDisplay.gd
class_name ClueDisplay
extends Node3D

const LABEL_OFFSET := 1.0   # 격자 면 바깥쪽 거리

func setup(model: PuzzleModel) -> void:
	var n := model.size
	var half := (n - 1) * BlockGrid.STEP / 2.0
	var edge := half + BlockGrid.BLOCK_SIZE / 2.0 + LABEL_OFFSET

	# X+ 면 — X축 클루 (axis=0, index_a=y, index_b=z)
	for z in n:
		for y in n:
			var clue := model.get_clue(0, y, z)
			if clue == 0:
				continue
			var label := _make_label(str(clue))
			label.position = Vector3(edge, y * BlockGrid.STEP - half, z * BlockGrid.STEP - half)
			add_child(label)

	# Y+ 면 — Y축 클루 (axis=1, index_a=x, index_b=z)
	for z in n:
		for x in n:
			var clue := model.get_clue(1, x, z)
			if clue == 0:
				continue
			var label := _make_label(str(clue))
			label.position = Vector3(x * BlockGrid.STEP - half, edge, z * BlockGrid.STEP - half)
			add_child(label)

	# Z+ 면 — Z축 클루 (axis=2, index_a=x, index_b=y)
	for y in n:
		for x in n:
			var clue := model.get_clue(2, x, y)
			if clue == 0:
				continue
			var label := _make_label(str(clue))
			label.position = Vector3(x * BlockGrid.STEP - half, y * BlockGrid.STEP - half, edge)
			add_child(label)

func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	return label
