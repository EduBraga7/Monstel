class_name ShotRunner
extends Node
## Ferramenta de QA visual (só roda com o argumento --shots): renderiza o jogo num SubViewport do
## tamanho pedido e salva PNGs. Uso:
##   Godot --path <proj> -- --shots --scenario=early --out=<pasta> --w=1080 --h=1920

var args: Dictionary = {}
var out_dir := ""
var sv: SubViewport
var gs: GameScreen
var size := Vector2i(1080, 1920)

func _ready() -> void:
	Save.test_mode = true
	Save.settings["hotel_name"] = "Hotel Boo"      # sem o diálogo de nome nas capturas (o cenário "name" limpa)
	args = _parse()
	out_dir = str(args.get("out", "user://shots"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	size = Vector2i(int(args.get("w", 1080)), int(args.get("h", 1920)))
	_run.call_deferred()

func _parse() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			s = s.substr(2)
			var eq := s.find("=")
			if eq >= 0:
				out[s.substr(0, eq)] = s.substr(eq + 1)
			else:
				out[s] = "1"
	return out

func _make_viewport() -> void:
	sv = SubViewport.new()
	sv.size = size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	add_child(sv)

func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame

## Espera as texturas pré-renderizadas (andares e cenário) ficarem prontas, para a captura mostrar o caminho real.
func _wait_bakes() -> void:
	var guard := 0
	while not Baker.idle() and guard < 600:
		await get_tree().process_frame
		guard += 1
	await _wait(3)

func _shot(label: String) -> void:
	await _wait(2)
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var path := out_dir.path_join(label + ".png")
	img.save_png(path)
	print("shot: ", path, " ", img.get_size())

func _run() -> void:
	_make_viewport()
	var sc := str(args.get("scenario", "early"))
	match sc:
		"menu":
			var m := MenuScreen.new()
			sv.add_child(m)
			await _wait(30)
			await _shot("menu")
		"name":
			Save.settings["hotel_name"] = ""
			gs = GameScreen.new()
			gs.hotel = _make_hotel("early")
			sv.add_child(gs)
			await get_tree().create_timer(1.0).timeout
			await _shot("modal_name")
		"offline":
			Save.settings["hotel_name"] = "Hotel Boo"
			gs = GameScreen.new()
			gs.hotel = _make_hotel("mid")
			gs.offline_seconds = 7380.0
			gs.offline_gain = gs.hotel.apply_offline(7380.0) + 2840.0
			sv.add_child(gs)
			await get_tree().create_timer(1.0).timeout
			await _shot("modal_offline")
		"taps":
			await _taps()
		"persist":
			await _persist()
		"stress":
			await _stress()
		"gallery":
			await _gallery()
		"early":
			await _game(_make_hotel("early"), "early", false)
		"mid":
			await _game(_make_hotel("mid"), "mid", true)
		"late":
			await _game(_make_hotel("late"), "late", false)
		_:
			print("cenário desconhecido: ", sc)
	get_tree().quit()

# --- galeria de monstros ------------------------------------------------------------

class Gallery extends Node2D:
	var t := 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1080, 1920), Color("2a1a4a"))
		var species := [&"ghost", &"zombie", &"vampire", &"mummy", &"witch", &"werewolf", &"bat"]
		var moods := [MonsterArt.Mood.NEUTRAL, MonsterArt.Mood.HAPPY, MonsterArt.Mood.ANGRY, MonsterArt.Mood.SLEEPY, MonsterArt.Mood.SCARED]
		for r in range(species.size()):
			var y := 230.0 + float(r) * 255.0
			draw_string(UIKit.font(700), Vector2(20, y - 90), str(species[r]), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("ffd166"))
			for c in range(moods.size()):
				var x := 150.0 + float(c) * 190.0
				MonsterArt.draw(self, species[r], t + float(c), 0.0, moods[c], 0.0, Vector2(0.4, 0.1), 1.0, Vector2(x, y), 0.0, Vector2(1.7, 1.7))
			MonsterArt.draw(self, species[r], t, 1.0, MonsterArt.Mood.NEUTRAL, 0.0, Vector2.ZERO, -1.0, Vector2(1010, y), 0.0, Vector2(1.7, 1.7))

func _gallery() -> void:
	var g := Gallery.new()
	sv.add_child(g)
	await _wait(8)
	await _shot("gallery")

# --- teste de interação (sem capturas): toques, coleta, painéis e construção ------------------

var _fails := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1

## Posição na tela (coordenadas do viewport) de um ponto local da torre.
func _screen_of(local: Vector2) -> Vector2:
	return gs.world.get_canvas_transform() * gs.tower.to_global(local)

func _taps() -> void:
	var h := _make_hotel("mid")
	h.money = 100.0
	gs = GameScreen.new()
	gs.hotel = h
	sv.add_child(gs)
	await _wait(8)
	# 1) coleta por toque no balão
	var f := -1
	for i in range(h.floors.size()):
		if h.floors[i].pending > 1.0:
			f = i
			break
	_check(f >= 0, "há andar com moedas pendentes")
	if f >= 0:
		gs.focus_world_y(gs.tower.floor_center(f).y)
		await get_tree().create_timer(0.8).timeout
		await _wait(3)
		var before := h.money
		var pend := h.floors[f].pending
		var bubble_local := Vector2(Geo.FLOOR_W - 70.0, -float(f) * Geo.FLOOR_H - 170.0)
		gs._on_tap(_screen_of(bubble_local))
		_check(h.floors[f].pending < 0.01 and h.money > before + pend * 0.99, "toque no balão coleta as moedas (+%d)" % int(pend))
	# 2) toque num andar abre a folha do andar
	await _wait(3)
	var local_floor := Vector2(500.0, -1.0 * Geo.FLOOR_H - 120.0)
	gs.hud.close_all()
	await get_tree().create_timer(0.4).timeout
	gs.focus_world_y(gs.tower.floor_center(1).y)
	await get_tree().create_timer(0.7).timeout
	gs._on_tap(_screen_of(local_floor))
	_check(gs.hud.active == gs.hud.room_sheet and gs.hud.room_sheet.floor_idx == 1, "toque num andar abre a folha dele")
	# 3) melhorar o andar pela folha
	h.money = 1.0e6
	var lvl_before := h.floors[1].level
	gs.hud.room_sheet.up_btn.pressed.emit()
	await _wait(3)
	_check(h.floors[1].level == lvl_before + 1, "botão Melhorar sobe o nível do andar")
	# 4) toque no terreno vazio abre a folha de construção e construir funciona
	gs.hud.close_all()
	await get_tree().create_timer(0.4).timeout
	var n_before := h.floors.size()
	gs.hud.open_build()
	await get_tree().create_timer(0.5).timeout
	_check(gs.hud.active == gs.hud.build_sheet, "abrir Construir mostra a folha")
	var row: Dictionary = gs.hud.build_sheet.rows[&"suite"]
	(row["btn"] as Button).pressed.emit()
	await _wait(4)
	_check(h.floors.size() == n_before + 1, "construir uma suíte pela folha adiciona o andar")
	_check(gs.tower.floor_views.size() == h.floors.size(), "a torre criou a vista do novo andar")
	# 5) contratar e velocidade
	await _wait(2)
	gs.hud.open_sheet(gs.hud.staff_sheet)
	await get_tree().create_timer(0.4).timeout
	var cashier_before := h.staff_count(&"cashier")
	var srow: Dictionary = gs.hud.staff_sheet.rows[&"bellhop"]
	var bellhops := h.staff_count(&"bellhop")
	(srow["hire"] as Button).pressed.emit()
	await _wait(2)
	_check(h.staff_count(&"bellhop") == bellhops + 1 or h.staff_count(&"bellhop") == h.staff_cap(&"bellhop"), "contratar funciona (ou já está no teto)")
	gs.hud._set_speed(3)
	_check(gs.tower.speed == 4.0 and not gs.tower.paused, "botão 4x muda a velocidade")
	gs.hud._set_speed(0)
	_check(gs.tower.paused, "botão de pausa pausa a simulação")
	# 6) a simulação anda e nada quebra por alguns segundos
	gs.hud._set_speed(3)
	gs.hud.close_all()
	var t0 := h.time
	await get_tree().create_timer(2.0).timeout
	_check(h.time > t0 + 3.0, "simulação avança a 4x (%.1fs de jogo em ~2s)" % (h.time - t0))
	# 6b) a lupa alterna entre a torre inteira e o zoom normal
	gs.hud.close_all()
	await get_tree().create_timer(0.4).timeout
	var z0 := gs.zoom
	gs.hud.zoom_btn.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	var z1 := gs.zoom
	gs.hud.zoom_btn.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	var z2 := gs.zoom
	_check(z1 < z0 * 0.9 and absf(z2 - z0) < 0.05, "lupa: afasta para ver a torre (%.2f -> %.2f) e volta (%.2f)" % [z0, z1, z2])
	# 6c) app volta do segundo plano (celular): o tempo fora vira baú de moedas e aparece o aviso
	var expected := h.offline_gain(7200.0)
	var money_before := h.money
	gs._notification(NOTIFICATION_APPLICATION_PAUSED)
	gs._paused_at -= 7200
	gs._notification(NOTIFICATION_APPLICATION_RESUMED)
	await _wait(3)
	var modal_open := false
	for n in gs.hud.root.get_children():
		if n is Modal:
			modal_open = true
			(n as Modal)._pick("ok")                      # "Coletar": o baú do saguão vira dinheiro
	await _wait(2)
	_check(expected > 1.0 and modal_open and h.money >= money_before + expected * 0.99, "voltar do segundo plano mostra o aviso e credita o tempo fora (esperado +%d, veio +%d)" % [int(expected), int(h.money - money_before)])
	# 7) trocar o idioma pelas configurações recria a tela (todos os textos são montados na criação)
	var restarted := [false]
	gs.restart_requested.connect(func() -> void: restarted[0] = true)
	Save.set_setting("lang", "en")
	_check(bool(restarted[0]) and Loc.lang == "en", "trocar o idioma em jogo pede para recriar a tela")
	Save.set_setting("lang", "pt")
	print("FALHAS: ", _fails)
	_unused(cashier_before)

func _unused(_v: Variant) -> void:
	pass

# --- estresse: torre cheia a 4x, mede tempo de quadro, draw calls, nós e custo da simulação ----------

func _stress() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var h := _make_hotel("late")
	h.advance(900.0)
	gs = GameScreen.new()
	gs.hotel = h
	sv.add_child(gs)
	await get_tree().create_timer(1.0).timeout
	await _wait_bakes()
	gs.hud._set_speed(3)
	for phase in ["zoomout", "zoomin"]:
		if phase == "zoomout":
			gs.zoom = 0.3
		else:
			gs.zoom = 0.9
			gs.focus_world_y(gs.tower.floor_center(8).y)
		await get_tree().create_timer(1.0).timeout
		var n := 0
		var t_sum := 0.0
		var t_max := 0.0
		var dc_max := 0
		var nodes := 0
		var guests_max := 0
		var t_end := Time.get_ticks_msec() + 5000
		var last := Time.get_ticks_usec()
		while Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var dt_ms := float(now - last) / 1000.0
			last = now
			n += 1
			t_sum += dt_ms
			t_max = maxf(t_max, dt_ms)
			dc_max = maxi(dc_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			guests_max = maxi(guests_max, h.guests.size())
		var avg := t_sum / maxf(1.0, float(n))
		print("%s: %d quadros em 5 s | média %.2f ms (%.0f fps) | pior %.1f ms | draw calls máx %d | nós %d | hóspedes máx %d | andares %d" % [phase, n, avg, 1000.0 / maxf(0.001, avg), t_max, dc_max, nodes, guests_max, h.floors.size()])
		await _shot("stress_" + phase)
	var t0 := Time.get_ticks_usec()
	for i in range(2000):
		h.step(Balance.DT)
	var per := float(Time.get_ticks_usec() - t0) / 2000.0 / 1000.0
	print("simulação pura: %.3f ms por passo de 0,1 s (com %d hóspedes)" % [per, h.guests.size()])
	if args.has("dc"):
		# onde estão os draw calls? esconde uma parte por vez (zoom padrão, foco no meio da torre)
		gs.zoom = 0.9
		gs.focus_world_y(gs.tower.floor_center(8).y)
		await get_tree().create_timer(1.0).timeout
		var parts := {
			"tudo": [],
			"sem HUD": [gs.hud.root],
			"sem andares": [gs.tower.floor_layer],
			"sem monstros": [gs.tower.monster_layer],
			"sem cenário": [gs.tower.scenery],
			"sem poços": [gs.tower.shaft_view],
			"sem moedas/fx": [gs.tower.coin_layer, gs.tower.fx_layer],
		}
		for name in parts:
			var hid: Array = parts[name]
			for n in hid:
				(n as CanvasItem).visible = false
			await _wait(3)
			var dc := 0
			for k in range(5):
				await get_tree().process_frame
				dc = maxi(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			print("  draw calls %-14s %d" % [name, dc])
			for n in hid:
				(n as CanvasItem).visible = true

# --- teste de persistência, offline e textos (sem capturas) ----------------------------------------

## Compara dois valores vindos de dicionários salvos (números com tolerância relativa).
func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k in da:
			if not db.has(k) or not _same(da[k], db[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in range(aa.size()):
			if not _same(aa[i], ab[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		var fa := float(a)
		var fb := float(b)
		return absf(fa - fb) <= 1e-6 * maxf(1.0, maxf(absf(fa), absf(fb)))
	return str(a) == str(b)

func _persist() -> void:
	var real_path := Save.path
	var real_bak := Save.bak_path
	Save.path = "user://qa_save.json"
	Save.bak_path = "user://qa_save.bak.json"
	Save.test_mode = false
	for p in [Save.path, Save.bak_path, Save.path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	# 1) hotel -> disco -> hotel idêntico
	var h := _make_hotel("mid")
	h.advance(180.0)
	h.claim_goal()
	h.set_price(&"suite", 2)
	Save.settings["hotel_name"] = "Hotel Teste"
	Save.settings["sfx"] = false
	_check(Save.save_hotel(h), "salvar grava o arquivo")
	_check(FileAccess.file_exists(Save.path), "arquivo de save existe no disco")
	Save.hotel_data = {}
	Save.settings["hotel_name"] = ""
	Save.settings["sfx"] = true
	Save.load_all()
	_check(Save.has_save(), "carregar encontra o save")
	_check(Save.settings["hotel_name"] == "Hotel Teste" and Save.settings["sfx"] == false, "configurações voltam do disco")
	var h2 := Hotel.new(1)
	_check(h2.from_dict(Save.hotel_data), "Hotel.from_dict aceita o save")
	var d1 := h.to_dict()
	var d2 := h2.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d1))
	_check(_same(parsed, d2), "estado restaurado == estado salvo (to_dict idêntico)")
	for k in d1:
		if not _same((parsed as Dictionary)[k], d2[k]):
			print("   difere em: ", k, " salvo=", str((parsed as Dictionary)[k]).left(120), " restaurado=", str(d2[k]).left(120))
	# 2) o hotel restaurado continua funcionando (hóspedes não são salvos: voltam a chegar)
	var money0 := h2.money
	h2.advance(600.0)
	_check(h2.guests.size() > 0 or h2.stat(&"served") > float(h.stat(&"served")), "hotel restaurado volta a receber hóspedes")
	_check(not is_nan(h2.money) and h2.money >= 0.0 and h2.rep >= 1.0 and h2.rep <= 5.0 and h2.money != money0, "hotel restaurado segue válido após 10 min")
	# 3) arquivo corrompido -> usa o backup
	Save.save_hotel(h2)                                  # 2º save cria o .bak com o 1º
	var f := FileAccess.open(Save.path, FileAccess.WRITE)
	f.store_string("{isto nao e json")
	f.close()
	Save.hotel_data = {}
	Save.load_all()
	_check(Save.has_save(), "save corrompido: recupera do backup")
	# 4) save com campos absurdos não derruba o jogo
	var evil := d1.duplicate(true)
	evil["money"] = -50.0
	evil["rep"] = 99.0
	evil["level"] = -3
	evil["floors"].append({"type": "inexistente", "level": 99})
	evil["staff_n"] = {"maid": 9999, "alienigena": 3}
	evil["goal_idx"] = 9999
	var h3 := Hotel.new(1)
	_check(h3.from_dict(evil), "save adulterado é aceito com valores corrigidos")
	_check(h3.money >= 0.0 and h3.rep <= 5.0 and h3.level >= 1 and h3.staff_count(&"maid") <= h3.staff_cap(&"maid"), "valores absurdos são limitados")
	h3.advance(120.0)
	_check(true, "simulação roda 2 min após save adulterado sem erro")
	_check(not Hotel.new(1).from_dict({"floors": [], "version": 1}), "save sem andares é recusado")
	# 5) offline
	var hh := _make_hotel("mid")
	hh.advance(300.0)
	var g2 := hh.offline_gain(7200.0)
	var net := maxf(0.0, hh.income_ema - hh.wage_per_day() / Balance.DAY_LEN)
	_check(absf(g2 - net * 7200.0 * Balance.OFFLINE_EFFICIENCY) < 0.01, "ganho offline = renda líquida × tempo × eficiência (%.0f em 2 h)" % g2)
	_check(is_equal_approx(hh.offline_gain(100.0 * 3600.0), hh.offline_gain(Balance.OFFLINE_CAP_H * 3600.0)), "ganho offline respeita o teto de %d h" % int(Balance.OFFLINE_CAP_H))
	_check(hh.offline_gain(-5.0) == 0.0, "tempo negativo (relógio do aparelho mudou) não dá moedas")
	var pend0 := hh.floors[0].pending
	var got := hh.apply_offline(7200.0)
	_check(is_equal_approx(hh.floors[0].pending, pend0 + got), "ganho offline vira baú de moedas no saguão")
	# 6) textos: paridade PT/EN, avaliações e nomes
	var missing := 0
	var tables := {}
	var jf := FileAccess.open("res://data/i18n.json", FileAccess.READ)
	tables = JSON.parse_string(jf.get_as_text())
	for k in (tables["pt"] as Dictionary):
		if not (tables["en"] as Dictionary).has(k):
			missing += 1
			print("   falta em EN: ", k)
	for k in (tables["en"] as Dictionary):
		if not (tables["pt"] as Dictionary).has(k):
			missing += 1
			print("   falta em PT: ", k)
	_check(missing == 0, "chaves de texto PT e EN batem (%d chaves)" % (tables["pt"] as Dictionary).size())
	var species_list := ["ghost", "zombie", "vampire", "mummy", "witch", "werewolf"]
	var factors := ["generic", "reception", "elevator", "comfort", "price", "clean", "facility", "stairs", "vip"]
	var empty := 0
	var longest := 0
	for lang in ["pt", "en"]:
		Loc.set_language(lang)
		for sp in species_list:
			for fc in factors:
				for stars in range(1, 6):
					for sd in [0, 7, 19, 123, 4567]:
						var tx := Loc.review_text({"species": sp, "factor": fc, "stars": stars, "seed": sd, "positive": stars >= 3})
						if tx == "":
							empty += 1
						longest = maxi(longest, tx.length())
			for ns in range(0, 12):
				if Loc.guest_name(sp, ns) == "":
					empty += 1
	_check(empty == 0, "avaliações e nomes nunca saem vazios (maior texto: %d letras)" % longest)
	Loc.set_language("en")
	var en_play := Loc.t("menu.play")
	_check(en_play != "menu.play" and en_play != "", "tradução EN carrega (%s)" % en_play)
	Loc.set_language("pt")
	_check(Loc.t("menu.play") != en_play, "trocar de idioma muda o texto (%s -> %s)" % [en_play, Loc.t("menu.play")])
	# limpeza
	for p in [Save.path, Save.bak_path, Save.path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Save.path = real_path
	Save.bak_path = real_bak
	Save.test_mode = true
	print("FALHAS: ", _fails)

# --- cenários de jogo ----------------------------------------------------------------

func _make_hotel(kind: String) -> Hotel:
	var h := Hotel.new(11)
	if kind == "early":
		h.advance(40.0)
		return h
	h.money = 1.0e9
	h.level = 14
	var plan: Array[StringName] = [&"suite", &"suite", &"bar", &"suite", &"spa", &"housekeeping", &"suite", &"buffet", &"boutique", &"suite", &"gym", &"marketing"]
	if kind == "late":
		plan.append_array([&"suite", &"suite", &"suite", &"suite", &"suite", &"suite", &"suite", &"suite"] as Array[StringName])
	for t in plan:
		h.build(t)
	for f in range(1, h.floors.size()):
		if h.floors[f].type == &"suite":
			for k in range(f % 4):
				h.upgrade_room(f)
	h.hire(&"receptionist")
	h.hire(&"maid")
	h.hire(&"bellhop")
	h.hire(&"cashier")
	h.upgrade_elevator()
	h.build_shaft()
	h.advance(300.0)
	h.money = 3500.0
	return h

func _game(h: Hotel, label: String, with_sheets: bool) -> void:
	gs = GameScreen.new()
	gs.hotel = h
	sv.add_child(gs)
	await _wait(10)
	await _wait_bakes()
	await _shot(label + "_1")
	if int(args.get("focus", -1)) >= 0:
		gs.focus_world_y(gs.tower.floor_center(int(args.get("focus"))).y)
		await get_tree().create_timer(0.8).timeout
		await _shot(label + "_focus")
	if with_sheets:
		gs.hud.open_build()
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_build")
		gs.hud.open_room(1)
		await get_tree().create_timer(0.7).timeout
		await _shot(label + "_sheet_room")
		gs.hud.open_sheet(gs.hud.hotel_sheet)
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_hotel")
		gs.hud.open_sheet(gs.hud.staff_sheet)
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_staff")
		gs.hud.open_sheet(gs.hud.reviews_sheet)
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_reviews")
		gs.hud.open_sheet(gs.hud.dex_sheet)
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_dex")
		gs.hud.open_sheet(gs.hud.settings_sheet)
		await get_tree().create_timer(0.6).timeout
		await _shot(label + "_sheet_settings")
		gs.hud.close_all()
		await get_tree().create_timer(0.4).timeout
		gs.zoom = 0.4
		await get_tree().create_timer(0.5).timeout
		await _shot(label + "_zoomout")
