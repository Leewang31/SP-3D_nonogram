# scripts/Home.gd
extends Control

const MAIN_SCENE_PATH := "res://Main.tscn"

const PUZZLE_PATHS := [
	"res://puzzles/tutorial_01.json",
	"res://puzzles/puzzle_02.json",
	"res://puzzles/puzzle_03.json",
	"res://puzzles/puzzle_04.json",
	"res://puzzles/puzzle_05.json",
	"res://puzzles/puzzle_06.json",
	"res://puzzles/puzzle_07.json",
	"res://puzzles/puzzle_08.json",
	"res://puzzles/puzzle_09.json",
	"res://puzzles/puzzle_10.json",
	"res://puzzles/puzzle_11.json",
]

const CARD_COLOR := Color(1, 1, 1)
const CARD_SHADOW := Color(0.835, 0.871, 0.902)
const INK := Color(0.259, 0.337, 0.408)
const INK_SOFT := Color(0.427, 0.529, 0.588)
const STAGE_BADGE := Color(1.0, 0.82, 0.36)

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.84, 0.94, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "Picross 3D"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0, 64)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "스테이지를 선택하세요"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position = Vector2(0, 108)
	add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 150
	scroll.offset_bottom = -30
	scroll.offset_left = 24
	scroll.offset_right = -24
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for i in PUZZLE_PATHS.size():
		var path: String = PUZZLE_PATHS[i]
		var stage := i + 1
		var info := _read_puzzle_info(path)
		grid.add_child(_make_stage_card(stage, info, path))

func _read_puzzle_info(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	var data: Dictionary = JSON.parse_string(raw)
	var block_count := 0
	var solution: Array = data.get("solution", [])
	for layer in solution:
		for row in layer:
			for v in row:
				block_count += int(v)
	return {
		"name": data.get("name", data.get("id", "?")),
		"block_count": block_count,
	}

func _make_stage_card(stage: int, info: Dictionary, path: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 130)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(18)
	style.shadow_color = CARD_SHADOW
	style.shadow_size = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = STAGE_BADGE
	badge_style.set_corner_radius_all(10)
	badge_style.content_margin_left = 10
	badge_style.content_margin_right = 10
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var badge_label := Label.new()
	badge_label.text = str(stage)
	badge_label.add_theme_font_size_override("font_size", 15)
	badge_label.add_theme_color_override("font_color", Color(0.478, 0.353, 0.071))
	badge.add_child(badge_label)
	col.add_child(badge)

	var name_label := Label.new()
	name_label.text = String(info["name"])
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", INK)
	col.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "%d 블록" % int(info["block_count"])
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", INK_SOFT)
	col.add_child(count_label)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_stage_selected.bind(path, stage))
	card.add_child(btn)

	return card

func _on_stage_selected(path: String, stage: int) -> void:
	GameState.select(path, stage)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
