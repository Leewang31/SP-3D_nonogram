# scripts/HUD.gd
class_name HUD
extends CanvasLayer

signal pause_pressed(is_paused: bool)
signal home_pressed
signal reset_pressed

const CARD_COLOR := Color(1, 1, 1)
const CARD_SHADOW := Color(0.835, 0.871, 0.902)
const INK := Color(0.259, 0.337, 0.408)      # #42606f
const INK_SOFT := Color(0.427, 0.529, 0.588) # #6d8c9d
const HEART_FULL := Color(1.0, 0.42, 0.42)
const HEART_EMPTY := Color(0.886, 0.776, 0.776)
const STAGE_BADGE := Color(1.0, 0.82, 0.36)

var _stage_label: Label
var _hearts: HBoxContainer
var _title_label: Label
var _timer_label: Label
var _message_label: Label
var _max_lives := 3
var _is_paused := false
var _reset_btn: Button

func _ready() -> void:
	layer = 10
	_build()

func _build() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(18, 54)
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	top_bar.add_child(_make_stage_badge())

	var home_btn := _make_icon_button("⌂")
	home_btn.pressed.connect(func(): home_pressed.emit())
	top_bar.add_child(home_btn)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(70, 0)
	top_bar.add_child(spacer1)

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 4)
	top_bar.add_child(_hearts)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer2)

	_reset_btn = _make_icon_button("↻")
	_reset_btn.disabled = true
	_reset_btn.pressed.connect(func(): reset_pressed.emit())
	top_bar.add_child(_reset_btn)

	top_bar.add_child(_make_icon_button("⚙"))

	var pause_btn := _make_icon_button("❙❙")
	pause_btn.pressed.connect(func():
		_is_paused = not _is_paused
		pause_pressed.emit(_is_paused)
	)
	top_bar.add_child(pause_btn)

	# 미스터리 타이틀 + 타이머
	var title_col := VBoxContainer.new()
	title_col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_col.position = Vector2(0, 108)
	title_col.custom_minimum_size = Vector2(402, 0)
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(title_col)

	var title_pill := PanelContainer.new()
	title_pill.add_theme_stylebox_override("panel", _pill_style(Color(1, 1, 1, 0.7), 16))
	title_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_col.add_child(title_pill)

	_title_label = Label.new()
	_title_label.text = "? ? ?"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", INK_SOFT)
	title_pill.add_child(_title_label)
	title_pill.add_theme_constant_override("margin_left", 20)
	title_pill.add_theme_constant_override("margin_right", 20)
	title_pill.add_theme_constant_override("margin_top", 7)
	title_pill.add_theme_constant_override("margin_bottom", 7)

	var timer_row := HBoxContainer.new()
	timer_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_row.add_theme_constant_override("separation", 6)
	title_col.add_child(timer_row)

	_timer_label = Label.new()
	_timer_label.text = "⏱ 00:00"
	_timer_label.add_theme_font_size_override("font_size", 15)
	_timer_label.add_theme_color_override("font_color", INK_SOFT)
	timer_row.add_child(_timer_label)

	# 클리어 / 게임오버 메시지 (평소 숨김)
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.add_theme_font_size_override("font_size", 30)
	_message_label.visible = false
	add_child(_message_label)

	# 하단 회전 힌트
	var bottom_row := HBoxContainer.new()
	bottom_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_row.position = Vector2(0, -72)
	bottom_row.custom_minimum_size = Vector2(402, 0)
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bottom_row)

	var hint_pill := PanelContainer.new()
	hint_pill.add_theme_stylebox_override("panel", _pill_style(Color(1, 1, 1, 0.72), 22))
	bottom_row.add_child(hint_pill)

	var hint_label := Label.new()
	hint_label.text = "⟲  바깥쪽을 드래그해 회전"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", INK_SOFT)
	hint_pill.add_child(hint_label)
	hint_pill.add_theme_constant_override("margin_left", 20)
	hint_pill.add_theme_constant_override("margin_right", 20)
	hint_pill.add_theme_constant_override("margin_top", 11)
	hint_pill.add_theme_constant_override("margin_bottom", 11)

	set_lives(_max_lives, _max_lives)

func _make_stage_badge() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	card.add_theme_constant_override("margin_left", 10)
	card.add_theme_constant_override("margin_right", 14)
	card.add_theme_constant_override("margin_top", 8)
	card.add_theme_constant_override("margin_bottom", 8)

	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = STAGE_BADGE
	badge_style.corner_radius_top_left = 10
	badge_style.corner_radius_top_right = 10
	badge_style.corner_radius_bottom_left = 10
	badge_style.corner_radius_bottom_right = 10
	badge_style.content_margin_left = 8
	badge_style.content_margin_right = 8
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_style)
	row.add_child(badge)

	_stage_label = Label.new()
	_stage_label.text = "1"
	_stage_label.add_theme_font_size_override("font_size", 15)
	_stage_label.add_theme_color_override("font_color", Color(0.478, 0.353, 0.071))
	badge.add_child(_stage_label)

	var name_label := Label.new()
	name_label.text = "스테이지"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", INK)
	row.add_child(name_label)

	return card

func _make_icon_button(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(44, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", INK_SOFT)
	btn.add_theme_stylebox_override("normal", _card_style())
	btn.add_theme_stylebox_override("hover", _card_style())
	btn.add_theme_stylebox_override("pressed", _card_style())
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = CARD_SHADOW
	style.shadow_size = 4
	return style

func _pill_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func set_stage(n: int) -> void:
	_stage_label.text = str(n)

func set_lives(current: int, max_lives: int) -> void:
	_max_lives = max_lives
	for child in _hearts.get_children():
		child.free()
	for i in max_lives:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", 22)
		heart.add_theme_color_override("font_color", HEART_FULL if i < current else HEART_EMPTY)
		_hearts.add_child(heart)

func set_timer_seconds(seconds: float) -> void:
	var total := int(seconds)
	var mm := total / 60
	var ss := total % 60
	_timer_label.text = "⏱ %02d:%02d" % [mm, ss]

func reveal_title(text: String) -> void:
	_title_label.text = text

func show_status(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true

func hide_status() -> void:
	_message_label.visible = false

func set_reset_enabled(enabled: bool) -> void:
	_reset_btn.disabled = not enabled
