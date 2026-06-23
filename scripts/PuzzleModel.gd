# scripts/PuzzleModel.gd
class_name PuzzleModel

enum BlockState { INTACT, REMOVED }
enum RemoveResult { OK, WRONG, ALREADY_REMOVED }

var size: int
var _solution: Array   # [z][y][x] = 0|1
var _state: Array      # [z][y][x] = BlockState
var _removed_count: int = 0
var _to_remove_count: int = 0

func load_puzzle(data: Dictionary) -> void:
    size = data["size"]
    _solution = data["solution"]
    _state = []
    _removed_count = 0
    _to_remove_count = 0
    for z in size:
        var layer: Array = []
        for y in size:
            var row: Array = []
            for x in size:
                row.append(BlockState.INTACT)
                if _solution[z][y][x] == 0:
                    _to_remove_count += 1
            layer.append(row)
        _state.append(layer)

func remove_block(x: int, y: int, z: int) -> RemoveResult:
    if _state[z][y][x] == BlockState.REMOVED:
        return RemoveResult.ALREADY_REMOVED
    if _solution[z][y][x] == 1:
        return RemoveResult.WRONG
    _state[z][y][x] = BlockState.REMOVED
    _removed_count += 1
    return RemoveResult.OK

func get_clue(axis: int, index_a: int, index_b: int) -> int:
    var count := 0
    match axis:
        0:  # X: index_a=y, index_b=z
            for x in size:
                count += _solution[index_b][index_a][x]
        1:  # Y: index_a=x, index_b=z
            for y in size:
                count += _solution[index_b][y][index_a]
        2:  # Z: index_a=x, index_b=y
            for z in size:
                count += _solution[z][index_b][index_a]
    return count

func is_solved() -> bool:
    return _removed_count == _to_remove_count

func get_block_state(x: int, y: int, z: int) -> BlockState:
    return _state[z][y][x]
