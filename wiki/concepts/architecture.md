# 3D 노노그램 아키텍처

세 책임 분리: 퍼즐 모델 / 렌더러 / 인터랙션 (→ CLAUDE.md 핵심 아키텍처 참고)

## 씬 트리

```
Main.tscn
├── Node3D (GameRoot)
│   ├── Camera3D          ← CameraController.gd
│   ├── Node3D            ← BlockGrid.gd (MeshInstance3D 동적 생성)
│   ├── Node3D            ← ClueDisplay.gd (Label3D 힌트 숫자)
│   └── DirectionalLight3D + WorldEnvironment
└── CanvasLayer (UI)
    ├── HSlider           ← 레이어 슬라이더
    └── Label             ← 페널티 카운터
```

Main.gd가 모든 노드 프로그래매틱 생성 (→ [[core-decisions]]).

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

---

관련: [[game-design]], [[core-decisions]]
