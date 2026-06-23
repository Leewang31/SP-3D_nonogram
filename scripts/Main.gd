# scripts/Main.gd
extends Node3D

const MAX_PENALTY := 5
const PUZZLE_PATH := "res://puzzles/tutorial_01.json"

var _model: PuzzleModel
var _grid: BlockGrid
var _cam: CameraController
var _clues: ClueDisplay
var _gizmo: AxisGizmo
var _penalty_label: Label
var _penalty := 0
var _solved := false

func _ready() -> void:
	_load_and_build()

func _load_and_build() -> void:
	_penalty = 0
	_solved = false

	# 기존 자식 노드 정리 (리셋 시)
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	# 모델
	var raw := FileAccess.get_file_as_string(PUZZLE_PATH)
	_model = PuzzleModel.new()
	_model.load_puzzle(JSON.parse_string(raw))

	# 조명
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-PI / 4.0, PI / 4.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.15)
	env_node.environment = env
	add_child(env_node)

	# 블록 격자
	_grid = BlockGrid.new()
	add_child(_grid)
	_grid.setup(_model)

	# 힌트 숫자
	_clues = ClueDisplay.new()
	add_child(_clues)
	_clues.setup(_model)

	# 축 기즈모
	_gizmo = AxisGizmo.new()
	add_child(_gizmo)
	_gizmo.setup(_model.size)
	_gizmo.depth_changed.connect(_on_depth_changed)

	# 카메라
	_cam = CameraController.new()
	add_child(_cam)
	_cam.block_tapped.connect(_on_block_tapped)
	_cam.gizmo_tapped.connect(_gizmo.on_axis_tapped)

	# UI
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_penalty_label = Label.new()
	_penalty_label.position = Vector2(20, 20)
	_penalty_label.add_theme_font_size_override("font_size", 36)
	_penalty_label.modulate = Color.WHITE
	canvas.add_child(_penalty_label)
	_update_penalty_label()

func _on_block_tapped(x: int, y: int, z: int) -> void:
	if _solved:
		return
	var result := _model.remove_block(x, y, z)
	match result:
		PuzzleModel.RemoveResult.OK:
			_grid.remove_block_visual(x, y, z)
			if _model.is_solved():
				_on_solved()
		PuzzleModel.RemoveResult.WRONG:
			_penalty += 1
			_update_penalty_label()
			_grid.flash_block_red(x, y, z)
			if _penalty >= MAX_PENALTY:
				_on_game_over()
		PuzzleModel.RemoveResult.ALREADY_REMOVED:
			pass

func _on_depth_changed(axis: int, depth: int) -> void:
	_grid.set_depth_filter(axis, depth)

func _on_solved() -> void:
	_solved = true
	_penalty_label.text = "CLEAR!"
	_penalty_label.modulate = Color.YELLOW

func _on_game_over() -> void:
	_solved = true   # prevent re-entry during 2s wait
	_penalty_label.text = "GAME OVER — Resetting..."
	await get_tree().create_timer(2.0).timeout
	_load_and_build()

func _update_penalty_label() -> void:
	_penalty_label.text = "Penalties: %d / %d" % [_penalty, MAX_PENALTY]
