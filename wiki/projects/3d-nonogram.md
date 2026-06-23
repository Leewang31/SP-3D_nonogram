---
date: 2026-06-13
type: project
status: in_progress
tags:
  - project
  - 3d-nonogram
  - godot4
ai-first: true
---

## 미래의 Claude를 위해
Picross 3D 클론 모바일 게임. Godot 4 + GDScript. 꽉 찬 블록에서 시작해 제거하는 방식. 모델/뷰 분리 아키텍처. 이 노트에서 모든 설계 결정과 진행 상황 추적.

---

# 3D 노노그램 (Picross 3D 클론)

## 프로젝트 개요

Nintendo의 입체 피크로스(Picross 3D: Round 2) 클론. NxNxN 블록에서 시작해 숫자 단서를 보고 불필요한 블록을 제거해 3D 오브젝트를 완성하는 퍼즐 게임.

- **목표:** 메카닉 검증 프로토타입 (퍼즐 1개, 핵심 게임플레이)
- **플랫폼:** 모바일 (iOS / Android)
- **기술 스택:** Godot 4 + GDScript
- **시작일:** 2026-06-13
- **레퍼런스:** 입체 피크로스 2 (Nintendo 3DS / HAL Laboratory)

---

## 핵심 게임 메카닉

### 방식
- 꽉 찬 3D 블록 격자에서 시작
- 각 행/열/기둥 숫자 = 그 줄에 **남을** 블록 수
- 불필요한 블록 제거 → 숨겨진 3D 오브젝트 완성

### 블록 타입
- **1단계:** 파란 블록 단일 타입 (유지 or 제거)
- **2단계 (이후 확장):** 파랑 + 주황 이중 색상 시스템

### 힌트 숫자 규칙 (원작 기준)
- 숫자만 = 해당 줄의 남을 블록 수
- ○ 표시 = 남은 블록이 2그룹 이상으로 분리
- □ 표시 = 남은 블록이 3그룹 이상으로 분리

---

## 격자 크기

가변 지원 — 퍼즐 데이터의 `size` 필드로 제어:
| 크기 | 블록 수 | 용도 |
|---|---|---|
| 3×3×3 | 27 | 튜토리얼 |
| 5×5×5 | 125 | 기본 |
| 10×10×10 | 1,000 | 고급 |

---

## 터치 조작 방식

**자유 3D 회전 + 레이어 슬라이더:**
- 한 손가락 드래그 → 카메라 오빗
- 핀치 → 줌 인/아웃
- 탭 → 레이캐스트 → 블록 제거
- 레이어 슬라이더 → 층 이동 (내부 블록 접근)

---

## 아키텍처

### 씬 트리
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

### 데이터 흐름
```
puzzle.json → PuzzleModel.gd → BlockGrid.gd (렌더링)
터치 입력 → CameraController.gd → 레이캐스트 → BlockGrid.gd → PuzzleModel.gd
```

### PuzzleModel.gd 인터페이스 (순수 GDScript, 노드 없음)
```gdscript
func load_puzzle(data: Dictionary) -> void
func remove_block(x, y, z: int) -> RemoveResult  # OK | WRONG | ALREADY_REMOVED
func get_clues(axis: Axis, index: int) -> Array[ClueGroup]
func is_solved() -> bool
func get_block_state(x, y, z: int) -> BlockState  # INTACT | REMOVED | MUST_KEEP
```

---

## 프로토타입 범위 (A — 메카닉 검증)

포함:
- 3D 블록 격자 렌더링
- 카메라 오빗 + 핀치 줌
- 탭 → 레이캐스트 → 블록 제거
- 레이어 슬라이더
- 힌트 숫자 표시 (각 축)
- 정답 판정
- 실수 페널티

미포함:
- 메인 메뉴 / 퍼즐 선택
- 플래그 마킹
- 클리어 연출 (파티클/애니메이션)

---

## Key Decisions

| 날짜 | 결정 | 이유 |
|---|---|---|
| 2026-06-13 | Picross 3D 방식 (제거) | 직관적 조작감, 시각적 보상, 검증된 재미 |
| 2026-06-13 | 파랑 단일 타입 먼저 | 프로토타입 범위 최소화, 이후 주황 확장 |
| 2026-06-13 | 모바일 (iOS/Android) | 닌텐도 원작과 동일한 터치 경험 목표 |
| 2026-06-13 | Godot 4 선택 (Unity 대신) | Claude Code 협업 최적화 — .gd/.tscn 모두 텍스트 기반 |
| 2026-06-13 | 가변 격자 크기 | 퍼즐 데이터 size 필드 하나로 전 크기 지원 |
| 2026-06-13 | 자유 3D 회전 + 레이어 슬라이더 | 3D 뷰 + 내부 블록 접근 둘 다 해결 |
| 2026-06-13 | 모델/뷰 분리 아키텍처 | PuzzleModel 독립 테스트, Claude Code 협업 최적 |
| 2026-06-13 | 메카닉 검증 프로토타입 (범위 A) | 3D 퍼즐은 실제 돌려봐야 재미 판단 가능 |
| 2026-06-23 | 첫 테스트 퍼즐: 십자가(+) 3D 크로스 | 7블록 유지 — 단순하고 대칭, 학습 곡선 낮음 |
| 2026-06-23 | 힌트 마커 (○/□) 프로토타입 제외 | 구현 복잡도 대비 가치 낮음, 이후 확장 |
| 2026-06-23 | AxisGizmo: 탭으로 depth 순환 | 드래그 상태 머신 복잡도 피함, 프로토타입에 충분 |
| 2026-06-23 | ClueDisplay: 0인 클루 숨김 | 화면 노이즈 감소 |
| 2026-06-23 | Main.gd가 모든 노드 프로그래매틱 생성 | .tscn 손편집 복잡도 제거, Claude Code 협업 최적 |

---

## 열린 질문

- [ ] 레이어 슬라이더 UI 위치 (하단? 우측?)

## 최근 활동

- 2026-06-13: 브레인스토밍 완료. 핵심 결정 8개 확정. 아키텍처 설계 완료.
- 2026-06-23: 프로토타입 구현 완료. 8개 태스크 완료. Godot 4 에디터에서 F5로 실행 가능.
