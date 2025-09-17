extends Node

var players : Array[Tank] = []
var player_distance := 0.0
var current_player = 0
enum game_mode {
	
}

func start_game():
	players[current_player].is_active = true

func end_turn(player : Tank):
	player.is_active = false
	current_player = wrapi(current_player + 1, 0, players.size())
	players[current_player].is_active = true
	players[current_player].fired_projectile = false

func declare_player(player : Tank):
	if !players.has(player):
		players.append(player)
		Cam.targets.append(player)
	if players.size() == 2:
		start_game()
func declare_projectile(projectile):
	Cam.targets.append(projectile)

func remove_projectile(projectile):
	Cam.targets.erase(projectile)

func _process(delta: float) -> void:
	player_distance = players[0].global_position.distance_to(players[1].global_position)
	if player_distance > 2000.0:
		if !Cam.split:
			Cam.split = true
	else:
		if Cam.split:
			Cam.split = false
