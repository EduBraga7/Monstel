class_name MenuScreen
extends Node
## Tela de título: logo animado, torre ao luar, monstrinhos de plantão e os botões Jogar/Continuar.

signal play_requested(new_game: bool)

class TitleArt extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var vs := get_viewport().get_visible_rect().size
		var gy := vs.y * 0.78
		var cx := vs.x * 0.5
		# colinas
		var hills := PackedVector2Array([Vector2(0, gy)])
		for i in range(0, 13):
			var x := vs.x * float(i) / 12.0
			hills.append(Vector2(x, gy - 90.0 - sin(float(i) * 1.1) * 38.0))
		hills.append(Vector2(vs.x, gy))
		draw_colored_polygon(hills, Color("1d0f3d"))
		# torre
		var tw := 420.0
		var th := vs.y * 0.34
		var top := gy - th
		draw_rect(Rect2(cx - tw * 0.5, top, tw, th), Color("2a1a52"))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - tw * 0.5 - 30, top), Vector2(cx, top - 190), Vector2(cx + tw * 0.5 + 30, top)]), Color("3a2478"))
		draw_circle(Vector2(cx, top - 70), 34, Color("ffd978"))
		for r in range(6):
			for c in range(4):
				var wx := cx - tw * 0.5 + 40.0 + float(c) * 92.0
				var wy := top + 40.0 + float(r) * (th - 90.0) / 5.0
				var lit := int(floor(t * 0.6 + float(r * 3 + c) * 1.7)) % 5 != 0
				Art.rrect(self, Rect2(wx, wy, 50, 62), Color("ffd36b") if lit else Color("1b0f38"), 10.0)
		# chão
		draw_rect(Rect2(0, gy, vs.x, vs.y - gy), Color("0f3a40"))
		draw_rect(Rect2(0, gy, vs.x, 10), Color("2f8a74"))

var sky: SkyLayer
var ui: Control
var _crowd: Node2D
var _monsters: Array[MonsterView] = []

func _ready() -> void:
	sky = SkyLayer.new()
	add_child(sky)
	sky.set_hour(22.6)
	sky.set_moon(Vector2(0.83, 0.315))     # fora do caminho do logo
	var art := TitleArt.new()
	add_child(art)
	_crowd = Node2D.new()
	add_child(_crowd)
	_build_ui()
	_spawn_crowd()
	Sfx.start_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:      # botão Voltar do Android no título: sai do jogo
		get_tree().quit()

func _process(delta: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	for mv in _monsters:
		mv.update_view(delta, 1.0, Vector2.ZERO)
		if mv.guest != null and randf() < delta * 0.18:
			mv.guest.emote = &"heart"
			mv.guest.emote_t = 1.6
		if mv.guest != null and mv.guest.emote_t > 0.0:
			mv.guest.emote_t -= delta
			if mv.guest.emote_t <= 0.0:
				mv.guest.emote = &""
	_crowd.position = Vector2(0, vs.y * 0.78 + 42.0)

func _spawn_crowd() -> void:
	var vs := get_viewport().get_visible_rect().size
	var species: Array[StringName] = [&"zombie", &"witch", &"ghost", &"vampire", &"werewolf", &"mummy"]
	_crowd.scale = Vector2(1.7, 1.7)
	var n := species.size()
	for i in range(n):
		var g := Guest.new()
		g.species = species[i]
		g.x = (vs.x / 1.7) * (float(i) + 0.5) / float(n)
		g.prev_x = g.x
		g.facing = 1.0 if i % 2 == 0 else -1.0
		g.state = Guest.S.QUEUE
		g.floor_f = 0.0
		g.prev_floor = 0.0
		var mv := MonsterView.new()
		mv.bind_guest(g)
		_crowd.add_child(mv)
		_monsters.append(mv)
	_crowd.position = Vector2(0, vs.y * 0.78 + 42.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_bottom", 90)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var v := UIKit.vbox(18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	# logo com letras que quicam
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", 2)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := [Color("ff9f43"), Color("ffd166"), Color("7ee081"), Color("2fd8bd"), Color("ff7eb6"), Color("c9a8ff"), Color("ff9f43")]
	var word := "MONSTEL"
	for i in range(word.length()):
		var l := UIKit.label(word[i], 168, cols[i], 700)
		l.add_theme_constant_override("outline_size", 22)
		l.add_theme_color_override("font_outline_color", Color("2a1838"))
		l.pivot_offset = Vector2(60, 100)
		logo.add_child(l)
		var tw := l.create_tween().set_loops()
		tw.tween_interval(float(i) * 0.12)
		tw.tween_property(l, "position:y", -16.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.9)
	v.add_child(logo)
	var tag := UIKit.label(Loc.t("menu.tagline"), 38, UIKit.C_TEXT, 500)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)
	v.add_child(UIKit.spacer())
	var play := UIKit.button(Loc.t("menu.continue") if Save.has_save() else Loc.t("menu.play"), &"primary", 64)
	play.custom_minimum_size = Vector2(0, 150)
	play.pressed.connect(func() -> void: play_requested.emit(false))
	v.add_child(play)
	var pt := play.create_tween().set_loops()
	pt.tween_property(play, "scale", Vector2(1.03, 1.03), 0.6).set_trans(Tween.TRANS_SINE)
	pt.tween_property(play, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	if Save.has_save():
		var ng := UIKit.button(Loc.t("menu.new_game"), &"ghost", 36)
		ng.pressed.connect(_ask_new_game)
		v.add_child(ng)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for l2 in [["pt", "PT"], ["en", "EN"]]:
		var b := UIKit.button(l2[1], &"segment", 32)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 70)
		var code: String = l2[0]
		b.set_pressed_no_signal(Loc.lang == code)
		b.pressed.connect(func() -> void:
			Save.set_setting("lang", code)
			get_tree().reload_current_scene())
		row.add_child(b)
	var mus := UIKit.button(Loc.t("settings.music"), &"segment", 28)
	mus.toggle_mode = true
	mus.set_pressed_no_signal(bool(Save.settings.get("music", true)))
	mus.pressed.connect(func() -> void: Save.set_setting("music", mus.button_pressed))
	row.add_child(mus)
	var snd := UIKit.button(Loc.t("settings.sfx"), &"segment", 28)
	snd.toggle_mode = true
	snd.set_pressed_no_signal(bool(Save.settings.get("sfx", true)))
	snd.pressed.connect(func() -> void: Save.set_setting("sfx", snd.button_pressed))
	row.add_child(snd)
	v.add_child(row)

func _ask_new_game() -> void:
	var m := Modal.open(ui, Loc.t("menu.new_confirm_title"), Loc.t("menu.new_confirm_body"), [["no", Loc.t("menu.cancel"), "ghost"], ["yes", Loc.t("menu.confirm"), "danger"]], null, &"close")
	m.chosen.connect(func(id: String) -> void:
		if id == "yes":
			Save.delete_save()
			play_requested.emit(true))
