# 3D 노노그램 아키텍처

세 책임 분리: 퍼즐 모델 / 렌더러 / 인터랙션 (→ CLAUDE.md 핵심 아키텍처 참고)

## 씬 흐름

```
Home.tscn (Control)          ← 스테이지 선택 화면, main_scene
  └─ 탭 → GameState.select(path, stage) → change_scene_to_file(Main.tscn)

Main.tscn (Node3D)
├── DirectionalLight3D
├── WorldEnvironment      ← ProceduralSkyMaterial 파스텔 그라디언트 하늘
├── BlockGrid.gd          ← 6면 개별 쉐이딩 셰이더(ShaderMaterial)로 블록 렌더
├── ClueDisplay.gd        ← Label3D 힌트 숫자 + 원형 칩 배경(QuadMesh)
├── AxisGizmo.gd          ← X/Y/Z 레이어 depth 드래그 스크롤 제어 (2026-07-12, 이전 탭-사이클 방식 대체)
├── CameraController.gd (Camera3D)
└── HUD.gd (CanvasLayer)  ← 스테이지뱃지, 홈 버튼, 하트(lives), 기어/일시정지 버튼,
                             미스터리 타이틀+타이머, 회전 힌트 pill, clear/game-over 메시지
                             (홈 버튼 → Main.gd가 change_scene_to_file(Home.tscn))
```

`GameState.gd` (autoload) — `selected_puzzle_path`, `stage_number`를 Home→Main 씬 전환 간 전달하는 유일한 전역 상태. Main.gd가 모든 노드 프로그래매틱 생성 (→ [[core-decisions]]). HUD.gd는 claude.ai/design에서 가져온 모바일 화면 목업(Picross3D.dc.html)을 Godot Control 트리로 구현한 것 (→ [[core-decisions]] 2026-07-11). Home.gd도 같은 카드 스타일(흰 라운드 패널 + 그림자)을 재사용하되 코드는 공유하지 않고 각자 로컬 헬퍼로 중복 구현 (프로토타입 단계에서 공유 유틸 추상화는 이르다고 판단).

## 데이터 흐름

```
puzzle.json → PuzzleModel.gd → BlockGrid.gd (렌더링)
터치 입력 → CameraController.gd → 레이캐스트 → BlockGrid.gd → PuzzleModel.gd
```

## PuzzleModel.gd 인터페이스 (순수 GDScript, 노드 없음)

```gdscript
func load_puzzle(data: Dictionary) -> void
func remove_block(x, y, z: int) -> RemoveResult          # OK | WRONG | ALREADY_REMOVED
func get_clue(axis: int, index_a: int, index_b: int) -> int
func get_intact_count(axis: int, index_a: int, index_b: int) -> int
func is_confirmed_keep(x, y, z: int) -> bool             # 라인 intact 수 == 클루 → 유지 확정
func is_solved() -> bool
func get_block_state(x, y, z: int) -> BlockState         # INTACT | REMOVED
```

⚠️ 초기 설계안에는 `BlockState.MUST_KEEP`을 상태값으로 넣을 계획이었으나, 실제 구현은 `is_confirmed_keep()`을 매 라인마다 동적으로 계산하는 순수 함수로 대체 (상태를 이중으로 저장하지 않음, → [[core-decisions]] 2026-07-05).

`PuzzleModel.name`: JSON `name` 필드(선택, 기본 `""`). 퍼즐 완성 시 HUD 미스터리 타이틀("? ? ?") 리빌에 사용.

## HUD.gd 인터페이스 (Control, 노드 트리 직접 생성)

```gdscript
func set_stage(n: int) -> void
func set_lives(current: int, max_lives: int) -> void
func set_timer_seconds(seconds: float) -> void
func reveal_title(text: String) -> void
func show_status(text: String, color: Color) -> void   # CLEAR! / GAME OVER
func hide_status() -> void
signal pause_pressed(is_paused: bool)                  # Main.gd가 get_tree().paused에 연결
signal home_pressed                                     # Main.gd가 Home.tscn으로 전환
```

## 퍼즐 목록 (puzzles/*.json)

Home.gd `PUZZLE_PATHS` 상수 배열로 순서 고정 (디렉터리 알파벳 스캔 대신 명시적 리스트 — `tutorial_01`이 `puzzle_02`보다 사전순 뒤라 스캔 시 순서 꼬임 방지).

| 스테이지 | 파일 | 이름 | 비고 |
|---|---|---|---|
| 1 | tutorial_01.json | 십자가 | 최초 튜토리얼 |
| 2 | puzzle_02.json | 상자 | 쉘(26블록), 1칸만 제거 — 온보딩용 |
| 3 | puzzle_03.json | 고리 | 단일 레이어 사각 고리 |
| 4 | puzzle_04.json | 계단 | 3단 계단 |
| 5 | puzzle_05.json | T자 | |
| 6 | puzzle_06.json | L자 | |
| 7 | puzzle_07.json | 다이아몬드 | 4×4×4, 맨해튼 거리 기반 |
| 8 | puzzle_08.json | 피라미드 | 4×4×4, 계단식 4단 |
| 9 | puzzle_09.json | 고리 | 4×4×4, 사각 튜브(중간 2개 층) |
| 10 | puzzle_10.json | 계단 | 4×4×4, x축 따라 상승 |
| 11 | puzzle_11.json | 구 | 4×4×4, 모서리(코너 8개)만 깎은 정육면체(56/64) — 원래 유클리드 거리 근사였으나 이 해상도에서 다이아몬드(맨해튼)와 완전히 동일한 셀 집합이 나와 puzzle_07과 중복, 2026-07-12 재생성 |

7번부터는 `size=4` — `PuzzleModel`/`BlockGrid`/`ClueDisplay` 모두 `_model.size`를 동적 참조하므로 격자 크기 변경에 별도 대응 불필요.

---

관련: [[game-design]], [[core-decisions]]
