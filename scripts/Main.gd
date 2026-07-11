# scripts/Main.gd
extends Node3D

const MAX_LIVES := 3
const HOME_SCENE_PATH := "res://Home.tscn"

var _model: PuzzleModel
var _grid: BlockGrid
var _cam: CameraController
var _clues: ClueDisplay
var _gizmo: AxisGizmo
var _hud: HUD
var _lives := MAX_LIVES
var _solved := false
var _elapsed := 0.0

func _ready() -> void:
	_load_and_build()

func _process(delta: float) -> void:
	if _solved or _hud == null:
		return
	_elapsed += delta
	_hud.set_timer_seconds(_elapsed)

func _load_and_build() -> void:
	_lives = MAX_LIVES
	_solved = false
	_elapsed = 0.0

	# 기존 자식 노드 정리 (리셋 시)
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	# 모델
	var raw := FileAccess.get_file_as_string(GameState.selected_puzzle_path)
	_model = PuzzleModel.new()
	_model.load_puzzle(JSON.parse_string(raw))

	# 조명
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-PI / 4.0, PI / 4.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.75, 0.9, 0.95)
	sky_mat.sky_horizon_color = Color(0.84, 0.94, 0.92)
	sky_mat.ground_horizon_color = Color(0.89, 0.96, 0.89)
	sky_mat.ground_bottom_color = Color(0.89, 0.96, 0.89)
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_node.environment = env
	add_child(env_node)

	# 블록 격자
	_grid = BlockGrid.new()
	add_child(_grid)
	_grid.setup(_model)
	_refresh_all_confirmed()

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
	_hud = HUD.new()
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 버튼 반응
	add_child(_hud)
	_hud.set_stage(GameState.stage_number)
	_hud.set_lives(_lives, MAX_LIVES)
	_hud.set_timer_seconds(0.0)
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.home_pressed.connect(_on_home_pressed)

func _on_block_tapped(x: int, y: int, z: int) -> void:
	if _solved:
		return
	if _model.is_confirmed_keep(x, y, z):
		return   # 유지 확정 블록 — 페널티 없이 무시
	var result := _model.remove_block(x, y, z)
	match result:
		PuzzleModel.RemoveResult.OK:
			_grid.remove_block_visual(x, y, z)
			_clues.on_block_removed(x, y, z)
			_refresh_confirmed_lines(x, y, z)
			if _model.is_solved():
				_on_solved()
		PuzzleModel.RemoveResult.WRONG:
			_lives -= 1
			_hud.set_lives(_lives, MAX_LIVES)
			_grid.flash_block_red(x, y, z)
			if _lives <= 0:
				_on_game_over()
		PuzzleModel.RemoveResult.ALREADY_REMOVED:
			pass

func _refresh_all_confirmed() -> void:
	var n := _model.size
	for z in n:
		for y in n:
			for x in n:
				if _model.get_block_state(x, y, z) == PuzzleModel.BlockState.INTACT:
					_grid.set_block_confirmed(x, y, z, _model.is_confirmed_keep(x, y, z))

func _refresh_confirmed_lines(x: int, y: int, z: int) -> void:
	_refresh_line(0, y, z)
	_refresh_line(1, x, z)
	_refresh_line(2, x, y)

func _refresh_line(axis: int, a: int, b: int) -> void:
	var n := _model.size
	for i in n:
		var bx: int
		var by: int
		var bz: int
		match axis:
			0: bx = i; by = a; bz = b
			1: bx = a; by = i; bz = b
			2: bx = a; by = b; bz = i
		if _model.get_block_state(bx, by, bz) == PuzzleModel.BlockState.INTACT:
			_grid.set_block_confirmed(bx, by, bz, _model.is_confirmed_keep(bx, by, bz))

func _on_depth_changed(axis: int, depth: int) -> void:
	_grid.set_depth_filter(axis, depth)

func _on_solved() -> void:
	_solved = true
	_hud.reveal_title(_model.name)
	_hud.show_status("CLEAR!", Color(1.0, 0.82, 0.36))

func _on_game_over() -> void:
	_solved = true   # prevent re-entry during 2s wait
	_hud.show_status("GAME OVER", Color(0.9, 0.3, 0.3))
	await get_tree().create_timer(2.0).timeout
	_hud.hide_status()
	_load_and_build()

func _on_pause_pressed(is_paused: bool) -> void:
	get_tree().paused = is_paused

func _on_home_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HOME_SCENE_PATH)
