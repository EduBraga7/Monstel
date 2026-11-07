class_name GameScreen
extends Node
## Tela de jogo: monta céu, mundo (torre + câmera), entrada e interface, e liga tudo
## (áudio, salvamento automático, ganhos offline, recompensa diária, modo foto, menu).

signal back_to_menu
signal restart_requested              # recria a tela (ex.: troca de idioma: todos os textos são montados na criação)

const TOWER_X := 40.0                # a torre (0..1000) fica centrada na tela de 1080 de largura
const GROUND_BELOW := 190.0
const SAVE_EVERY := 15.0

var hotel: Hotel
var sky: SkyLayer
var world: Node2D
var cam: Camera2D
var tower: TowerView
var hud: Hud
var winput: WorldInput
var offline_seconds := 0.0
var offline_gain := 0.0

var cam_y := -780.0
var zoom := 0.92
var vel_y := 0.0

var _dragging := false
var _focus_tw: Tween
var _zoom_tw: Tween
var _paused_at := 0
var _save_t := 0.0
var _photo: PhotoOverlay
var _photo_layer: CanvasLayer

func _ready() -> void:
	if hotel == null:
		hotel = Hotel.new(0)
	sky = SkyLayer.new()
	add_child(sky)
	world = Node2D.new()
	add_child(world)
	tower = TowerView.new()
	tower.position = Vector2(TOWER_X, 0)
	world.add_child(tower)
	tower.setup(hotel)
	tower.sky = sky
	cam = Camera2D.new()
	world.add_child(cam)
	cam.position = Vector2(540.0, cam_y)
	cam.make_current()
	var il := CanvasLayer.new()
	il.layer = 1
	add_child(il)
	winput = WorldInput.new()
	il.add_child(winput)
	hud = Hud.new()
	add_child(hud)
	hud.setup(hotel, tower)
	winput.tapped.connect(_on_tap)
	winput.dragged.connect(_on_drag)
	winput.released.connect(_on_release)
	winput.zoomed.connect(_on_zoom)
	tower.floor_tapped.connect(func(i: int) -> void: hud.open_room(i))
	tower.plot_tapped.connect(func() -> void: hud.open_build())
	tower.coins_collected_at.connect(_on_coins_collected)
	hud.focus_floor_requested.connect(func(i: int) -> void: focus_world_y(tower.floor_center(i).y))
	hud.focus_plot_requested.connect(func() -> void: focus_world_y(tower.scenery.plot_rect().get_center().y))
	hud.menu_requested.connect(func() -> void: hud.open_sheet(hud.settings_sheet))
	hud.zoom_toggle_requested.connect(_toggle_zoom)
	hud.settings_sheet.photo_requested.connect(_enter_photo)
	hud.settings_sheet.menu_requested.connect(_to_menu)
	hud.settings_sheet.reset_requested.connect(_confirm_reset)
	hud.settings_sheet.name_changed.connect(_refresh_sign)
	hotel.room_built.connect(func(i: int) -> void:
		if hud.active == null or not hud.active.is_open:
			focus_world_y(tower.floor_center(i).y))
	hotel.vip_arrived.connect(func(_g: Guest) -> void:
		if hud.active == null or not hud.active.is_open:
			focus_world_y(tower.floor_center(0).y))
	var vs := get_viewport().get_visible_rect().size
	zoom = clampf(minf(0.92, (vs.x - 40.0) / 1000.0), 0.3, 1.3)
	_wire_audio()
	Sfx.start_music()
	_refresh_sign()
	get_tree().set_auto_accept_quit(false)
	Loc.language_changed.connect(_on_language_changed)
	_flow.call_deferred()

func _on_language_changed() -> void:
	save_now()
	get_tree().set_auto_accept_quit(true)
	restart_requested.emit()

## Liga os eventos da simulação aos sons e à vibração.
func _wire_audio() -> void:
	hotel.coins_collected.connect(func(_f: int, a: float) -> void:
		Sfx.coin(a)
		Haptics.tap(12))
	hotel.room_built.connect(func(_i: int) -> void:
		Sfx.play(&"build")
		Haptics.tap(40))
	hotel.room_upgraded.connect(func(_i: int) -> void:
		Sfx.play(&"upgrade")
		Haptics.tap(25))
	hotel.staff_changed.connect(func() -> void: Sfx.play(&"upgrade", 1.2, -4.0))
	hotel.level_up.connect(func(_l: int) -> void:
		Sfx.play(&"levelup")
		Haptics.tap(70))
	hotel.goal_ready.connect(func(_id: String) -> void: Sfx.play(&"star"))
	hotel.goal_claimed.connect(func(_id: String, _r: float) -> void:
		Sfx.play(&"goal")
		Haptics.tap(30))
	hotel.species_discovered.connect(func(_s: StringName) -> void: Sfx.play(&"boo"))
	hotel.vip_arrived.connect(func(_g: Guest) -> void: Sfx.play(&"vip"))
	hotel.inspector_arrived.connect(func(_g: Guest) -> void: Sfx.play(&"star", 0.8))
	hotel.rush_started.connect(func() -> void:
		Sfx.play(&"rush")
		Haptics.tap(60))
	hotel.review_posted.connect(func(rv: Dictionary) -> void:
		var st := int(rv.get("stars", 3))
		if st >= 5 and randf() < 0.5:
			Sfx.play(&"star", 1.0, -6.0)
		elif st <= 1:
			Sfx.play(&"bad", 1.0, -4.0))

func _refresh_sign() -> void:
	tower.scenery.sign_text = Save.hotel_name()
	tower.scenery.refresh()

# --- fluxo de abertura: nome, ganhos offline, recompensa diária ------------------------------

func _flow() -> void:
	await get_tree().process_frame
	if str(Save.settings.get("hotel_name", "")) == "":
		await _ask_name()
	if offline_gain >= 1.0:
		await _show_offline()
	await _daily_reward()

func _ask_name() -> void:
	var names: Array = Loc.t("name.suggestions").split("|")
	var le := LineEdit.new()
	le.max_length = 18
	le.text = str(names[randi() % names.size()])
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_override("font", UIKit.font(700))
	le.add_theme_font_size_override("font_size", 46)
	le.add_theme_stylebox_override("normal", UIKit.box(Color("1b0f38"), 24, UIKit.C_LINE, 3))
	le.add_theme_stylebox_override("focus", UIKit.box(Color("1b0f38"), 24, UIKit.C_MINT, 3))
	le.custom_minimum_size = Vector2(0, 96)
	var m := Modal.open(hud.root, Loc.t("name.title"), Loc.t("name.body"), [["ok", Loc.t("name.ok"), "primary"]], le, &"build")
	await m.chosen
	var chosen_name := le.text.strip_edges()
	Save.set_setting("hotel_name", chosen_name if chosen_name != "" else str(names[0]))
	_refresh_sign()

func _show_offline() -> void:
	var m := Modal.open(hud.root, Loc.t("offline.title"), Loc.t("offline.body", [Fmt.duration(offline_seconds), Fmt.coins(offline_gain)]), [["ok", Loc.t("offline.collect"), "primary"]], null, &"moon")
	await m.chosen
	var screen := get_viewport().get_visible_rect().size * 0.5
	var got := hotel.collect(0, false)
	if got > 0.0:
		hud.fly_coins(screen, got)
		Sfx.coin(got)

func _daily_reward() -> void:
	var today := Save.today()
	var last := int(Save.settings.get("daily_day", -1))
	if today == last:
		return
	var streak := int(Save.settings.get("daily_streak", 0))
	streak = streak + 1 if (last >= 0 and today == last + 1) else 1
	Save.settings["daily_day"] = today
	Save.settings["daily_streak"] = streak
	if last < 0:                                   # primeira vez: sem pop-up durante o tutorial
		Save.save_settings()
		return
	var reward := roundf(maxf(120.0, hotel.income_ema * 90.0 * (1.0 + 0.1 * float(mini(streak, 7)))))
	var rush := streak % 3 == 0
	var body := Loc.t("daily.body", [streak, Fmt.coins(reward)])
	if rush:
		body += "\n" + Loc.t("daily.rush")
	var m := Modal.open(hud.root, Loc.t("daily.title"), body, [["ok", Loc.t("daily.claim"), "primary"]], null, &"star")
	await m.chosen
	hotel.money += reward
	if rush:
		hotel.rush_charges = mini(3, hotel.rush_charges + 1)
	Save.save_settings()
	hud.fly_coins(get_viewport().get_visible_rect().size * 0.5, reward)
	Sfx.play(&"goal")

# --- salvar / sair -------------------------------------------------------------------------

func save_now() -> void:
	Save.save_hotel(hotel)

func _process(delta: float) -> void:
	_save_t += delta
	if _save_t >= SAVE_EVERY:
		_save_t = 0.0
		save_now()
	var vs := get_viewport().get_visible_rect().size
	if not _dragging:
		cam_y += vel_y * delta
		vel_y *= exp(-delta * 4.5)
		if absf(vel_y) < 6.0:
			vel_y = 0.0
	else:
		vel_y *= exp(-delta * 12.0)         # se o dedo parar, a velocidade de "arremesso" some
	var zl := _zoom_limits(vs)
	zoom = clampf(zoom, zl.x, zl.y)
	var cr := _cam_range(vs)
	if _dragging:
		cam_y = clampf(cam_y, cr.x, cr.y)
	else:
		var wanted := clampf(cam_y, cr.x, cr.y)
		if wanted != cam_y:                    # fora da faixa (ex.: folha fechou): volta suavemente
			cam_y = lerpf(cam_y, wanted, 1.0 - exp(-delta * 10.0))
	cam.position = Vector2(540.0, cam_y)
	cam.zoom = Vector2(zoom, zoom)
	var half := vs / (2.0 * zoom)
	var center_local := cam.position - tower.position
	tower.view_rect = Rect2(center_local - half, half * 2.0)
	tower.look_world = world.get_global_mouse_position()
	sky.set_scroll(cam_y)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_paused_at = int(Time.get_unix_time_from_system())
			if hotel != null:
				save_now()
			Engine.max_fps = 10
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if hotel != null:
				save_now()
			Engine.max_fps = 10
		NOTIFICATION_APPLICATION_RESUMED:
			Engine.max_fps = 60
			_credit_away_time()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			Engine.max_fps = 60
		NOTIFICATION_WM_CLOSE_REQUEST:
			if hotel != null:
				save_now()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()

## No celular o app pode ficar na memória enquanto o jogador usa outro: ao voltar, credita o tempo fora
## como no ganho offline da abertura (só no pause/resume de verdade; no PC o jogo segue rodando).
func _credit_away_time() -> void:
	if _paused_at <= 0 or hotel == null:
		return
	var away := float(int(Time.get_unix_time_from_system()) - _paused_at)
	_paused_at = 0
	if away < 60.0 or away > 30.0 * 86400.0:          # curto demais, ou relógio do aparelho mudou
		return
	offline_seconds = away
	offline_gain = hotel.apply_offline(away)
	if offline_gain >= 1.0:
		_show_offline()

func _on_back() -> void:
	if _photo != null:
		_exit_photo()
	elif hud.active != null and hud.active.is_open:
		hud.close_all()
	else:
		_to_menu()

func _to_menu() -> void:
	save_now()
	get_tree().set_auto_accept_quit(true)
	back_to_menu.emit()

func _confirm_reset() -> void:
	var m := Modal.open(hud.root, Loc.t("settings.reset_title"), Loc.t("settings.reset_body"), [["no", Loc.t("menu.cancel"), "ghost"], ["yes", Loc.t("menu.confirm"), "danger"]], null, &"close")
	m.chosen.connect(func(id: String) -> void:
		if id == "yes":
			Save.delete_save()
			get_tree().set_auto_accept_quit(true)
			back_to_menu.emit())

# --- modo foto ---------------------------------------------------------------------------------

func _enter_photo() -> void:
	if _photo != null:
		return
	hud.root.visible = false
	_photo_layer = CanvasLayer.new()
	_photo_layer.layer = 12
	add_child(_photo_layer)
	_photo = PhotoOverlay.new()
	_photo_layer.add_child(_photo)
	_photo.setup(Save.hotel_name(), hotel.built_count(), hotel.rep, hotel.level)
	_photo.closed.connect(_exit_photo)
	_photo.save_requested.connect(_save_photo)

func _exit_photo() -> void:
	if _photo == null:
		return
	_photo_layer.queue_free()
	_photo_layer = null
	_photo = null
	hud.root.visible = true

func _save_photo() -> void:
	if _photo == null:
		return
	var ph := _photo
	ph.set_buttons_visible(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	ph.set_buttons_visible(true)
	var path := "user://monstel_foto_%d.png" % int(Time.get_unix_time_from_system())
	var ok := img.save_png(path) == OK
	DisplayServer.clipboard_set(Loc.t("photo.share_text", [Save.hotel_name(), hotel.built_count(), Fmt.stars(hotel.rep)]))
	ph.flash(Loc.t("photo.saved") if ok else "...")
	Sfx.play(&"star")

# --- câmera -----------------------------------------------------------------------------

func _zoom_limits(vs: Vector2) -> Vector2:
	var span := GROUND_BELOW - tower.top_extent()
	var zmin := clampf(vs.y / span, 0.28, 0.9)
	return Vector2(zmin, 1.3)

## Faixa permitida para cam_y. Com uma folha aberta, deixa rolar mais para baixo para que o
## andar escolhido possa subir até a área livre acima dela.
func _cam_range(vs: Vector2) -> Vector2:
	var half_h := vs.y / (2.0 * zoom)
	var extra := (hud.sheet_height() / zoom) if hud != null else 0.0
	var bar := (hud.bottom_height() if hud != null else 170.0) + 24.0
	var lo := tower.top_extent() + half_h
	var hi := (bar - vs.y * 0.5) / zoom + extra       # a linha do chão do saguão fica logo acima da barra
	if lo > hi:
		var mid := (lo + hi) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)

## Botão da lupa: alterna entre a torre inteira na tela e o zoom normal.
func _toggle_zoom() -> void:
	var vs := get_viewport().get_visible_rect().size
	var zl := _zoom_limits(vs)
	var normal := clampf(minf(0.92, (vs.x - 40.0) / 1000.0), zl.x, zl.y)
	var target := zl.x if zoom > zl.x * 1.3 else normal
	if _zoom_tw != null:
		_zoom_tw.kill()
	_zoom_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tw.tween_property(self, "zoom", target, 0.4)

## Leva a câmera para que `wy` (y do mundo) fique no meio da área livre entre as barras e a folha aberta.
func focus_world_y(wy: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var top := hud.top_height() if hud != null else 0.0
	var bot := vs.y - maxf(hud.sheet_height(), hud.bottom_height() + 10.0) if hud != null else vs.y
	var yc := (top + bot) * 0.5
	var target := wy - (yc - vs.y * 0.5) / zoom
	if _focus_tw != null:
		_focus_tw.kill()
	vel_y = 0.0
	_focus_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tw.tween_property(self, "cam_y", target, 0.5)

# --- entrada --------------------------------------------------------------------------------

func _on_drag(rel: Vector2) -> void:
	_dragging = true
	if _focus_tw != null:
		_focus_tw.kill()
	var dy := -rel.y / zoom
	cam_y += dy
	vel_y = lerpf(vel_y, dy / maxf(0.001, get_process_delta_time()), 0.4)

func _on_release(_v: Vector2) -> void:
	_dragging = false

func _on_tap(pos: Vector2) -> void:
	_dragging = false
	var wpos := world.get_canvas_transform().affine_inverse() * pos
	var local := tower.to_local(wpos)
	var handled := tower.tap(local)
	if not handled and hud.active != null:
		hud.close_all()

func _on_zoom(factor: float, at: Vector2) -> void:
	var vs := get_viewport().get_visible_rect().size
	var zl := _zoom_limits(vs)
	var old := zoom
	zoom = clampf(zoom * factor, zl.x, zl.y)
	# mantém o ponto sob o dedo/mouse parado
	var wy_before := cam_y + (at.y - vs.y * 0.5) / old
	cam_y = wy_before - (at.y - vs.y * 0.5) / zoom

func _on_coins_collected(amount: float, world_pos: Vector2) -> void:
	hud.fly_coins(world.get_canvas_transform() * world_pos, amount)
