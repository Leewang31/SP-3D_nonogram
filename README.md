# Picross 3D — 입체 피크로스 클론

Nintendo 입체 피크로스(Picross 3D: Round 2) 클론. NxNxN 블록 격자에서 숫자 단서를 보고 불필요한 블록을 제거해 숨겨진 3D 오브젝트를 완성하는 퍼즐 게임.

## 현황

메카닉 검증 프로토타입 — 3×3×3 십자가(+) 퍼즐 1개, 핵심 게임플레이 구현 완료.

## 게임 방식

- 꽉 찬 NxNxN 블록 격자에서 시작
- 각 행/열/기둥의 숫자 = 그 줄에 **남을** 블록 수
- 불필요한 블록 제거 → 3D 오브젝트 완성

## 기술 스택

- **엔진:** Godot 4.3+
- **언어:** GDScript
- **플랫폼:** 모바일 (iOS / Android)

## 실행 방법

1. [Godot 4.3+](https://godotengine.org/download) 설치
2. 이 레포 클론
3. Godot 에디터에서 `project.godot` 열기
4. F5 또는 실행 버튼

## 조작

| 입력 | 동작 |
|---|---|
| 한 손가락 드래그 | 카메라 오빗 |
| 핀치 | 줌 인/아웃 |
| 탭 | 블록 제거 |
| 화살표 탭 | 레이어 depth 필터 (X/Y/Z) |

## 프로젝트 구조

```
scripts/
├── PuzzleModel.gd       # 순수 퍼즐 로직 (노드 없음, 독립 테스트 가능)
├── BlockGrid.gd         # 3D 블록 격자 렌더링
├── CameraController.gd  # 터치 입력 (오빗/핀치/탭/레이캐스트)
├── ClueDisplay.gd       # 힌트 숫자 Label3D
├── AxisGizmo.gd         # X/Y/Z 레이어 depth 제어 화살표
└── Main.gd              # 씬 조율 및 게임 상태

puzzles/
└── tutorial_01.json     # 3×3×3 십자가(+) 퍼즐

tests/
└── test_puzzle_model.gd # PuzzleModel 헤드리스 테스트
```

## 퍼즐 데이터 포맷

```json
{
  "id": "tutorial_01",
  "size": 3,
  "solution": [
    [[0,0,0],[0,1,0],[0,0,0]],
    [[0,1,0],[1,1,1],[0,1,0]],
    [[0,0,0],[0,1,0],[0,0,0]]
  ]
}
```

인덱스 순서: `solution[z][y][x]`. `1` = 유지, `0` = 제거 대상.
클루는 런타임에 solution에서 결정론적으로 도출.

## 테스트

```bash
godot --headless --path . --script tests/test_puzzle_model.gd
```

## 레퍼런스

- 입체 피크로스 2 (HAL Laboratory / Nintendo 3DS)
