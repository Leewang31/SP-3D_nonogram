# scripts/GameState.gd
extends Node

const DEFAULT_PUZZLE_PATH := "res://puzzles/tutorial_01.json"

var selected_puzzle_path: String = DEFAULT_PUZZLE_PATH
var stage_number: int = 1

func select(puzzle_path: String, stage: int) -> void:
	selected_puzzle_path = puzzle_path
	stage_number = stage
