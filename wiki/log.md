# 작업 로그 (append-only)

## 2026-06-13 브레인스토밍 및 아키텍처 설계
핵심 결정 8개 확정 ([[core-decisions]]). 모델/뷰/인터랙션 분리 아키텍처 설계 완료 ([[architecture]]).

## 2026-06-23 프로토타입 구현 완료
8개 태스크 완료. Godot 4 에디터에서 F5로 실행 가능. 십자가 테스트 퍼즐, AxisGizmo depth 순환, ClueDisplay 0-클루 숨김 등 결정 ([[core-decisions]]).

## 2026-07-05 위키 구조 개편
CLAUDE.md 위키 운영 규칙 변경 (projects/concepts/knowledge/raw 구조 → index/log/concepts/decisions 구조). 기존 `wiki/projects/3d-nonogram.md`를 [[game-design]], [[architecture]], [[core-decisions]]로 분리하고 `wiki/index.md` 생성.

## 2026-07-05 버그 수정: 제거된 블록 뒤 탭 안 되던 문제
`BlockGrid.remove_block_visual`이 시각적으로만 숨기고 콜리전(StaticBody3D)은 유지 → 레이캐스트가 제거된 블록에서 막혀 뒤 블록 탭 불가. `collision_layer = 0`으로 해제해 레이 통과하도록 수정.

## 2026-07-05 힌트 숫자 표시 방식 변경
숫자가 격자 바깥 고정 위치에 떠 있던 문제 수정. 각 라인의 **현재 최전방 intact 블록 표면**에 부착하고, 블록 제거 시 자동으로 다음 블록 표면으로 이동하도록 `ClueDisplay`에 `on_block_removed()` 추가. 0인 클루도 표시하도록 변경 (⚠️ [[core-decisions]] 2026-06-23 결정 번복). 이후 billboard 회전 때문에 표면에 안 붙어 보이는 문제 추가 발견 → billboard 제거하고 축별 고정 회전 부여로 재수정.

## 2026-07-05 확정 유지 블록(MUST_KEEP) 기능 추가
어떤 축 라인이든 intact 블록 수 == 클루 값이 되면, 남은 블록은 전부 solution=1이 확정됨(더 제거할 필요 없음). `PuzzleModel`에 `get_intact_count()`, `is_confirmed_keep()` 추가(순수 함수, 상태 이중 저장 안 함). `BlockGrid.set_block_confirmed()`로 금색 표시, `Main.gd`에서 확정 블록 탭 시 페널티 없이 무시하도록 배선. 아키텍처 문서상 원래 계획됐던 `BlockState.MUST_KEEP` 개념을 동적 계산 방식으로 구현 (→ [[architecture]], [[core-decisions]]). `tests/test_puzzle_model.gd`에 케이스 추가.
