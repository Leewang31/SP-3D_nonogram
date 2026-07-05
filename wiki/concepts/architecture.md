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
func remove_block(x, y, z: int) -> RemoveResult  # OK | WRONG | ALREADY_REMOVED
func get_clues(axis: Axis, index: int) -> Array[ClueGroup]
func is_solved() -> bool
func get_block_state(x, y, z: int) -> BlockState  # INTACT | REMOVED | MUST_KEEP
```

---

관련: [[game-design]], [[core-decisions]]
