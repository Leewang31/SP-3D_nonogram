# Picross 3D Prototype — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3×3×3 Picross 3D (제거 방식) 메카닉 검증 프로토타입 — Godot 4 실행 가능한 단일 씬.

**Architecture:** PuzzleModel(순수 로직) → Main.gd(조율) ↔ BlockGrid(렌더링) + CameraController(입력+레이캐스트) + ClueDisplay(힌트) + AxisGizmo(레이어 제어). 모든 노드는 Main.gd가 프로그래매틱으로 생성.

**Tech Stack:** Godot 4.3+, GDScript only, JSON 퍼즐 포맷, InputEventScreenTouch/Drag.

## Global Constraints

- Godot 4.3 이상 필수
- GDScript만 사용 (C# 없음)
- solution 인덱스 순서: `solution[z][y][x]` (z=0이 바닥)
- 힌트 마커 (○/□) 제외 — 숫자만 표시
- BLOCK_SIZE = 1.0, BLOCK_GAP = 0.1 (step = 1.1)
- 터치 입력만 — 마우스 에디터 테스트는 Godot Remote Debug 또는 에디터의 "Emulate Touch From Mouse" 설정으로

---

## File Map

| 파일 | 역할 |
|---|---|
| `project.godot` | Godot 프로젝트 설정 |
| `icon.svg` | 앱 아이콘 (최소) |
| `Main.tscn` | 루트 씬 (Node3D 하나, Main.gd 첨부) |
| `scripts/Main.gd` | 씬 조율 — 노드 생성, 시그널 연결, 게임 상태 |
| `scripts/PuzzleModel.gd` | 순수 로직 — 노드 없음, 독립 테스트 가능 |
| `scripts/BlockGrid.gd` | 3D 블록 MeshInstance3D 생성 + 가시성 제어 |
| `scripts/CameraController.gd` | 터치 FSM — 오빗/핀치/탭/레이캐스트 |
| `scripts/ClueDisplay.gd` | 각 축 면 Label3D 힌트 숫자 |
| `scripts/AxisGizmo.gd` | X/Y/Z 화살표 — 탭으로 레이어 depth 제어 |
| `puzzles/tutorial_01.json` | 3×3×3 십자가(+) 퍼즐 |
| `tests/test_puzzle_model.gd` | PuzzleModel 헤드리스 테스트 |

---

## Task 1: 프로젝트 스캐폴딩 + 퍼즐 JSON

**Files:**
- Create: `project.godot`
- Create: `icon.svg`
- Create: `Main.tscn`
- Create: `puzzles/tutorial_01.json`
- Create dirs: `scripts/`, `puzzles/`, `tests/`

**Interfaces:**
- Produces: Godot 프로젝트 실행 진입점, 퍼즐 데이터

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p scripts puzzles tests
```

- [ ] **Step 2: project.godot 생성**

```ini
; Engine configuration file.
[application]

config/name="Picross3D"
config/features=PackedStringArray("4.3", "Mobile")
config/icon="res://icon.svg"
run/main_scene="res://Main.tscn"

[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/mode=4

[input_devices]

pointing/emulate_touch_from_mouse=true

[rendering]

renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
```

- [ ] **Step 3: icon.svg 생성**

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" rx="16" fill="#3d8bed"/>
  <text x="64" y="90" font-size="72" text-anchor="middle" fill="white">+</text>
</svg>
```

- [ ] **Step 4: Main.tscn 생성**

```
[gd_scene format=3]

[node name="Main" type="Node3D"]
```

- [ ] **Step 5: puzzles/tutorial_01.json 생성**

십자가(+) 퍼즐 — 7개 블록 유지, 20개 제거.
`solution[z][y][x]`: 1=유지, 0=제거.

```json
{
  "id": "tutorial_01",
  "size": 3,
  "solution": [
    [
      [0, 0, 0],
      [0, 1, 0],
      [0, 0, 0]
    ],
    [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0]
    ],
    [
      [0, 0, 0],
      [0, 1, 0],
      [0, 0, 0]
    ]
  ]
}
```

- [ ] **Step 6: Godot 에디터에서 프로젝트 열기 확인**

Godot 4.3 에디터에서 `project.godot` 열기. 에러 없이 열리면 통과.

---

## Task 2: PuzzleModel.gd (TDD)

**Files:**
- Create: `scripts/PuzzleModel.gd`
- Create: `tests/test_puzzle_model.gd`

**Interfaces:**
- Produces:
  - `class_name PuzzleModel`
  - `enum BlockState { INTACT, REMOVED }`
  - `enum RemoveResult { OK, WRONG, ALREADY_REMOVED }`
  - `func load_puzzle(data: Dictionary) -> void`
  - `func remove_block(x: int, y: int, z: int) -> RemoveResult`
  - `func get_clue(axis: int, index_a: int, index_b: int) -> int`
    - axis=0(X): index_a=y, index_b=z → solution[z][y][*] 합계
    - axis=1(Y): index_a=x, index_b=z → solution[z][*][x] 합계
    - axis=2(Z): index_a=x, index_b=y → solution[*][y][x] 합계
  - `func is_solved() -> bool`
  - `func get_block_state(x: int, y: int, z: int) -> BlockState`

- [ ] **Step 1: 테스트 파일 작성**

```gdscript
# tests/test_puzzle_model.gd
extends SceneTree

const TUTORIAL_SOLUTION = [
    [[[0,0,0],[0,1,0],[0,0,0]]],
    [[[0,1,0],[1,1,1],[0,1,0]]],
    [[[0,0,0],[0,1,0],[0,0,0]]]
]

var _passed := 0
var _failed := 0

func _init() -> void:
    var data := {
        "id": "tutorial_01",
        "size": 3,
        "solution": [
            [[0,0,0],[0,1,0],[0,0,0]],
            [[0,1,0],[1,1,1],[0,1,0]],
            [[0,0,0],[0,1,0],[0,0,0]]
        ]
    }

    _test_load_puzzle(data)
    _test_remove_correct_block(data)
    _test_remove_wrong_block(data)
    _test_already_removed(data)
    _test_is_solved(data)
    _test_clue_x_axis(data)
    _test_clue_z_axis(data)

    print("\nResults: %d passed, %d failed" % [_passed, _failed])
    quit(_failed)

func _assert(condition: bool, name: String) -> void:
    if condition:
        _passed += 1
        print("PASS: " + name)
    else:
        _failed += 1
        print("FAIL: " + name)

func _test_load_puzzle(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    _assert(m.size == 3, "load_puzzle sets size=3")
    _assert(m.get_block_state(0, 0, 0) == PuzzleModel.BlockState.INTACT, "load_puzzle initial state INTACT")

func _test_remove_correct_block(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    # (0,0,0) is solution=0 → correct to remove
    var result := m.remove_block(0, 0, 0)
    _assert(result == PuzzleModel.RemoveResult.OK, "remove correct block returns OK")
    _assert(m.get_block_state(0, 0, 0) == PuzzleModel.BlockState.REMOVED, "removed block state is REMOVED")

func _test_remove_wrong_block(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    # (1,1,1) is solution=1 → WRONG to remove
    var result := m.remove_block(1, 1, 1)
    _assert(result == PuzzleModel.RemoveResult.WRONG, "remove keep-block returns WRONG")
    _assert(m.get_block_state(1, 1, 1) == PuzzleModel.BlockState.INTACT, "wrong remove leaves state INTACT")

func _test_already_removed(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    m.remove_block(0, 0, 0)
    var result := m.remove_block(0, 0, 0)
    _assert(result == PuzzleModel.RemoveResult.ALREADY_REMOVED, "double remove returns ALREADY_REMOVED")

func _test_is_solved(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    _assert(not m.is_solved(), "not solved initially")
    # Remove all 20 blocks that should be removed (solution==0)
    for z in 3:
        for y in 3:
            for x in 3:
                if data["solution"][z][y][x] == 0:
                    m.remove_block(x, y, z)
    _assert(m.is_solved(), "is_solved after removing all correct blocks")

func _test_clue_x_axis(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    # X-axis clue: axis=0, index_a=y, index_b=z
    # (y=1, z=1) → solution[1][1] = [1,1,1] → count=3
    _assert(m.get_clue(0, 1, 1) == 3, "X-axis clue (y=1,z=1) == 3")
    # (y=0, z=0) → solution[0][0] = [0,0,0] → count=0
    _assert(m.get_clue(0, 0, 0) == 0, "X-axis clue (y=0,z=0) == 0")
    # (y=1, z=0) → solution[0][1] = [0,1,0] → count=1
    _assert(m.get_clue(0, 1, 0) == 1, "X-axis clue (y=1,z=0) == 1")

func _test_clue_z_axis(data: Dictionary) -> void:
    var m := PuzzleModel.new()
    m.load_puzzle(data)
    # Z-axis clue: axis=2, index_a=x, index_b=y
    # (x=1, y=1) → solution[*][1][1] = [1,1,1] → count=3
    _assert(m.get_clue(2, 1, 1) == 3, "Z-axis clue (x=1,y=1) == 3")
    # (x=0, y=0) → solution[*][0][0] = [0,0,0] → count=0
    _assert(m.get_clue(2, 0, 0) == 0, "Z-axis clue (x=0,y=0) == 0")
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

```bash
godot4 --headless --script tests/test_puzzle_model.gd
```

Expected: `Error: Could not find class "PuzzleModel"` 또는 유사 에러.

- [ ] **Step 3: PuzzleModel.gd 구현**

```gdscript
# scripts/PuzzleModel.gd
class_name PuzzleModel

enum BlockState { INTACT, REMOVED }
enum RemoveResult { OK, WRONG, ALREADY_REMOVED }

var size: int
var _solution: Array   # [z][y][x] = 0|1
var _state: Array      # [z][y][x] = BlockState
var _removed_count: int = 0
var _to_remove_count: int = 0

func load_puzzle(data: Dictionary) -> void:
    size = data["size"]
    _solution = data["solution"]
    _state = []
    _removed_count = 0
    _to_remove_count = 0
    for z in size:
        var layer: Array = []
        for y in size:
            var row: Array = []
            for x in size:
                row.append(BlockState.INTACT)
                if _solution[z][y][x] == 0:
                    _to_remove_count += 1
            layer.append(row)
        _state.append(layer)

func remove_block(x: int, y: int, z: int) -> RemoveResult:
    if _state[z][y][x] == BlockState.REMOVED:
        return RemoveResult.ALREADY_REMOVED
    if _solution[z][y][x] == 1:
        return RemoveResult.WRONG
    _state[z][y][x] = BlockState.REMOVED
    _removed_count += 1
    return RemoveResult.OK

func get_clue(axis: int, index_a: int, index_b: int) -> int:
    var count := 0
    match axis:
        0:  # X: index_a=y, index_b=z
            for x in size:
                count += _solution[index_b][index_a][x]
        1:  # Y: index_a=x, index_b=z
            for y in size:
                count += _solution[index_b][y][index_a]
        2:  # Z: index_a=x, index_b=y
            for z in size:
                count += _solution[z][index_b][index_a]
    return count

func is_solved() -> bool:
    return _removed_count == _to_remove_count

func get_block_state(x: int, y: int, z: int) -> BlockState:
    return _state[z][y][x]
```

- [ ] **Step 4: 테스트 실행 — PASS 확인**

```bash
godot4 --headless --script tests/test_puzzle_model.gd
```

Expected:
```
PASS: load_puzzle sets size=3
PASS: load_puzzle initial state INTACT
PASS: remove correct block returns OK
...
Results: 10 passed, 0 failed
```

- [ ] **Step 5: 커밋**

```bash
git init
git add scripts/PuzzleModel.gd tests/test_puzzle_model.gd puzzles/tutorial_01.json project.godot icon.svg Main.tscn
git commit -m "feat: scaffold Godot project + PuzzleModel (TDD)"
```

---

## Task 3: BlockGrid.gd

**Files:**
- Create: `scripts/BlockGrid.gd`

**Interfaces:**
- Consumes: `PuzzleModel` (class_name)
- Produces:
  - `class_name BlockGrid`
  - `const BLOCK_SIZE := 1.0`
  - `const BLOCK_GAP := 0.1`
  - `func setup(model: PuzzleModel) -> void` — 블록 생성, model 저장
  - `func remove_block_visual(x: int, y: int, z: int) -> void`
  - `func flash_block_red(x: int, y: int, z: int) -> void` (async)
  - `func set_depth_filter(axis: int, depth: int) -> void` — axis: 0=X,1=Y,2=Z,-1=없음

- [ ] **Step 1: BlockGrid.gd 작성**

```gdscript
# scripts/BlockGrid.gd
class_name BlockGrid
extends Node3D

const BLOCK_SIZE := 1.0
const BLOCK_GAP := 0.1
const STEP := BLOCK_SIZE + BLOCK_GAP

var _model: PuzzleModel
var _blocks: Array   # [z][y][x] = Node3D
var _filter_axis := -1
var _filter_depth := -1

func setup(model: PuzzleModel) -> void:
    _model = model
    _create_blocks()

func _create_blocks() -> void:
    var n := _model.size
    var half := (n - 1) * STEP / 2.0
    for z in n:
        var layer: Array = []
        for y in n:
            var row: Array = []
            for x in n:
                var block := _make_block(x, y, z, half)
                add_child(block)
                row.append(block)
            layer.append(row)
        _blocks.append(layer)

func _make_block(x: int, y: int, z: int, half: float) -> Node3D:
    var root := Node3D.new()
    root.position = Vector3(x * STEP - half, y * STEP - half, z * STEP - half)

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.5, 0.9)
    mesh.material_override = mat
    root.add_child(mesh)

    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
    col.shape = shape
    body.add_child(col)
    body.set_meta("grid_pos", Vector3i(x, y, z))
    body.set_meta("is_block", true)
    root.add_child(body)

    return root

func remove_block_visual(x: int, y: int, z: int) -> void:
    _blocks[z][y][x].visible = false

func flash_block_red(x: int, y: int, z: int) -> void:
    var mesh := _blocks[z][y][x].get_child(0) as MeshInstance3D
    var mat := mesh.material_override as StandardMaterial3D
    var original := mat.albedo_color
    mat.albedo_color = Color(0.9, 0.2, 0.2)
    await get_tree().create_timer(0.3).timeout
    mat.albedo_color = original

func set_depth_filter(axis: int, depth: int) -> void:
    _filter_axis = axis
    _filter_depth = depth
    var n := _model.size
    for z in n:
        for y in n:
            for x in n:
                if _model.get_block_state(x, y, z) == PuzzleModel.BlockState.REMOVED:
                    continue
                _blocks[z][y][x].visible = _is_visible(x, y, z)

func _is_visible(x: int, y: int, z: int) -> bool:
    if _filter_axis == -1:
        return true
    match _filter_axis:
        0: return x <= _filter_depth
        1: return y <= _filter_depth
        2: return z <= _filter_depth
    return true
```

- [ ] **Step 2: 에디터에서 시각 확인 (임시 Main.gd)**

`Main.tscn`의 Node3D에 임시 스크립트 첨부:

```gdscript
# 임시 확인용 — Task 8에서 교체됨
extends Node3D

func _ready() -> void:
    var model := PuzzleModel.new()
    model.load_puzzle(JSON.parse_string(
        FileAccess.get_file_as_string("res://puzzles/tutorial_01.json")
    ))
    var grid := BlockGrid.new()
    add_child(grid)
    grid.setup(model)

    var cam := Camera3D.new()
    cam.position = Vector3(3, 3, 6)
    cam.look_at(Vector3.ZERO, Vector3.UP)
    add_child(cam)

    var light := DirectionalLight3D.new()
    light.rotation = Vector3(-PI/4, PI/4, 0)
    add_child(light)
```

Godot 에디터에서 F5 실행 → 3×3×3 파란 블록 격자 보이면 통과.

- [ ] **Step 3: 임시 스크립트 제거 (Main.gd 초기화)**

Main.tscn의 스크립트를 비어있는 상태로 되돌림:

```gdscript
# scripts/Main.gd (빈 상태 — Task 8에서 완성)
extends Node3D
```

Main.tscn에 스크립트 경로 등록:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1_main"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/BlockGrid.gd scripts/Main.gd Main.tscn
git commit -m "feat: add BlockGrid — 3D block grid with MeshInstance3D"
```

---

## Task 4: CameraController.gd

**Files:**
- Create: `scripts/CameraController.gd`

**Interfaces:**
- Consumes: BlockGrid (collision layer 1), AxisGizmo (collision layer 2, 메타 "gizmo_axis")
- Produces:
  - `class_name CameraController extends Camera3D`
  - `signal block_tapped(x: int, y: int, z: int)`
  - `signal gizmo_tapped(axis: int)`
  - `func reset_transform() -> void` — 초기 카메라 위치 설정

터치 상태 머신:
- 터치 0개: idle
- 터치 1개: 드래그 중 → 오빗 OR 집어든 상태
- 터치 2개: 핀치
- 탭 판정: ENDED, delta < TAP_THRESHOLD → 레이캐스트

- [ ] **Step 1: CameraController.gd 작성**

```gdscript
# scripts/CameraController.gd
class_name CameraController
extends Camera3D

signal block_tapped(x: int, y: int, z: int)
signal gizmo_tapped(axis: int)

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
        if _touches.size() == 2:
            _is_pinching = true
            _pinch_start_dist = _touches[0].distance_to(_touches[1])
    else:
        if not _is_pinching and event.index == 0:
            var moved := event.position.distance_to(_touch0_start)
            if moved < TAP_THRESHOLD:
                _do_raycast(event.position)
        _touches.erase(event.index)
        if _touches.size() < 2:
            _is_pinching = false

func _on_drag(event: InputEventScreenDrag) -> void:
    _touches[event.index] = event.position
    if _is_pinching and _touches.size() == 2:
        var new_dist := _touches[0].distance_to(_touches[1])
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

func _do_raycast(screen_pos: Vector2) -> void:
    var space := get_world_3d().direct_space_state
    var origin := project_ray_origin(screen_pos)
    var direction := project_ray_normal(screen_pos)
    var params := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
    params.collision_mask = 3  # layer 1 (blocks) + layer 2 (gizmo)
    var hit := space.intersect_ray(params)
    if not hit:
        return
    var collider := hit.collider
    if collider.has_meta("grid_pos"):
        var gp := collider.get_meta("grid_pos") as Vector3i
        block_tapped.emit(gp.x, gp.y, gp.z)
    elif collider.has_meta("gizmo_axis"):
        gizmo_tapped.emit(collider.get_meta("gizmo_axis") as int)
```

- [ ] **Step 2: 에디터 수동 확인**

임시로 Main.gd에 CameraController 연결:

```gdscript
extends Node3D

func _ready() -> void:
    var model := PuzzleModel.new()
    model.load_puzzle(JSON.parse_string(
        FileAccess.get_file_as_string("res://puzzles/tutorial_01.json")
    ))
    var grid := BlockGrid.new()
    add_child(grid)
    grid.setup(model)

    var cam := CameraController.new()
    add_child(cam)
    cam.block_tapped.connect(func(x, y, z): print("tap %d %d %d" % [x, y, z]))

    var light := DirectionalLight3D.new()
    light.rotation = Vector3(-PI/4, PI/4, 0)
    add_child(light)
```

F5 실행 → 드래그로 격자 회전, 핀치 줌, 블록 탭 시 콘솔 출력 확인.

- [ ] **Step 3: 커밋**

```bash
git add scripts/CameraController.gd
git commit -m "feat: add CameraController — orbit/pinch/tap/raycast"
```

---

## Task 5: ClueDisplay.gd

**Files:**
- Create: `scripts/ClueDisplay.gd`

**Interfaces:**
- Consumes: `PuzzleModel.get_clue(axis, index_a, index_b)`, `BlockGrid.BLOCK_SIZE`, `BlockGrid.BLOCK_GAP`, `BlockGrid.STEP`
- Produces:
  - `class_name ClueDisplay extends Node3D`
  - `func setup(model: PuzzleModel) -> void`

힌트 배치:
- X-axis(axis=0): X+ 면. 각 (y,z)마다 Label3D.
- Y-axis(axis=1): Y+ 면. 각 (x,z)마다 Label3D.
- Z-axis(axis=2): Z+ 면. 각 (x,y)마다 Label3D.
- 0인 클루는 표시 안 함 (빈 셀).

- [ ] **Step 1: ClueDisplay.gd 작성**

```gdscript
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
```

- [ ] **Step 2: 에디터 수동 확인**

Main.gd 임시 수정 — ClueDisplay 추가:

```gdscript
var clues := ClueDisplay.new()
add_child(clues)
clues.setup(model)
```

F5 실행 → 격자 외곽에 숫자 보이면 통과. 중간 레이어(z=1) X+ 면에서 `1, 3, 1`이 보여야 함.

- [ ] **Step 3: 커밋**

```bash
git add scripts/ClueDisplay.gd
git commit -m "feat: add ClueDisplay — Label3D hint numbers on axis faces"
```

---

## Task 6: AxisGizmo.gd

**Files:**
- Create: `scripts/AxisGizmo.gd`

**Interfaces:**
- Consumes: `BlockGrid.STEP`, `PuzzleModel.size`
- Produces:
  - `class_name AxisGizmo extends Node3D`
  - `func setup(puzzle_size: int) -> void`
  - `signal depth_changed(axis: int, depth: int)` — depth=-1이면 필터 해제
  - collision layer 2 사용 (blocks와 분리)

동작:
- 화살표 탭 → 해당 축 depth를 순환: -1(전체) → 0 → 1 → 2 → -1 → ...
- `size-1`과 `-1`은 동일 효과 (전체 보임)

화살표 배치:
- X 화살표 (빨강): position=(edge+1.5, 0, 0)
- Y 화살표 (초록): position=(0, edge+1.5, 0)
- Z 화살표 (파랑): position=(0, 0, edge+1.5)

- [ ] **Step 1: AxisGizmo.gd 작성**

```gdscript
# scripts/AxisGizmo.gd
class_name AxisGizmo
extends Node3D

signal depth_changed(axis: int, depth: int)

var _puzzle_size: int
var _depths: Array[int] = [-1, -1, -1]   # X, Y, Z

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

func on_axis_tapped(axis: int) -> void:
    var d := _depths[axis]
    if d == -1:
        d = 0
    elif d >= _puzzle_size - 1:
        d = -1
    else:
        d += 1
    _depths[axis] = d
    depth_changed.emit(axis, d)
```

- [ ] **Step 2: 에디터 수동 확인**

Main.gd에 AxisGizmo 추가 (임시):

```gdscript
var gizmo := AxisGizmo.new()
add_child(gizmo)
gizmo.setup(model.size)
gizmo.depth_changed.connect(func(axis, depth): print("depth %d=%d" % [axis, depth]))
cam.gizmo_tapped.connect(gizmo.on_axis_tapped)
```

F5 실행 → 화살표 탭마다 콘솔에 depth 변화 출력 확인.

- [ ] **Step 3: 커밋**

```bash
git add scripts/AxisGizmo.gd
git commit -m "feat: add AxisGizmo — layer depth toggle via arrow tap"
```

---

## Task 7: Main.gd — 전체 연결

**Files:**
- Modify: `scripts/Main.gd`

**Interfaces:**
- Consumes: PuzzleModel, BlockGrid, CameraController, ClueDisplay, AxisGizmo
- Produces: 완전히 동작하는 프로토타입

게임 상태:
- `_penalty: int` — 최대 5회, 초과 시 게임 오버 (리셋)
- `_solved: bool`

- [ ] **Step 1: Main.gd 최종 구현**

```gdscript
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
    _penalty_label.text = "GAME OVER — Resetting..."
    await get_tree().create_timer(2.0).timeout
    _load_and_build()

func _update_penalty_label() -> void:
    _penalty_label.text = "Penalties: %d / %d" % [_penalty, MAX_PENALTY]
```

- [ ] **Step 2: 전체 게임 플로우 수동 테스트**

F5 실행 후 확인 체크리스트:

```
□ 3×3×3 파란 블록 격자 표시됨
□ 각 축 면에 힌트 숫자 표시됨 (X+, Y+, Z+ 면)
□ 드래그 → 카메라 오빗
□ 핀치 → 줌 인/아웃
□ 제거 대상 블록 탭 → 블록 사라짐
□ 유지 블록 탭 → 빨간 플래시, "Penalties: 1/5" 표시
□ 5번 페널티 → "GAME OVER — Resetting..." → 2초 후 리셋
□ 화살표 탭 → 해당 축 레이어 필터링 (X 화살표 탭 → x=0 슬라이스만 보임)
□ 화살표 다시 탭 → x=1 슬라이스까지 보임, 세 번 탭 → 전체 복원
□ 20개 블록 모두 제거 → "CLEAR!" 황색 표시
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/Main.gd
git commit -m "feat: wire Main.gd — full prototype playable"
```

---

## Task 8: Wiki 업데이트

**Files:**
- Modify: `wiki/projects/3d-nonogram.md`
- Modify: `log.md`

- [ ] **Step 1: wiki/projects/3d-nonogram.md Key Decisions 업데이트**

Key Decisions 테이블에 추가:

```markdown
| 2026-06-23 | 첫 테스트 퍼즐: 십자가(+) 3D 크로스 | 7블록 유지 — 단순하고 대칭, 학습 곡선 낮음 |
| 2026-06-23 | 힌트 마커 (○/□) 프로토타입 제외 | 구현 복잡도 대비 가치 낮음, 이후 확장 |
| 2026-06-23 | AxisGizmo: 탭으로 depth 순환 | 드래그 상태 머신 복잡도 피함, 프로토타입에 충분 |
| 2026-06-23 | ClueDisplay: 0인 클루 숨김 | 화면 노이즈 감소 |
| 2026-06-23 | Main.gd가 모든 노드 프로그래매틱 생성 | .tscn 손편집 복잡도 제거, Claude Code 협업 최적 |
```

열린 질문에서 해결된 항목 제거:
- ~~퍼즐 데이터 포맷 확정~~ → JSON 확정
- ~~힌트 숫자 그룹 마커~~ → 프로토타입 제외 확정
- ~~첫 테스트 퍼즐~~ → 십자가(+) 확정

최근 활동에 추가:
```markdown
- 2026-06-23: 구현 플랜 확정. 프로토타입 구현 시작.
```

- [ ] **Step 2: log.md 업데이트**

```markdown
## [2026-06-23] plan | 구현 플랜 작성 — docs/superpowers/plans/2026-06-23-picross3d-prototype.md
## [2026-06-23] decision | 첫 테스트 퍼즐 십자가(+) 확정, 힌트마커 제외, AxisGizmo 탭 방식 확정
## [2026-06-23] config | CLAUDE.md 업데이트 — 세션 시작 wiki 확인 규칙 추가, 기술 스택 명시
```

- [ ] **Step 3: 커밋**

```bash
git add wiki/projects/3d-nonogram.md log.md CLAUDE.md docs/superpowers/plans/2026-06-23-picross3d-prototype.md
git commit -m "docs: update wiki with prototype decisions and implementation plan"
```

---

## Self-Review 결과

**Spec coverage:**
- ✅ 3D 블록 격자 렌더링 → Task 3 (BlockGrid)
- ✅ 카메라 오빗 + 핀치 줌 → Task 4 (CameraController)
- ✅ 탭 → 레이캐스트 → 블록 제거 → Task 4 + Task 7
- ✅ 축 화살표 기즈모 → Task 6 (AxisGizmo)
- ✅ 힌트 숫자 표시 → Task 5 (ClueDisplay)
- ✅ 페널티 시스템 → Task 7 (Main.gd)
- ✅ 정답 판정 → Task 7 (Main.gd)
- ✅ JSON 퍼즐 포맷 → Task 1
- ✅ PuzzleModel TDD → Task 2

**Type consistency:**
- `BlockGrid.STEP` — Task 3에서 정의 (`const STEP := BLOCK_SIZE + BLOCK_GAP`), Task 5, 6에서 소비 ✅
- `PuzzleModel.get_clue(axis, index_a, index_b)` — Task 2 정의, Task 5 소비 ✅
- `PuzzleModel.BlockState.INTACT/REMOVED` — Task 2 정의, Task 3 소비 ✅
- `collision_layer 1` (blocks) vs `collision_layer 2` (gizmo) — Task 3, 4, 6에서 일관 ✅
