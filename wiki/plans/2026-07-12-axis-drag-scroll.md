# 레이어 심도 드래그 스크롤 네비게이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `AxisGizmo`의 탭-사이클 depth 제어를 드래그 스크롤로 교체하고, 한 축이 활성화된 동안 다른 두 축을 잠그는 인터랙션을 구현한다.

**Architecture:** `AxisGizmo`가 화면-공간 드래그 델타를 축별 depth 정수로 변환하는 상태 기계를 갖고, `CameraController`가 터치 다운 시점에 화살표 레이캐스트로 오빗/축-드래그 제스처 오너십을 분기해 신호로 전달한다. `HUD`에 리셋 버튼을 추가하고 `Main.gd`가 전부 배선한다.

**Tech Stack:** Godot 4.6, GDScript, `InputEventScreenTouch`/`InputEventScreenDrag`, `PhysicsRayQueryParameters3D`.

## Global Constraints

- 화살표는 드래그 전용 — 탭(이동 없는 터치+해제)은 depth를 바꾸지 않는다.
- 기본 임계값 `STEP_PIXELS := 60.0` (화면 픽셀, 상수로 분리해 튜닝 가능)
- depth는 `[0, size-1]`로 클램프 — 경계를 넘는 드래그는 누적을 0으로 리셋한다.
- 한 축이 활성화(잠금)된 동안 나머지 두 화살표는 `visible=false` + `collision_layer=0`.
- 손을 뗀 뒤에도 활성 축은 유지된다 — 리셋 버튼을 눌러야 대기 상태로 복귀.
- 리셋 버튼은 HUD 고정 버튼, 어떤 축이든 활성화됐을 때만 활성화된다.
- 핀치 줌은 축 드래그 중 두 번째 손가락이 닿아도 시작되지 않는다.
- 순수 계산 로직(픽셀 누적→스텝 변환)은 노드 의존 없는 `static func`으로 분리해 헤드리스 테스트.

---

## File Map

| 파일 | 역할 |
|---|---|
| `scripts/AxisGizmo.gd` | 드래그 상태 기계로 전면 재작성 — 탭-사이클 제거 |
| `scripts/CameraController.gd` | 터치다운 시 화살표 레이캐스트로 제스처 오너십 분기 |
| `scripts/HUD.gd` | 리셋 아이콘 버튼 추가 |
| `scripts/Main.gd` | 새 신호 배선 |
| `tests/test_axis_gizmo.gd` | 픽셀→스텝 변환 순수 함수 헤드리스 테스트 (신규) |

---

## Task 1: AxisGizmo 픽셀→레이어 변환 순수 함수 (TDD)

**Files:**
- Create: `tests/test_axis_gizmo.gd`
- Modify: `scripts/AxisGizmo.gd`

**Interfaces:**
- Produces: `static func AxisGizmo._consume_steps(accum: float, delta: float, step_pixels: float) -> Dictionary`
  - 반환: `{"remainder": float, "steps": int}` — `steps`는 이번 호출로 발생한 정수 레이어 이동량(음수 가능), `remainder`는 다음 호출로 이월할 누적값.

- [ ] **Step 1: 테스트 파일 작성**

```gdscript
# tests/test_axis_gizmo.gd
extends SceneTree

const AxisGizmo = preload("res://scripts/AxisGizmo.gd")

var _passed := 0
var _failed := 0

func _init() -> void:
	_test_single_step_forward()
	_test_carries_remainder()
	_test_accumulates_across_calls()
	_test_single_step_backward()
	_test_no_step_below_threshold()
	_test_multi_step_in_one_call()

	print("\nResults: %d passed, %d failed" % [_passed, _failed])
	quit(_failed)

func _assert(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("PASS: " + name)
	else:
		_failed += 1
		print("FAIL: " + name)

func _test_single_step_forward() -> void:
	var r := AxisGizmo._consume_steps(0.0, 65.0, 60.0)
	_assert(r["steps"] == 1, "65px delta with 60px step -> 1 step")
	_assert(is_equal_approx(r["remainder"], 5.0), "remainder carries the leftover 5px")

func _test_carries_remainder() -> void:
	var r := AxisGizmo._consume_steps(5.0, 58.0, 60.0)
	_assert(r["steps"] == 1, "accumulated 5+58=63px -> 1 step")
	_assert(is_equal_approx(r["remainder"], 3.0), "remainder is 3px after the step")

func _test_accumulates_across_calls() -> void:
	var accum := 0.0
	var total_steps := 0
	for delta in [20.0, 20.0, 25.0]:
		var r := AxisGizmo._consume_steps(accum, delta, 60.0)
		accum = r["remainder"]
		total_steps += r["steps"]
	_assert(total_steps == 1, "three small drags summing 65px -> 1 step total")
	_assert(is_equal_approx(accum, 5.0), "5px remainder left after the step")

func _test_single_step_backward() -> void:
	var r := AxisGizmo._consume_steps(0.0, -65.0, 60.0)
	_assert(r["steps"] == -1, "-65px delta -> -1 step")
	_assert(is_equal_approx(r["remainder"], -5.0), "remainder is -5px")

func _test_no_step_below_threshold() -> void:
	var r := AxisGizmo._consume_steps(0.0, 40.0, 60.0)
	_assert(r["steps"] == 0, "40px delta below 60px threshold -> 0 steps")
	_assert(is_equal_approx(r["remainder"], 40.0), "remainder equals the full delta")

func _test_multi_step_in_one_call() -> void:
	var r := AxisGizmo._consume_steps(0.0, 145.0, 60.0)
	_assert(r["steps"] == 2, "145px delta -> 2 steps in a single call (fast flick)")
	_assert(is_equal_approx(r["remainder"], 25.0), "remainder is 25px after 2 steps")
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

Run: `godot --headless --script tests/test_axis_gizmo.gd`
Expected: 에러 (`_consume_steps` 함수 없음) 또는 전부 FAIL.

- [ ] **Step 3: `AxisGizmo.gd`에 `_consume_steps` 추가**

`scripts/AxisGizmo.gd`의 `class_name AxisGizmo` / `extends Node3D` 선언 바로 아래, 기존 `signal depth_changed(axis: int, depth: int)` 다음 줄에 추가:

```gdscript
static func _consume_steps(accum: float, delta: float, step_pixels: float) -> Dictionary:
	var total := accum + delta
	var steps := int(total / step_pixels)
	var remainder := total - float(steps) * step_pixels
	return {"remainder": remainder, "steps": steps}
```

- [ ] **Step 4: 테스트 실행 — PASS 확인**

Run: `godot --headless --script tests/test_axis_gizmo.gd`
Expected:
```
PASS: 65px delta with 60px step -> 1 step
PASS: remainder carries the leftover 5px
PASS: accumulated 5+58=63px -> 1 step
PASS: remainder is 3px after the step
PASS: three small drags summing 65px -> 1 step total
PASS: 5px remainder left after the step
PASS: -65px delta -> -1 step
PASS: remainder is -5px
PASS: 40px delta below 60px threshold -> 0 steps
PASS: remainder equals the full delta
PASS: 145px delta -> 2 steps in a single call (fast flick)
PASS: remainder is 25px after 2 steps
Results: 12 passed, 0 failed
```

- [ ] **Step 5: 커밋**

```bash
git add tests/test_axis_gizmo.gd scripts/AxisGizmo.gd
git commit -m "feat: add pixel-to-layer-step conversion for axis drag scroll"
```

---

## Task 2: AxisGizmo 드래그 API로 전면 재작성

**Files:**
- Modify: `scripts/AxisGizmo.gd`

**Interfaces:**
- Consumes: `AxisGizmo._consume_steps` (Task 1), `BlockGrid.STEP`, `BlockGrid.BLOCK_SIZE`
- Produces:
  - `signal depth_changed(axis: int, depth: int)` (기존 시그니처 유지)
  - `signal axis_lock_changed(is_locked: bool)` (신규)
  - `func setup(puzzle_size: int) -> void` (기존 시그니처 유지)
  - `func begin_drag(axis: int) -> void`
  - `func update_drag(screen_delta: Vector2) -> void`
  - `func end_drag() -> void`
  - `func reset() -> void`
  - 제거: `func on_axis_tapped(axis: int) -> void`

`scripts/AxisGizmo.gd` 전체를 아래 내용으로 교체 (Task 1에서 추가한 `_consume_steps`는 그대로 유지):

- [ ] **Step 1: `scripts/AxisGizmo.gd` 전체 교체**

```gdscript
# scripts/AxisGizmo.gd
class_name AxisGizmo
extends Node3D

signal depth_changed(axis: int, depth: int)
signal axis_lock_changed(is_locked: bool)

const STEP_PIXELS := 60.0

var _puzzle_size: int
var _depths: Array[int] = [-1, -1, -1]   # X, Y, Z
var _roots: Array[Node3D] = [null, null, null]
var _bodies: Array[StaticBody3D] = [null, null, null]
var _active_axis := -1
var _drag_accum := 0.0

static func _consume_steps(accum: float, delta: float, step_pixels: float) -> Dictionary:
	var total := accum + delta
	var steps := int(total / step_pixels)
	var remainder := total - float(steps) * step_pixels
	return {"remainder": remainder, "steps": steps}

func setup(puzzle_size: int) -> void:
	_puzzle_size = puzzle_size
	var half := (puzzle_size - 1) * BlockGrid.STEP / 2.0
	var edge := half + BlockGrid.BLOCK_SIZE / 2.0

	_add_arrow(0, Vector3(edge + 1.5, 0.0, 0.0), Color.RED,   Vector3(0, 0, -PI/2))
	_add_arrow(1, Vector3(0.0, edge + 1.5, 0.0), Color.GREEN, Vector3.ZERO)
	_add_arrow(2, Vector3(0.0, 0.0, edge + 1.5), Color.BLUE,  Vector3(PI/2, 0, 0))

func _add_arrow(axis: int, pos: Vector3, color: Color, rotation_euler: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos

	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.8
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.18
	mesh.mesh = cyl
	mesh.rotation = rotation_euler
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	root.add_child(mesh)

	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = 0.8
	shape.radius = 0.18
	col.shape = shape
	col.rotation = rotation_euler
	body.add_child(col)
	body.set_meta("gizmo_axis", axis)
	root.add_child(body)

	add_child(root)
	_roots[axis] = root
	_bodies[axis] = body

func begin_drag(axis: int) -> void:
	if _active_axis != -1:
		return   # 이미 다른 축이 활성 — 새 grab 무시
	_active_axis = axis
	_drag_accum = 0.0
	for a in 3:
		if a != axis:
			_roots[a].visible = false
			_bodies[a].collision_layer = 0
	axis_lock_changed.emit(true)

func update_drag(screen_delta: Vector2) -> void:
	if _active_axis == -1:
		return
	var dir := _screen_direction(_active_axis)
	if dir == Vector2.ZERO:
		return
	var scalar := screen_delta.dot(dir)
	var result := _consume_steps(_drag_accum, scalar, STEP_PIXELS)
	var remainder: float = result["remainder"]
	var steps: int = result["steps"]
	if steps == 0:
		_drag_accum = remainder
		return
	var current := _depths[_active_axis]
	var target := current + steps
	var clamped := clampi(target, 0, _puzzle_size - 1)
	_drag_accum = 0.0 if clamped != target else remainder
	if clamped != current:
		_depths[_active_axis] = clamped
		depth_changed.emit(_active_axis, clamped)

func end_drag() -> void:
	_drag_accum = 0.0

func reset() -> void:
	if _active_axis == -1:
		return
	var axis := _active_axis
	_depths[axis] = -1
	depth_changed.emit(axis, -1)
	for a in 3:
		_roots[a].visible = true
		_bodies[a].collision_layer = 2
	_active_axis = -1
	_drag_accum = 0.0
	axis_lock_changed.emit(false)

func _screen_direction(axis: int) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var root := _roots[axis]
	var world_dir := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)][axis]
	var p0 := cam.unproject_position(root.global_position)
	var p1 := cam.unproject_position(root.global_position + world_dir * 0.5)
	var d := p1 - p0
	if d.length() < 0.001:
		return Vector2.ZERO
	return d.normalized()
```

- [ ] **Step 2: 헤드리스 파싱 확인**

`AxisGizmo`는 노드 의존이라 인스턴스화 테스트는 불가하지만, 정적 파싱 에러는 확인 가능:

```bash
cat > scripts/_check_gizmo_tmp.gd << 'EOF'
extends SceneTree
const AG = preload("res://scripts/AxisGizmo.gd")
func _init():
    print("parsed OK")
    quit()
EOF
godot --headless --script scripts/_check_gizmo_tmp.gd
rm scripts/_check_gizmo_tmp.gd
```

Expected: `parsed OK` 출력, 에러 없음.

- [ ] **Step 3: Task 1 테스트 재확인 (회귀 없음)**

Run: `godot --headless --script tests/test_axis_gizmo.gd`
Expected: `Results: 12 passed, 0 failed` (Task 1과 동일).

- [ ] **Step 4: 커밋**

```bash
git add scripts/AxisGizmo.gd
git commit -m "feat: rewrite AxisGizmo as a drag-scroll state machine"
```

---

## Task 3: CameraController — 터치다운 시점에 제스처 오너십 분기

**Files:**
- Modify: `scripts/CameraController.gd`

**Interfaces:**
- Consumes: `AxisGizmo` 콜라이더의 `gizmo_axis` 메타 (기존과 동일한 방식, 레이캐스트만 타이밍이 press로 이동)
- Produces:
  - `signal block_tapped(x: int, y: int, z: int)` (기존 유지)
  - `signal gizmo_drag_started(axis: int)` (신규)
  - `signal gizmo_drag_updated(delta: Vector2)` (신규)
  - `signal gizmo_drag_ended()` (신규)
  - 제거: `signal gizmo_tapped(axis: int)`

- [ ] **Step 1: `scripts/CameraController.gd` 전체 교체**

```gdscript
# scripts/CameraController.gd
class_name CameraController
extends Camera3D

signal block_tapped(x: int, y: int, z: int)
signal gizmo_drag_started(axis: int)
signal gizmo_drag_updated(delta: Vector2)
signal gizmo_drag_ended()

const TAP_THRESHOLD := 10.0
const ORBIT_SENSITIVITY := 0.007
const PINCH_SENSITIVITY := 0.015
const MIN_DISTANCE := 3.0
const MAX_DISTANCE := 18.0

var _theta := PI / 6.0    # horizontal angle
var _phi := PI / 3.5      # vertical angle
var _distance := 9.0
var _target := Vector3.ZERO

var _touches: Dictionary = {}     # index → Vector2
var _touch0_start := Vector2.ZERO
var _pinch_start_dist := 0.0
var _is_pinching := false
var _dragging_axis := -1

func _ready() -> void:
	reset_transform()

func reset_transform() -> void:
	_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if event.index == 0:
			_touch0_start = event.position
			var axis := _raycast_gizmo_axis(event.position)
			if axis != -1:
				_dragging_axis = axis
				gizmo_drag_started.emit(axis)
				return
		if _dragging_axis == -1 and _touches.size() == 2:
			_is_pinching = true
			_pinch_start_dist = _touches[0].distance_to(_touches[1])
	else:
		if event.index == 0 and _dragging_axis != -1:
			gizmo_drag_ended.emit()
			_dragging_axis = -1
		elif not _is_pinching and event.index == 0:
			var moved := event.position.distance_to(_touch0_start)
			if moved < TAP_THRESHOLD:
				_do_raycast(event.position)
		_touches.erase(event.index)
		if _touches.size() < 2:
			_is_pinching = false

func _on_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if event.index == 0 and _dragging_axis != -1:
		gizmo_drag_updated.emit(event.relative)
		return
	if _is_pinching and _touches.size() == 2:
		var new_dist: float = (_touches[0] as Vector2).distance_to(_touches[1] as Vector2)
		var delta := new_dist - _pinch_start_dist
		_distance = clamp(_distance - delta * PINCH_SENSITIVITY, MIN_DISTANCE, MAX_DISTANCE)
		_pinch_start_dist = new_dist
		_update_camera()
	elif not _is_pinching and event.index == 0:
		_theta -= event.relative.x * ORBIT_SENSITIVITY
		_phi = clamp(_phi - event.relative.y * ORBIT_SENSITIVITY, 0.15, PI - 0.15)
		_update_camera()

func _update_camera() -> void:
	var x := _distance * sin(_phi) * cos(_theta)
	var y := _distance * cos(_phi)
	var z := _distance * sin(_phi) * sin(_theta)
	position = _target + Vector3(x, y, z)
	look_at(_target, Vector3.UP)

func _raycast_gizmo_axis(screen_pos: Vector2) -> int:
	var space := get_world_3d().direct_space_state
	var origin := project_ray_origin(screen_pos)
	var direction := project_ray_normal(screen_pos)
	var params := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	params.collision_mask = 2  # gizmo 화살표만
	var hit := space.intersect_ray(params)
	if not hit:
		return -1
	var collider := hit["collider"] as CollisionObject3D
	if collider.has_meta("gizmo_axis"):
		return collider.get_meta("gizmo_axis") as int
	return -1

func _do_raycast(screen_pos: Vector2) -> void:
	var space := get_world_3d().direct_space_state
	var origin := project_ray_origin(screen_pos)
	var direction := project_ray_normal(screen_pos)
	var params := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	params.collision_mask = 1  # 블록만
	var hit := space.intersect_ray(params)
	if not hit:
		return
	var collider := hit["collider"] as CollisionObject3D
	if collider.has_meta("grid_pos"):
		var gp := collider.get_meta("grid_pos") as Vector3i
		block_tapped.emit(gp.x, gp.y, gp.z)
```

- [ ] **Step 2: 헤드리스 파싱 확인**

```bash
cat > scripts/_check_cam_tmp.gd << 'EOF'
extends SceneTree
const CC = preload("res://scripts/CameraController.gd")
func _init():
    print("parsed OK")
    quit()
EOF
godot --headless --script scripts/_check_cam_tmp.gd
rm scripts/_check_cam_tmp.gd
```

Expected: `parsed OK`, 에러 없음.

- [ ] **Step 3: 커밋**

```bash
git add scripts/CameraController.gd
git commit -m "feat: route gizmo arrow drags separately from camera orbit"
```

---

## Task 4: HUD — 리셋 버튼

**Files:**
- Modify: `scripts/HUD.gd`

**Interfaces:**
- Consumes: 없음 (독립)
- Produces:
  - `signal reset_pressed` (신규)
  - `func set_reset_enabled(enabled: bool) -> void` (신규)

- [ ] **Step 1: 시그널 선언 추가**

`scripts/HUD.gd` 상단, 기존 시그널 선언부:

```gdscript
signal pause_pressed(is_paused: bool)
signal home_pressed
```

이걸로 교체:

```gdscript
signal pause_pressed(is_paused: bool)
signal home_pressed
signal reset_pressed
```

- [ ] **Step 2: 리셋 버튼 변수 추가**

`var _is_paused := false` 다음 줄에 추가:

```gdscript
var _reset_btn: Button
```

- [ ] **Step 3: `_build()`에 리셋 버튼 배치**

기존 `top_bar.add_child(_make_icon_button("⚙"))` 줄을 찾아서 (기어 버튼), 그 바로 앞에 리셋 버튼 삽입:

```gdscript
	_reset_btn = _make_icon_button("↻")
	_reset_btn.disabled = true
	_reset_btn.pressed.connect(func(): reset_pressed.emit())
	top_bar.add_child(_reset_btn)

	top_bar.add_child(_make_icon_button("⚙"))
```

(기존 `top_bar.add_child(_make_icon_button("⚙"))` 한 줄만 있던 자리를 위 5줄로 교체.)

- [ ] **Step 4: `set_reset_enabled` 함수 추가**

파일 맨 끝, 기존 `hide_status()` 함수 다음에 추가:

```gdscript
func set_reset_enabled(enabled: bool) -> void:
	_reset_btn.disabled = not enabled
```

- [ ] **Step 5: 헤드리스 파싱 확인**

```bash
cat > scripts/_check_hud_tmp.gd << 'EOF'
extends SceneTree
const H = preload("res://scripts/HUD.gd")
func _init():
    print("parsed OK")
    quit()
EOF
godot --headless --script scripts/_check_hud_tmp.gd
rm scripts/_check_hud_tmp.gd
```

Expected: `parsed OK`, 에러 없음.

- [ ] **Step 6: 커밋**

```bash
git add scripts/HUD.gd
git commit -m "feat: add HUD reset button for axis depth lock"
```

---

## Task 5: Main.gd — 배선

**Files:**
- Modify: `scripts/Main.gd`

**Interfaces:**
- Consumes: `AxisGizmo.begin_drag/update_drag/end_drag/reset/axis_lock_changed` (Task 2), `CameraController.gizmo_drag_started/updated/ended` (Task 3), `HUD.reset_pressed/set_reset_enabled` (Task 4)

- [ ] **Step 1: 카메라-기즈모 신호 배선 교체**

`scripts/Main.gd`에서 다음 두 줄:

```gdscript
	_cam.block_tapped.connect(_on_block_tapped)
	_cam.gizmo_tapped.connect(_gizmo.on_axis_tapped)
```

이걸로 교체:

```gdscript
	_cam.block_tapped.connect(_on_block_tapped)
	_cam.gizmo_drag_started.connect(_gizmo.begin_drag)
	_cam.gizmo_drag_updated.connect(_gizmo.update_drag)
	_cam.gizmo_drag_ended.connect(_gizmo.end_drag)
```

- [ ] **Step 2: HUD 리셋 버튼 배선 추가**

다음 줄:

```gdscript
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.home_pressed.connect(_on_home_pressed)
```

이걸로 교체:

```gdscript
	_hud.pause_pressed.connect(_on_pause_pressed)
	_hud.home_pressed.connect(_on_home_pressed)
	_hud.reset_pressed.connect(_gizmo.reset)
	_gizmo.axis_lock_changed.connect(_hud.set_reset_enabled)
```

- [ ] **Step 3: 헤드리스 파싱 확인**

```bash
cat > scripts/_check_main_tmp.gd << 'EOF'
extends SceneTree
const M = preload("res://scripts/Main.gd")
func _init():
    print("parsed OK")
    quit()
EOF
godot --headless --script scripts/_check_main_tmp.gd
rm scripts/_check_main_tmp.gd
```

Expected: `parsed OK`, 에러 없음.

- [ ] **Step 4: `PuzzleModel` 회귀 테스트 재확인**

Run: `godot --headless --script tests/test_puzzle_model.gd`
Expected: 기존과 동일하게 `20 passed, 0 failed` (이번 작업은 `PuzzleModel`을 건드리지 않으므로 결과 불변이어야 함).

- [ ] **Step 5: 커밋**

```bash
git add scripts/Main.gd
git commit -m "feat: wire axis drag-scroll gesture and reset button in Main"
```

---

## Task 6: 에디터 수동 QA

**Files:** 없음 (검증 전용)

`AxisGizmo`/`CameraController`의 제스처 로직은 실제 터치 입력·레이캐스트·카메라 투영에 의존해 헤드리스로 검증 불가 — Godot 에디터에서 F5 실행 후 아래 체크리스트로 확인:

- [ ] **Step 1: 기본 동작 확인**

```
□ X(빨강)/Y(초록)/Z(파랑) 화살표 3개 모두 보임
□ 화살표를 짧게 탭(이동 없이 누르고 뗌) → depth 안 바뀜, 하지만 그 화살표만 남고 나머지 두 개 숨겨짐(잠금 진입) — 리셋 버튼이 활성화로 바뀜
□ 리셋 버튼 탭 → 화살표 3개 다시 보임, 리셋 버튼 다시 비활성화
```

- [ ] **Step 2: 드래그 스크롤 확인**

```
□ X 화살표를 잡고 오른쪽으로 드래그 → 레이어가 한 칸씩 순차적으로 보이기 시작 (0, 1, 2...)
□ 반대 방향으로 드래그 → depth 감소
□ 경계(0 또는 size-1)에서 계속 같은 방향으로 드래그해도 더 이상 변화 없음, 반대로 살짝만 당겨도 바로 반응
□ 손을 뗐다가 같은 화살표를 다시 잡고 드래그 → 스크롤 이어짐 (depth 유지된 상태에서 계속)
```

- [ ] **Step 3: 잠금/오빗/핀치 상호작용 확인**

```
□ 축 활성화 중 나머지 두 화살표 탭 시도 → 반응 없음(숨겨져 레이캐스트 안 맞음)
□ 축 드래그 중 빈 공간이 아니라 화살표에서 시작했으므로 카메라가 회전하지 않음
□ 축 드래그 중 두 번째 손가락을 대도 핀치 줌으로 전환되지 않음
□ 축 비활성(대기) 상태에서는 기존처럼 빈 공간 드래그 → 오빗, 핀치 → 줌, 블록 탭 → 제거 모두 정상
```

- [ ] **Step 4: 결과 기록**

전부 통과하면 다음 세션에서 위키 log에 기록. 문제 발견 시 구체적 증상을 메모해 후속 수정 태스크로 남김.

---

## Self-Review 결과

**Spec coverage (`wiki/specs/2026-07-12-axis-drag-scroll-design.md` 대비):**
- ✅ 드래그 전용 제스처 → Task 3 (`_raycast_gizmo_axis` on press, tap은 `update_drag` 호출 없이 종료)
- ✅ 고정 픽셀 거리(화면-공간 방향 투영) → Task 1/2 (`_consume_steps`, `_screen_direction`)
- ✅ 경계 클램프 + 누적 리셋 → Task 2 `update_drag`의 `clamped != target` 분기
- ✅ HUD 고정 리셋 버튼, 활성화될 때만 활성 → Task 4, Task 5 (`axis_lock_changed` → `set_reset_enabled`)
- ✅ 비활성 축 화살표 숨김(visible + collision_layer) → Task 2 `begin_drag`/`reset`
- ✅ 핀치 줌과 축 드래그 상호배제 → Task 3 `_on_touch`의 `_dragging_axis == -1` 가드

**Type consistency:**
- `AxisGizmo.begin_drag(axis: int)` / `update_drag(screen_delta: Vector2)` / `end_drag()` / `reset()` — Task 2에서 정의, Task 5에서 그대로 소비 ✅
- `CameraController.gizmo_drag_started(axis: int)` / `gizmo_drag_updated(delta: Vector2)` / `gizmo_drag_ended()` — Task 3 정의, Task 5 소비 ✅
- `HUD.reset_pressed` / `set_reset_enabled(enabled: bool)` — Task 4 정의, Task 5 소비 ✅
- `collision_layer 1`(blocks) / `2`(gizmo) 구분 — 기존 관례 그대로 유지, Task 2/3에서 일관 ✅
