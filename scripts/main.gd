extends Node
## Cena raiz e roteador de telas: pré-renderiza o atlas dos monstros, mostra o título e inicia o jogo.
## Com o argumento --shots roda o executor de capturas de tela (QA visual).

var _cur: Node

func _ready() -> void:
	await MonsterAtlas.bake(self)
	if OS.get_cmdline_user_args().has("--shots"):
		add_child(ShotRunner.new())
		return
	if OS.get_cmdline_user_args().has("--autoplay"):
		_start_game(false)
		return
	_show_menu()

func _exit_tree() -> void:
	UIKit.release()
	Art.release()
	MonsterAtlas.release()
	Baker.release()

func _swap(n: Node) -> void:
	if _cur != null:
		_cur.queue_free()
	_cur = n
	add_child(n)

func _show_menu() -> void:
	var m := MenuScreen.new()
	m.play_requested.connect(_start_game)
	_swap(m)

func _start_game(new_game: bool) -> void:
	var gs := GameScreen.new()
	var h := Hotel.new(0)
	if not new_game and Save.has_save():
		var loaded := Hotel.new(1)
		if loaded.from_dict(Save.hotel_data):
			h = loaded
			var away := float(int(Time.get_unix_time_from_system()) - Save.saved_at)
			if away > 60.0:
				gs.offline_seconds = away
				gs.offline_gain = h.apply_offline(away)
	gs.hotel = h
	gs.back_to_menu.connect(_show_menu)
	gs.restart_requested.connect(_start_game.bind(false))
	_swap(gs)
