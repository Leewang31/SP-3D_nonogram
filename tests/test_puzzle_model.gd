# tests/test_puzzle_model.gd
extends SceneTree

const PuzzleModel = preload("res://scripts/PuzzleModel.gd")

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
    _test_confirmed_keep(data)

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
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    _assert(m.size == 3, "load_puzzle sets size=3")
    _assert(m.get_block_state(0, 0, 0) == PuzzleModel.BlockState.INTACT, "load_puzzle initial state INTACT")

func _test_remove_correct_block(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    # (0,0,0) is solution=0 → correct to remove
    var result = m.remove_block(0, 0, 0)
    _assert(result == PuzzleModel.RemoveResult.OK, "remove correct block returns OK")
    _assert(m.get_block_state(0, 0, 0) == PuzzleModel.BlockState.REMOVED, "removed block state is REMOVED")

func _test_remove_wrong_block(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    # (1,1,1) is solution=1 → WRONG to remove
    var result = m.remove_block(1, 1, 1)
    _assert(result == PuzzleModel.RemoveResult.WRONG, "remove keep-block returns WRONG")
    _assert(m.get_block_state(1, 1, 1) == PuzzleModel.BlockState.INTACT, "wrong remove leaves state INTACT")

func _test_already_removed(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    m.remove_block(0, 0, 0)
    var result = m.remove_block(0, 0, 0)
    _assert(result == PuzzleModel.RemoveResult.ALREADY_REMOVED, "double remove returns ALREADY_REMOVED")

func _test_is_solved(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    _assert(not m.is_solved(), "not solved initially")
    # Remove all blocks that should be removed (solution==0)
    for z in 3:
        for y in 3:
            for x in 3:
                if data["solution"][z][y][x] == 0:
                    m.remove_block(x, y, z)
    _assert(m.is_solved(), "is_solved after removing all correct blocks")

func _test_clue_x_axis(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    # X-axis clue: axis=0, index_a=y, index_b=z
    # (y=1, z=1) → solution[1][1] = [1,1,1] → count=3
    _assert(m.get_clue(0, 1, 1) == 3, "X-axis clue (y=1,z=1) == 3")
    # (y=0, z=0) → solution[0][0] = [0,0,0] → count=0
    _assert(m.get_clue(0, 0, 0) == 0, "X-axis clue (y=0,z=0) == 0")
    # (y=1, z=0) → solution[0][1] = [0,1,0] → count=1
    _assert(m.get_clue(0, 1, 0) == 1, "X-axis clue (y=1,z=0) == 1")

func _test_clue_z_axis(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    # Z-axis clue: axis=2, index_a=x, index_b=y
    # (x=1, y=1) → solution[*][1][1] = [1,1,1] → count=3
    _assert(m.get_clue(2, 1, 1) == 3, "Z-axis clue (x=1,y=1) == 3")
    # (x=0, y=0) → solution[*][0][0] = [0,0,0] → count=0
    _assert(m.get_clue(2, 0, 0) == 0, "Z-axis clue (x=0,y=0) == 0")

func _test_confirmed_keep(data: Dictionary) -> void:
    var m = PuzzleModel.new()
    m.load_puzzle(data)
    # X-axis row (y=1,z=1) is fully solution=1 ([1,1,1]) → intact count 3 == clue 3 from the start
    _assert(m.is_confirmed_keep(0, 1, 1), "fully-filled row is confirmed keep before any removal")
    # X-axis row (y=1,z=0): solution=[0,1,0], clue=1 → not confirmed while both 0-cells remain intact
    _assert(not m.is_confirmed_keep(1, 1, 0), "keep-block not confirmed while row still has removable cells")
    # Remove one of the two 0-cells → still not confirmed (1 removable cell left)
    m.remove_block(0, 1, 0)
    _assert(not m.is_confirmed_keep(1, 1, 0), "keep-block not confirmed with one removable cell left")
    # Remove the last 0-cell → intact count (1) == clue (1) → now confirmed
    m.remove_block(2, 1, 0)
    _assert(m.is_confirmed_keep(1, 1, 0), "keep-block confirmed once row is reduced to clue count")
