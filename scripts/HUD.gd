# scripts/HUD.gd
class_name HUD
extends CanvasLayer

signal pause_pressed(is_paused: bool)
signal home_pressed
signal reset_pressed

const CARD_COLOR := Color(1, 1, 1)
const CARD_SHADOW := Color(0.835, 0.871, 0.902)
const INK := Color(0.259, 0.337, 0.408)      # #42606f
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
	# 좌/중앙/우 3그룹을 각각 화면 기준으로 독립 앵커링 — 한 HBoxContainer에 순차 배치하던
	# 이전 방식은 고정폭 스페이서(70px) 누적이 좁은 화면 폭을 넘기면 오른쪽 버튼이 잘려나감
	# (2026-07-18 스크린샷 QA로 발견). 그룹별 앵커는 화면 폭과 무관하게 항상 안전하게 맞음.
	var left_group := HBoxContainer.new()
	left_group.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_group.position = Vector2(16, 53)
	left_group.add_theme_constant_override("separation", 8)
	add_child(left_group)

	left_group.add_child(_make_stage_badge())

	var home_btn := _make_icon_button("⌂")
	home_btn.pressed.connect(func(): home_pressed.emit())
	left_group.add_child(home_btn)

	# title_col/bottom_row와 동일한 패턴: TOP_WIDE 앵커로 화면 폭 전체를 차지시키고
	# alignment=CENTER로 자식(하트)만 가운데 정렬 — 화면 폭에 의존하지 않음.
	var center_group := HBoxContainer.new()
	center_group.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_group.position = Vector2(0, 62)
	center_group.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center_group)

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 4)
	center_group.add_child(_hearts)

	var right_group := HBoxContainer.new()
	right_group.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_group.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # 오른쪽 끝 고정, 폭은 왼쪽으로 확장
	right_group.position = Vector2(-16, 53)
	right_group.add_theme_constant_override("separation", 8)
	add_child(right_group)

	_reset_btn = _make_icon_button("↻")
	_reset_btn.disabled = true
	_reset_btn.pressed.connect(func(): reset_pressed.emit())
	right_group.add_child(_reset_btn)

	var pause_btn := _make_primary_icon_button("❙❙")
	pause_btn.pressed.connect(func():
		_is_paused = not _is_paused
		pause_pressed.emit(_is_paused)
	)
	right_group.add_child(pause_btn)

	# 미스터리 타이틀 + 타이머
	var title_col := VBoxContainer.new()
	title_col.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_col.position = Vector2(0, 108)
	title_col.custom_minimum_size = Vector2(402, 0)
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(title_col)

	var title_pill := PanelContainer.new()
	title_pill.add_theme_stylebox_override("panel", _pill_style(16))
	title_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_col.add_child(title_pill)

	_title_label = Label.new()
	_title_label.text = "? ? ?"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", INK)
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
	_timer_label.add_theme_color_override("font_color", INK)
	timer_row.add_child(_timer_label)

	# 클리어 / 게임오버 메시지 (평소 숨김) — 3D 씬 위에 바로 얹히므로 아웃라인 필수
	# (배경 팔레트가 파스텔이라 아웃라인 없으면 CLEAR! 등 밝은 색 텍스트가 묻힘)
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.add_theme_font_size_override("font_size", 30)
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
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
	hint_pill.add_theme_stylebox_override("panel", _pill_style(22))
	bottom_row.add_child(hint_pill)

	var hint_label := Label.new()
	hint_label.text = "⟲  바깥쪽을 드래그해 회전"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", INK)
	hint_pill.add_child(hint_label)
	hint_pill.add_theme_constant_override("margin_left", 20)
	hint_pill.add_theme_constant_override("margin_right", 20)
	hint_pill.add_theme_constant_override("margin_top", 11)
	hint_pill.add_theme_constant_override("margin_bottom", 11)

	set_lives(_max_lives, _max_lives)

func _make_stage_badge() -> PanelContainer:
	# "스테이지" 텍스트 라벨을 감싸던 흰 카드 제거, 숫자 칩만 표시 — 화면 컨텍스트상
	# 중복 정보였고 상단바 폭 절약에도 도움 (Figma 목업 2026-07-18 반영)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(36, 36)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = STAGE_BADGE
	badge_style.corner_radius_top_left = 12
	badge_style.corner_radius_top_right = 12
	badge_style.corner_radius_bottom_left = 12
	badge_style.corner_radius_bottom_right = 12
	badge.add_theme_stylebox_override("panel", badge_style)

	_stage_label = Label.new()
	_stage_label.text = "1"
	_stage_label.add_theme_font_size_override("font_size", 15)
	_stage_label.add_theme_color_override("font_color", Color(0.478, 0.353, 0.071))
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_stage_label)

	return badge

func _make_icon_button(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(38, 38)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.45))
	btn.add_theme_stylebox_override("normal", _card_style())
	btn.add_theme_stylebox_override("hover", _card_style())
	btn.add_theme_stylebox_override("pressed", _card_style())
	btn.add_theme_stylebox_override("disabled", _card_style(0.55))
	btn.focus_mode = Control.FOCUS_NONE
	return btn

# 자주 쓰는 주 액션(일시정지)을 나머지 보조 버튼과 시각적으로 구분하기 위한
# 채워진 스타일 — Figma 목업(2026-07-18)의 버튼 위계 구분 반영
func _make_primary_icon_button(glyph: String) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(38, 38)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var style := _card_style()
	style.bg_color = INK
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _card_style(alpha: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CARD_COLOR.r, CARD_COLOR.g, CARD_COLOR.b, alpha)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = CARD_SHADOW
	style.shadow_size = 4
	return style

# 반투명 배경이 민트색 배경과 거의 안 구분되던 문제 수정 — 불투명 배경 + 테두리로
# 경계를 뚜렷하게 (Figma 목업 2026-07-18 대비 개선 반영)
func _pill_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.92)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = CARD_SHADOW
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
	_title_label.text = text if text != "" else "완성!"
	_title_label.add_theme_color_override("font_color", INK)

func show_status(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.visible = true

func hide_status() -> void:
	_message_label.visible = false

func set_reset_enabled(enabled: bool) -> void:
	_reset_btn.disabled = not enabled
