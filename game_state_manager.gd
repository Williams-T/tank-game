extends Node

var players : Array[Tank] = []
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
func declare_projectile(projectile : Projectile):
	Cam.targets.append(projectile)

func remove_projectile(projectile : Projectile):
	Cam.targets.erase(projectile)
