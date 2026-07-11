# 3D 노노그램 아키텍처

세 책임 분리: 퍼즐 모델 / 렌더러 / 인터랙션 (→ CLAUDE.md 핵심 아키텍처 참고)

## 씬 트리

```
Main.tscn (Node3D)
├── DirectionalLight3D
├── WorldEnvironment      ← ProceduralSkyMaterial 파스텔 그라디언트 하늘
├── BlockGrid.gd          ← 6면 개별 쉐이딩 셰이더(ShaderMaterial)로 블록 렌더
├── ClueDisplay.gd        ← Label3D 힌트 숫자 + 원형 칩 배경(QuadMesh)
├── AxisGizmo.gd          ← X/Y/Z 레이어 depth 탭 제어
├── CameraController.gd (Camera3D)
└── HUD.gd (CanvasLayer)  ← 스테이지뱃지, 하트(lives), 기어/일시정지 버튼,
                             미스터리 타이틀+타이머, 회전 힌트 pill, clear/game-over 메시지
```

Main.gd가 모든 노드 프로그래매틱 생성 (→ [[core-decisions]]). HUD.gd는 claude.ai/design에서 가져온 모바일 화면 목업(Picross3D.dc.html)을 Godot Control 트리로 구현한 것 (→ [[core-decisions]] 2026-07-11).

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
```

---

관련: [[game-design]], [[core-decisions]]
