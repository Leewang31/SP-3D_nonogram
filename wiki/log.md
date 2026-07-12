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

## 2026-07-11 claude.ai/design 목업 기반 HUD/비주얼 리뉴얼
사용자가 claude.ai/design 프로젝트(Picross3D.dc.html)를 DesignSync로 임포트해 그대로 구현 요청. 신규 `HUD.gd`(CanvasLayer) 작성 — 스테이지뱃지, 하트 3개(lives), 기어/일시정지 버튼, 미스터리 타이틀("? ? ?" → 정답 공개)+경과 타이머, 하단 회전 힌트 pill, CLEAR!/GAME OVER 메시지. `Main.gd`는 `MAX_PENALTY=5` 숫자 카운터를 버리고 `MAX_LIVES=3` 하트 모델로 교체, 일시정지를 `get_tree().paused`에 실제로 연결(HUD는 `PROCESS_MODE_ALWAYS`로 예외 처리). `BlockGrid`는 BoxMesh 단일 머티리얼 대신 면 노멀 기반 `ShaderMaterial`(6면 개별 밝기)로 토이블록 룩 구현. `ClueDisplay`는 클루 숫자 뒤에 생성 텍스처 기반 원형 칩 배경 추가. `PuzzleModel`에 `name` 필드 추가(퍼즐 완성 시 타이틀 리빌용), `puzzles/tutorial_01.json`에 `"name": "십자가"` 반영. 목업의 다색 배색/○□ 마커 구분/undo·hint/제스처 오버레이는 기존 결정 충돌 또는 백엔드 부재로 스코프 아웃 (→ [[core-decisions]], [[architecture]]).

## 2026-07-11 퍼즐 5종 추가 + 스테이지 선택 홈 화면
`puzzles/puzzle_02~06.json` 추가(상자/고리/계단/T자/L자, 3×3×3) — 총 6스테이지. 신규 `Home.gd`(Control, main_scene)가 `PUZZLE_PATHS` 순서대로 카드 그리드를 그리고, 탭하면 `GameState.gd`(오토로드)에 선택 경로/스테이지 번호를 저장 후 `Main.tscn`으로 전환. `Main.gd`는 하드코딩된 `PUZZLE_PATH`/`STAGE_NUMBER` 상수를 제거하고 `GameState`에서 읽도록 변경. `HUD.gd`에 홈 버튼(⌂) 추가 → `Main.gd`가 `change_scene_to_file(Home.tscn)`으로 복귀 (→ [[architecture]], [[core-decisions]]).

## 2026-07-11 위키 루트 잔재 정리 + CLAUDE.md 세션룰 경로 수정
루트에 남아있던 pre-2026-07-05 구조 잔재 `index.md`, `log.md` 삭제 (정본은 `wiki/index.md`, `wiki/log.md`). `.DS_Store`를 `.gitignore`에 추가. `CLAUDE.md` 세션시작 규칙에서 존재하지 않는 `wiki/projects/3d-nonogram.md` 참조 제거, index 기반 탐색으로 교체. Godot 에디터가 `project.godot`을 4.6으로 갱신하고 새로 생성한 `*.gd.uid` 파일들 트래킹 추가.

## 2026-07-11 MUST_KEEP 판정 OR→AND 변경 + ClueDisplay 빈 라인 마커 숨김
사용자 확인 결과 `PuzzleModel.is_confirmed_keep()`이 X/Y/Z 세 축 중 하나만 클루값과 일치해도 확정 유지(금색)로 판정하던 것을, 세 축 모두 동시에 일치해야만 확정되도록 변경 (⚠️ [[core-decisions]] 2026-07-05 결정 번복). `tests/test_puzzle_model.gd`의 확정 유지 테스트 케이스를 AND 시맨틱에 맞춰 재작성(중심 블록 vs 팔 블록 시나리오로 재구성), 18개 테스트 전부 통과 확인. 별개로 `ClueDisplay._reposition`이 한 라인의 블록이 전부 제거됐을 때 바깥 경계로 폴백 배치해 라벨/칩이 허공에 떠 보이던 버그 발견 및 수정 — 이제 `front == -1`이면 라벨·칩을 숨김 (→ [[core-decisions]]).

## 2026-07-11 클루 라벨 양면 표시 + 가독성/z-fighting 수정
사용자 요청으로 `ClueDisplay`가 각 축 라인마다 클루 숫자를 한쪽 끝(+ 방향)에만 붙이던 것을 양 끝(+/−)에 모두 붙이도록 변경 — 자유 회전 카메라로 어느 방향에서 봐도 라인 시작 쪽 클루가 보임. `_frontmost_intact`(최전방, 높은 인덱스)에 대응하는 `_backmost_intact`(최후방, 낮은 인덱스)을 추가하고, 라벨/칩 딕셔너리 키에 `sign`(+1/-1)을 포함해 축당 2개씩 관리. 구현 중 `for sign in [...]`에서 sign이 Variant로 추론돼 `var base := idx * STEP - half + sign * BLOCK_SIZE / 2.0`가 타입 추론 실패로 컴파일 에러 발생 → `for sign: int in [...]`로 명시 타입 지정해 해결.
추가로 "특정 각에서 숫자 안 보임" 버그 리포트 — 칩(원형 배경)과 라벨(숫자) 두 개의 반투명 메시가 표면에서 0.015 간격밖에 안 떨어져 있어 완만한 시야각에서 깊이정렬이 흔들려 텍스트가 칩 뒤로 밀리는 것으로 추정. `LABEL_OFFSET`/`CHIP_OFFSET` 간격을 0.015→0.06으로 벌리고, `label.render_priority=1`로 칩보다 항상 나중에 그려지도록 강제, `texture_filter`를 anisotropic mipmap으로 바꿔 완만한 각도에서 텍스트 자체가 흐려져 사라지는 것도 방지. 칩 배경도 반투명 → 불투명(진한 테두리+밝은 배경)으로, 텍스트도 진한색+굵은 흰 아웃라인으로 바꿔 블록 색과 무관하게 대비 확보 (→ [[core-decisions]]).

## 2026-07-12 4×4×4 퍼즐 5종 추가 (스테이지 7~11)
`size=4` 퍼즐 5개를 알고리즘으로 생성해 추가: 다이아몬드(맨해튼 거리, 32/64), 피라미드(계단식 4단, 30/64), 고리(사각 튜브, 중간 2개 층 테두리, 24/64), 계단(x축 따라 상승, 40/64), 구(유클리드 거리 근사, 32/64). `Home.gd`의 `PUZZLE_PATHS`에 `puzzle_07~11.json` 등록해 스테이지 7~11로 노출. `PuzzleModel.load_puzzle` + `get_clue`가 `_model.size`를 전부 동적 참조하는 걸 확인 — 3×3×3 하드코딩 없이 4×4×4도 문제없이 동작 (헤드리스 검증 완료).

## 2026-07-12 클루 원형 칩 배경 제거, 텍스트 단독 표시로 전환
사용자가 숫자를 원 안에 넣는 디자인이 "비호감"이라 피드백 — `ClueDisplay`에서 칩(QuadMesh + 절차 생성 원형 텍스처) 관련 코드 전부 제거하고 `Label3D`만 남김. 배경이 없어져 대비 확보가 중요해져 텍스트를 흰색 채움 + 진한 검정 아웃라인(18px, 기존 10px)으로 변경, `font_size` 64→96로 키움. 칩-라벨 간 z-fighting 방어용으로 넣었던 `render_priority`/이중 오프셋 로직도 칩 자체가 없어지며 자연히 불필요해져 제거 (→ [[core-decisions]]).

## 2026-07-12 docs/superpowers 폐지 — spec/plan을 위키로 전면 이관
사용자 요청으로 모든 자료를 위키 한 곳에서 관리하기로 결정. `docs/superpowers/specs/*.md` 2개(2026-06-13 최초 설계, 2026-07-12 레이어 드래그스크롤 설계)와 `docs/superpowers/plans/*.md` 1개(2026-06-23 프로토타입 구현 플랜)를 각각 `wiki/specs/`, `wiki/plans/`로 이동(`git mv`)하고 빈 `docs/` 디렉터리 삭제. `CLAUDE.md` Wiki 운영 규칙에 `wiki/specs/`, `wiki/plans/` 항목 추가 + "docs/superpowers 안 씀" 명시 — `superpowers:brainstorming`/`writing-plans` 스킬의 기본 경로(`docs/superpowers/...`)를 이 프로젝트에서는 항상 오버라이드해야 함. `wiki/index.md`에 specs/plans 섹션 추가.

## 2026-07-12 레이어 심도 드래그 스크롤 네비게이션 구현 (subagent-driven-development)
`wiki/specs/2026-07-12-axis-drag-scroll-design.md` → `wiki/plans/2026-07-12-axis-drag-scroll.md` 기준으로 5개 태스크를 서브에이전트 각각(구현 haiku, 리뷰 sonnet/haiku 혼용) 파견해 구현. `AxisGizmo`의 탭-사이클(`on_axis_tapped`) 제거하고 드래그 상태기계로 전면 교체 — `begin_drag`/`update_drag`/`end_drag`/`reset`, 축별 잠금(비활성 화살표 숨김+콜리전 해제), 경계 클램프+누적 리셋, `axis_lock_changed` 시그널. `CameraController`는 터치다운 시점에 기즈모 레이캐스트(mask=2)로 제스처 오너십을 먼저 판정해 오빗/축드래그를 분기하고, 블록 탭은 터치해제 시점 레이캐스트(mask=1)로 분리 — `gizmo_tapped` 시그널 폐지, `gizmo_drag_started/updated/ended` 3개로 교체. `HUD`에 리셋 버튼(↻, 축 잠금 중에만 활성) 추가. 픽셀→레이어 변환은 `AxisGizmo._consume_steps` 순수 함수로 분리해 `tests/test_axis_gizmo.gd`(12케이스) 헤드리스 테스트.
태스크 5개 개별 리뷰 전부 클린(Approved), 최종 전체 브랜치 리뷰(opus)도 Critical/Important 없이 클린 — Minor 3건: (1) 구식 `wiki/plans/2026-06-23-picross3d-prototype.md`의 옛 `gizmo_tapped`/`on_axis_tapped` 코드 리스팅이 낡아서 "superseded" 안내 추가로 수정함, (2) HUD 버튼(리셋 포함)이 `_input`에서 GUI보다 먼저 레이캐스트를 가로챌 여지 있음(기존 기어/일시정지 버튼도 같은 패턴 — 새로 생긴 문제 아님, Task 6 QA에서 확인 예정), (3) 빈 잠금 상태(depth=-1)에서 역방향 드래그 시 -2로 계산됐다가 0으로 클램프되어 "뒤로 당겼는데 0층으로 점프"하는 사소한 UX 특이점 — 무해하며 수정 보류.
남은 건 Task 6(에디터 수동 QA, 사람이 F5로 확인) — 헤드리스로 검증 불가한 터치 제스처 실동작 확인. (→ [[core-decisions]])

## 2026-07-12 드래그 스크롤 QA에서 버그 3건 발견 — 2건 수정, 1건 대기
Task 6 수동 QA 중 사용자가 실제 기기/에디터에서 확인하다 발견:
1. **클루 라벨 허공에 뜸 (수정 완료, `68b787b`)**: `ClueDisplay`가 클루를 "최전방 intact 블록 표면"에 동적 부착하는데, 그 블록이 depth 필터로 `visible=false` 처리되면 라벨만 남아 허공에 떠 보임. `_frontmost_intact`/`_backmost_intact` 탐색을 폐기하고 그리드 바깥 고정 경계(`half + BLOCK_SIZE/2 + LABEL_OFFSET`)에 항상 고정하는 방식으로 단순화 — depth 필터·제거 상태와 완전히 무관해짐. `on_block_removed`는 Main.gd 호출부 유지를 위해 빈 함수로 남김.
2. **최상단 도달 시 자동 언락 안 됨 (수정 완료, `68b787b`)**: depth가 `size-1`(전체 표시와 시각적으로 동일)에 도달해도 축이 계속 잠긴 채로 남아 나머지 화살표가 안 돌아오고 리셋 버튼도 안 꺼짐. `AxisGizmo.update_drag`에서 클램프된 depth가 `size-1`이면 `reset()`과 같은 언락 로직(`_unlock()`으로 공통화)을 자동 호출하도록 수정. 단, `reset()`과 달리 저장된 depth는 `-1`로 되돌리지 않고 `size-1` 그대로 유지 — 같은 화살표를 다시 잡았을 때 갑자기 0층으로 점프하지 않고 자연스럽게 이어서 스크롤되게 함.
3. **depth 필터로 숨긴 블록의 콜리전이 안 꺼짐 (수정 완료)**: `BlockGrid.set_depth_filter`(`BlockGrid.gd:113-134`)가 `visible`만 토글하고 `collision_layer`는 그대로 둠 — 안쪽 블록을 부수려고 탭해도 레이캐스트가 먼저 숨겨진(투명) 바깥 블록에 맞아 엉뚱하게 하트가 깎임. 2026-07-05에 "제거된 블록"에 대해 고쳤던 것과 같은 종류의 버그가 "depth-필터로 숨긴 블록"에도 존재. `_set_block_visible(x,y,z,vis)` 헬퍼로 통합해 `visible`과 `collision_layer`(1/0)를 항상 같이 토글하도록 수정 — 두 곳(depth=-1 전체 표시, depth 필터 적용)의 루프가 모두 이 헬퍼를 거치도록 교체.

## 2026-07-12 Home↔Main 정적 QA + 타이틀 리빌 폴백 + puzzle_11 중복 데이터 수정
Godot 바이너리 없어 헤드리스/에디터 실행 대신 코드 정적 추적으로 Home→GameState→Main 플로우 검증: 시그널 인자(`gizmo_drag_started/updated/ended`, `pause_pressed`, `home_pressed`, `reset_pressed`, `axis_lock_changed`) 전부 송수신측 일치, `BlockGrid`/`ClueDisplay`/`AxisGizmo` 모두 `_model.size` 동적 참조라 4×4×4(스테이지 7~11)도 3×3×3과 동일 경로로 동작 확인 — 통합 버그 없음.
`HUD.reveal_title()`이 빈 문자열 방어 없이 그대로 라벨에 넣던 것을 수정 — `name` 필드 없는 퍼즐이면 "완성!"으로 폴백, 리빌 시 텍스트 색도 옅은 `INK_SOFT`에서 진한 `INK`로 바뀌도록 추가(현재 등록된 퍼즐 11개 전부 name이 있어 실제로는 발동 안 하지만 방어 코드).
`puzzle_07.json`(다이아몬드)과 `puzzle_11.json`(구)의 `solution` 배열이 완전히 동일했던 것 발견 — 4×4×4처럼 축당 거리 레벨이 2단계(내부/외곽)뿐인 해상도에서는 맨해튼(L1)과 유클리드(L2) 임계값 선택이 "축소된 좌표 개수 k" 기준으로 항상 같은 부분집합을 골라 두 지표가 사실상 구분 안 되는 게 원인. `puzzle_11`을 "코너 8개만 깎은 정육면체"(k≤2, 56/64)로 재생성해 `puzzle_07`(k≤1, 32/64)과 확실히 다른 형태로 분리 (→ [[architecture]]).

## 2026-07-12 그룹 힌트 마커 추가 — 위첨자 숫자 방식
2026-06-23/2026-07-12 두 차례 백로그됐던 ○/□ 힌트 마커를 사용자 제안으로 재검토·구현. 원작은 "숫자+○(2그룹 이상)"/"숫자+□(3그룹 이상)"로 정확한 그룹 개수를 뭉뚱그리는데, 대신 위첨자 유니코드 숫자로 정확한 그룹 개수를 표시하는 방식 채택(예: 남을 블록 3개가 2덩어리로 나뉘면 "3²", 3덩어리면 "3³"). `PuzzleModel.get_group_count(axis, index_a, index_b)` 순수 함수 추가(라인에서 연속 1-런 개수 계산) — `tests/test_puzzle_model.gd`에 분리/연속/빈 라인 3케이스 검증 추가. `ClueDisplay._add_label`이 `get_clue`+`get_group_count`를 조합해 텍스트를 만들고(`_format_clue_text`), 그룹 1개 이하면 위첨자 없이 숫자만 — 별도 도형 메시 없이 기존 Label3D 텍스트 접미사만으로 구현해 2026-07-12 칩 제거 이후의 "텍스트 단독" 스타일과 자연스럽게 맞음 (→ [[core-decisions]], [[architecture]]).

## 2026-07-12 HUD 버튼 탭이 3D 레이캐스트로 새는 문제 수정
드래그 스크롤 구현 최종 리뷰(opus)에서 Minor로 남겨뒀던 항목 — `CameraController`가 `_input()`을 쓰고 있어 Godot 입력 처리 순서(`_input` → GUI → `_unhandled_input`)상 HUD 버튼(일시정지/리셋/기어/홈)을 눌러도 GUI가 이벤트를 완전히 소비하기 전에 카메라가 먼저 그 터치를 받아 블록/기즈모 레이캐스트를 시도할 수 있었음. 버튼이 화면상 3D 큐브와 겹치면 버튼 탭 한 번에 블록까지 같이 반응할 위험. `_input()` → `_unhandled_input()`로 변경 — `Button`(기본 `mouse_filter=STOP`)이 소비한 터치는 더 이상 `CameraController`까지 전파되지 않음 (→ [[core-decisions]]).

## 2026-07-12 클루 라벨 "허공에 뜸" 재발 — 블록 자식 부착 방식으로 재설계
사용자가 스크린샷으로 다른 버그 제보: 그리드 경계 고정 라벨(위 2026-07-12 항목)이 depth 드래그 스크롤로 절단면이 이동해도 안 따라가고 안 숨겨져, 실제 잘려나간 면과 숫자 위치가 어긋나 붕 떠 보임. 사용자가 "차라리 모든 큐브에 숫자를 다 적어두는 게 더 간편한 구현"이라고 제안 — 승인.
`BlockGrid.gd`에 `get_block(x,y,z)` 접근자 추가. `ClueDisplay.setup(model, grid)`로 시그니처 변경 — 그리드 경계 좌표 계산(half/edge) 전부 제거하고, 각 블록(x,y,z)마다 자신이 속한 3개 라인(X/Y/Z축)의 클루 라벨을 블록 로컬 좌표(±BLOCK_SIZE/2 + LABEL_OFFSET)로 계산해 **블록 노드의 자식으로 직접 부착**. `Node3D.visible=false`가 자식까지 전파되는 Godot 특성을 이용해 블록이 숨겨지면(depth 필터든 제거든) 라벨도 자동으로 같이 숨겨짐 — 별도 갱신 로직 불필요. `Main.gd`의 `_clues.on_block_removed(x,y,z)` 호출과 `ClueDisplay.on_block_removed`(빈 스텁이었음) 완전 삭제.
같은 라인의 여러 블록에 동일 클루 텍스트가 중복 부착되지만, 앞쪽 블록의 불투명 큐브가 뒤쪽 라벨을 depth test로 자연히 가려주므로 항상 "그 라인에서 지금 노출된 가장 앞쪽 표면"에만 숫자가 보임 — 별도의 "최전방 탐색" 로직 없이 occlusion만으로 원래 의도한 동작이 나옴. 트레이드오프로 라벨 노드 수가 축당 n배 증가(경계 고정 방식은 축당 2개 고정, 새 방식은 축당 2n개) — 4×4×4 퍼즐(스테이지 7~11) 기준 라인당 8개, 프로토타입 규모에서는 허용 범위로 판단.
헤드리스 검증: `godot --headless --quit-after 60 Main.tscn` 스크립트 파싱/런타임 에러 없이 클린 종료 확인, `tests/test_puzzle_model.gd`(23 passed) / `tests/test_axis_gizmo.gd`(12 passed) 회귀 전부 통과 (→ [[architecture]], [[core-decisions]]).
