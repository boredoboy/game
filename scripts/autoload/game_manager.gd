extends Node

signal stats_changed(kills: int, score: int)
signal wave_changed(wave: int)

var kills := 0
var score := 0
var current_wave := 0
var player: Node3D

func begin_run(player_node: Node3D) -> void:
	kills = 0
	score = 0
	current_wave = 0
	player = player_node
	stats_changed.emit(kills, score)
	wave_changed.emit(current_wave)

func set_wave(value: int) -> void:
	current_wave = value
	wave_changed.emit(current_wave)

func register_kill(points: int) -> void:
	kills += 1
	score += points
	stats_changed.emit(kills, score)
