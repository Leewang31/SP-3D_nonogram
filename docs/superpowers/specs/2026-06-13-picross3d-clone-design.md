# Picross 3D 클론 — 설계 문서

**날짜:** 2026-06-13  
**상태:** 초안 승인 대기  
**범위:** 메카닉 검증 프로토타입 (범위 A)

---

## 1. 프로젝트 개요

Nintendo 입체 피크로스(Picross 3D: Round 2) 클론. NxNxN 블록 격자에서 숫자 단서를 보고 불필요한 블록을 제거해 숨겨진 3D 오브젝트를 완성하는 퍼즐 게임.

- **플랫폼:** 모바일 (iOS / Android)
- **엔진:** Godot 4 + GDScript
- **레퍼런스:** 입체 피크로스 2 (HAL Laboratory / Nintendo 3DS)

---

## 2. 핵심 메카닉

### 게임 방식
- 꽉 찬 NxNxN 블록 격자에서 시작
- 각 행/열/기둥의 숫자 = 그 줄에 **남을** 블록 수
- 불필요한 블록 제거 → 3D 오브젝트 완성

### 힌트 숫자 규칙
| 표시 | 의미 |
|---|---|
| 숫자만 | 남을 블록 수, 연속 1그룹 |
| 숫자 + ○ | 남을 블록이 2그룹 이상으로 분리 |
| 숫자 + □ | 남을 블록이 3그룹 이상으로 분리 |

### 블록 타입
- **1단계 (현재):** 파란 블록 단일 — 유지 or 제거
- **2단계 (이후 확장):** 파랑 + 주황 이중 색상

---

## 3. 격자 크기

퍼즐 데이터의 `size` 필드 하나로 전 크기 지원:

| size | 블록 수 | 용도 |
|---|---|---|
| 3 | 3×3×3 = 27 | 튜토리얼 |
| 5 | 5×5×5 = 125 | 기본 |
| 10 | 10×10×10 = 1,000 | 고급 |

---

## 4. 아키텍처

### 씬 트리
```
Main.tscn
├── Node3D (GameRoot)
│   ├── Camera3D              ← CameraController.gd
│   ├── Node3D                ← BlockGrid.gd
│   │   └── (MeshInstance3D × N³, 동적 생성)
│   ├── Node3D                ← ClueDisplay.gd
│   │   └── (Label3D, 각 축 면에 배치)
│   ├── Node3D                ← AxisGizmo.gd
│   │   └── (X/Y/Z 화살표 StaticBody3D)
│   └── DirectionalLight3D + WorldEnvironment
└── CanvasLayer
    └── Label  ← 페널티 카운터 (우상단)
```

### 데이터 흐름
```
puzzle.json
    ↓ load_puzzle()
PuzzleModel.gd  ──→  BlockGrid.gd (초기 렌더링)
                ──→  ClueDisplay.gd (힌트 숫자 배치)

터치 입력
    ↓
CameraController.gd
    ├── 빈 공간 드래그 → 카메라 오빗
    ├── 핀치 → 줌
    └── 탭 → 레이캐스트 → BlockGrid.gd
                              ↓
                         hit된 블록 (x,y,z)
                              ↓
                    PuzzleModel.remove_block(x,y,z)
                         ↓              ↓
                        OK            WRONG
                    블록 hide      페널티 +1

AxisGizmo 드래그
    ↓
축 depth 변경 → BlockGrid.gd (visible 범위 업데이트)
```

---

## 5. 데이터 모델

### puzzle.json
```json
{
  "id": "tutorial_01",
  "size": 3,
  "solution": [
    [[1,1,1],[1,0,1],[1,1,1]],
    [[1,0,1],[0,0,0],[1,0,1]],
    [[1,1,1],[1,0,1],[1,1,1]]
  ]
}
```
- 인덱스 순서: `solution[z][y][x]`
- `1` = 유지, `0` = 제거 대상
- `clues`는 런타임에 solution에서 결정론적 도출 (JSON 저장 불필요)

### 핵심 타입 (GDScript)
```gdscript
enum BlockState { INTACT, REMOVED }
enum RemoveResult { OK, WRONG, ALREADY_REMOVED }

class ClueGroup:
    var count: int    # 남을 블록 수
    var marker: int   # 0=없음, 2=○(2그룹+), 3=□(3그룹+)
```

### PuzzleModel.gd 인터페이스 (순수 GDScript, 노드 없음)
```gdscript
func load_puzzle(data: Dictionary) -> void
func remove_block(x: int, y: int, z: int) -> RemoveResult
func get_clues(axis: int, index_a: int, index_b: int) -> ClueGroup
# axis=X → index_a=y, index_b=z  (X축 방향 줄, y행 z열)
# axis=Y → index_a=x, index_b=z
# axis=Z → index_a=x, index_b=y
func is_solved() -> bool
func get_block_state(x: int, y: int, z: int) -> BlockState
```

---

## 6. 입력 처리

### 터치 상태 머신 (CameraController.gd)

**터치 1개:**
- `BEGAN` → 시작점 기록
- `MOVED` → delta → 카메라 오빗 (Euler 회전)
- `ENDED` → 이동량 < `TAP_THRESHOLD(10px)` → 탭 판정 → 레이캐스트

**터치 2개 (핀치):**
- 두 터치 거리 변화 → 카메라 FOV 또는 Z 거리 조정

### 레이캐스트 흐름
```
탭 위치 → camera.project_ray() → PhysicsRayQueryParameters3D
    → space_state.intersect_ray()
    → hit.collider.get_meta("grid_pos") → Vector3i(x, y, z)
    → puzzle_model.remove_block(x, y, z)
```

### 축 화살표 기즈모 (AxisGizmo.gd)

3D 블록 중심에 X(빨강) / Y(초록) / Z(파랑) 화살표 배치:

| 상태 | 동작 |
|---|---|
| depth 전부 0 | 세 화살표 모두 표시 |
| 임의 축 화살표 드래그 | 해당 축 depth 증가, 나머지 두 화살표 hide |
| 활성 축 depth = 0 복귀 | 나머지 두 화살표 다시 표시 |
| Y, Z도 X와 동일 규칙 | 한 번에 한 축만 활성 가능 |

- depth D → X축 `[0..D]` 블록만 `visible = true`
- 화살표 드래그 중 레이캐스트 비활성화 (충돌 방지)
- 화살표는 `StaticBody3D` + `CollisionShape3D`로 별도 레이어 처리

---

## 7. 에러 처리 및 페널티

| 상황 | 결과 |
|---|---|
| 남겨야 할 블록 탭 (`WRONG`) | 페널티 +1, 햅틱 진동, 블록 빨간 플래시 후 복원 |
| 이미 제거된 블록 탭 (`ALREADY_REMOVED`) | 무시 |
| 페널티 5회 | 게임 오버 (프로토타입: 리셋만) |
| 모든 불필요 블록 제거 (`is_solved()`) | 완료 메시지 표시 |
| 기즈모 드래그 중 탭 | 레이캐스트 비활성화 → 무시 |

---

## 8. 프로토타입 범위

### 포함
- [x] 3D 블록 격자 렌더링 (MeshInstance3D 동적 생성)
- [x] 카메라 오빗 + 핀치 줌
- [x] 탭 → 레이캐스트 → 블록 제거
- [x] 축 화살표 기즈모 (X/Y/Z depth 제어)
- [x] 힌트 숫자 표시 (각 축 면 Label3D)
- [x] 페널티 시스템
- [x] 정답 판정

### 미포함 (이후 확장)
- [ ] 메인 메뉴 / 퍼즐 선택
- [ ] 플래그 마킹
- [ ] 클리어 연출 (파티클/애니메이션)
- [ ] 주황 블록 시스템
- [ ] 배경음악 / 효과음
- [ ] 진행 저장

---

## 9. 테스트 전략

`PuzzleModel.gd`는 순수 GDScript (노드 없음) → 독립 실행 테스트:

```gdscript
# test_puzzle_model.gd
func test_clue_generation():
    # solution → clue 도출 정확성 검증

func test_remove_correct_block():
    # 제거 대상 블록 → RemoveResult.OK 확인

func test_remove_wrong_block():
    # 유지 블록 제거 시도 → RemoveResult.WRONG + 상태 미변경

func test_is_solved():
    # 모든 불필요 블록 제거 후 is_solved() == true
```

BlockGrid / CameraController / AxisGizmo → Godot 에디터 수동 검증.

---

## 10. 미결 사항

- [ ] 첫 테스트 퍼즐 오브젝트 (3×3×3 단순 형태 — 무엇으로?)
- [ ] 화살표 기즈모 드래그 감도 (픽셀 당 depth 변화량)
- [ ] 힌트 숫자 폰트 크기 (격자 크기별 자동 조정?)
- [ ] 페널티 수 조정 가능 여부 (5회 고정 vs 설정 가능)
