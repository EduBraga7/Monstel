class_name Hud
extends CanvasLayer
## Interface do jogo: barra superior (dinheiro, nível, reputação, relógio, Rush, velocidade),
## faixa de metas, barra inferior (navegação), "coletar tudo", avisos, setas de tutorial e as folhas.

signal focus_floor_requested(idx: int)
signal focus_plot_requested
signal menu_requested
signal zoom_toggle_requested

class LevelBadge extends Control:
	var level := 1
	var progress := 0.0
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(c, r, Color("1b0f38"))
		Art.arc(self, c, r - 7.0, -PI / 2.0, -PI / 2.0 + TAU, 8.0, Color("3c2575"), 40)
		if progress > 0.01:
			Art.arc(self, c, r - 7.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 8.0, Color("2fd8bd"), 40)
		draw_circle(c, r - 17.0, Color("5b3fa6"))
		draw_circle(c + Vector2(-5, -7), r - 30.0, Color("7a5ad0"))
		var f := UIKit.font(700)
		var s := str(level)
		var px := 46 if s.length() < 3 else 36
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string_outline(f, Vector2(c.x - w * 0.5, c.y + px * 0.34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color("2a1838"))
		draw_string(f, Vector2(c.x - w * 0.5, c.y + px * 0.34), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("fffdfa"))

## Seta que balança apontando para o alvo do tutorial.
class HintArrow extends Control:
	var t := 0.0
	var up := false          # true: seta embaixo do alvo apontando para cima
	var ring := true
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var bob := sin(t * 6.0) * 9.0
		var r := 48.0 + sin(t * 5.0) * 5.0
		if ring:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(1.0, 0.82, 0.3, 0.85), 6.0, true)
		var sgn := 1.0 if up else -1.0
		var tip := Vector2(0, sgn * (r + 8.0 + bob))
		var base := Vector2(0, sgn * (r + 52.0 + bob))
		draw_colored_polygon(PackedVector2Array([tip, base + Vector2(-26, 0), base + Vector2(26, 0)]), Color("ffd166"))
		draw_rect(Rect2(-10, minf(base.y, base.y + sgn * 40.0), 20, 40), Color("ffd166"))

var hotel: Hotel
var tower: TowerView
var root: Control
var money_label: Label
var money_icon: IconView
var rep_label: Label
var clock_label: Label
var clock_icon: IconView
var badge: LevelBadge
var speed_btns: Array[Button] = []
var rush_btn: Button
var rush_count: Label
var goal_panel: PanelContainer
var goal_label: Label
var goal_bar: ProgressBar
var goal_reward: HBoxContainer
var claim_btn: Button
var collect_btn: Button
var zoom_btn: Button
var rush_banner: PanelContainer
var rush_label: Label
var toast_box: VBoxContainer
var hint: HintArrow
var nav_btns: Dictionary = {}
var build_sheet: BuildSheet
var room_sheet: RoomSheet
var hotel_sheet: HotelSheet
var staff_sheet: StaffSheet
var reviews_sheet: ReviewsSheet
var dex_sheet: DexSheet
var settings_sheet: SettingsSheet
var active: Sheet = null
var money_shown := 0.0

var _bottom_h := 190.0
var _top_h := 250.0
var _last_money_text := ""
var _toast_count := 0

func setup(h: Hotel, tv: TowerView) -> void:
	hotel = h
	tower = tv
	layer = 10
	money_shown = h.money
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var safe := UIKit.safe_insets(self)
	_build_top(safe)
	_build_goal(safe)
	_build_bottom(safe)
	_build_misc(safe)
	build_sheet = BuildSheet.new()
	room_sheet = RoomSheet.new()
	hotel_sheet = HotelSheet.new()
	staff_sheet = StaffSheet.new()
	reviews_sheet = ReviewsSheet.new()
	dex_sheet = DexSheet.new()
	settings_sheet = SettingsSheet.new()
	settings_sheet.height_frac = 0.7
	for s: Sheet in [build_sheet, room_sheet, hotel_sheet, staff_sheet, reviews_sheet, dex_sheet, settings_sheet]:
		root.add_child(s)
		s.closed.connect(_on_sheet_closed.bind(s))
	build_sheet.built.connect(func(idx: int) -> void: focus_floor_requested.emit(idx))
	reviews_sheet.shared.connect(_on_share)
	hint = HintArrow.new()
	hint.visible = false
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	h.level_up.connect(_on_level_up)
	h.review_posted.connect(_on_review)
	h.day_ended.connect(_on_day_ended)
	h.species_discovered.connect(_on_species)
	h.goal_claimed.connect(func(_id: String, r: float) -> void: _toast(Loc.t("toast.goal", [Fmt.coins(r)]), UIKit.C_MINT, "check"))
	h.vip_arrived.connect(func(g: Guest) -> void: _toast(Loc.t("toast.vip", [Loc.guest_name(str(g.species), g.name_seed)]), UIKit.C_GOLD, "star"))
	h.inspector_arrived.connect(func(_g: Guest) -> void: _toast(Loc.t("toast.inspector"), UIKit.C_PINK, "review"))
	h.inspector_result.connect(_on_inspector_result)

func _on_sheet_closed(s: Sheet) -> void:
	if active == s:
		active = null
	tower.selected_floor = -1

# --- construção ---------------------------------------------------------------------

func _pill(color: Color = UIKit.C_PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.box(color, 40, UIKit.C_LINE, 3, 6).duplicate() as StyleBoxFlat
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	return p

func _build_top(safe: Vector4) -> void:
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22.0 + safe.x
	top.offset_right = -22.0 - safe.z
	top.offset_top = 16.0 + safe.y
	root.add_child(top)
	var r1 := UIKit.hbox(12)
	badge = LevelBadge.new()
	badge.custom_minimum_size = Vector2(104, 104)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r1.add_child(badge)
	var mp := _pill()
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mh := UIKit.hbox(12)
	money_icon = IconView.make(&"coin", 58)
	mh.add_child(money_icon)
	money_label = UIKit.label("0", 52, UIKit.C_GOLD, 700)
	mh.add_child(money_label)
	mp.add_child(mh)
	r1.add_child(mp)
	var rp := _pill()
	rp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rh := UIKit.hbox(8)
	rh.add_child(IconView.make(&"star", 50, Color("ffd166")))
	rep_label = UIKit.label("3.0", 46, UIKit.C_TEXT, 700)
	rh.add_child(rep_label)
	rp.add_child(rh)
	r1.add_child(rp)
	var gear := UIKit.button("", &"ghost", 30)
	gear.custom_minimum_size = Vector2(88, 88)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gi := IconView.make(&"gear", 48)
	gi.position = Vector2(20, 14)
	gear.add_child(gi)
	gear.pressed.connect(func() -> void: menu_requested.emit())
	r1.add_child(gear)
	top.add_child(r1)
	var r2 := UIKit.hbox(10)
	var cp := _pill(Color("22103f"))
	var ch := UIKit.hbox(10)
	clock_icon = IconView.make(&"moon", 40, Color("ffe9a8"))
	ch.add_child(clock_icon)
	clock_label = UIKit.label("", 32, UIKit.C_TEXT, 600)
	ch.add_child(clock_label)
	cp.add_child(ch)
	r2.add_child(cp)
	rush_btn = UIKit.button("", &"ghost", 28)
	rush_btn.custom_minimum_size = Vector2(150, 66)
	var rb := UIKit.hbox(6)
	rb.set_anchors_preset(Control.PRESET_FULL_RECT)
	rb.alignment = BoxContainer.ALIGNMENT_CENTER
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rb.add_child(IconView.make(&"flame", 38))
	rush_count = UIKit.label("x1", 30, UIKit.C_GOLD, 700)
	rb.add_child(rush_count)
	rush_btn.add_child(rb)
	rush_btn.pressed.connect(_on_rush)
	r2.add_child(rush_btn)
	r2.add_child(UIKit.spacer())
	var labels := ["II", "1x", "2x", "4x"]
	for i in range(4):
		var b := UIKit.button(labels[i], &"segment", 30)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(84, 66)
		b.pressed.connect(func() -> void: _set_speed(i))
		r2.add_child(b)
		speed_btns.append(b)
	top.add_child(r2)
	_top_h = 16.0 + safe.y + 104.0 + 10.0 + 70.0 + 10.0

func _build_goal(safe: Vector4) -> void:
	goal_panel = _pill(Color("22103f"))
	goal_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	goal_panel.offset_left = 22.0 + safe.x
	goal_panel.offset_right = -22.0 - safe.z
	goal_panel.offset_top = _top_h - 6.0
	var h := UIKit.hbox(14)
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_label = UIKit.label("", 28, UIKit.C_TEXT, 600)
	goal_label.clip_text = true
	goal_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(goal_label)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(0, 16)
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_bar.add_theme_stylebox_override("background", UIKit.box(Color("120a26"), 8))
	goal_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.C_MINT, 8))
	left.add_child(goal_bar)
	h.add_child(left)
	goal_reward = Sheet.price_row(0.0, true)
	goal_reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(goal_reward)
	claim_btn = UIKit.button("", &"good", 30)
	claim_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim_btn.visible = false
	claim_btn.pressed.connect(_on_claim)
	h.add_child(claim_btn)
	goal_panel.add_child(h)
	root.add_child(goal_panel)
	_top_h += 92.0

func _build_bottom(safe: Vector4) -> void:
	var bar := PanelContainer.new()
	var sb := UIKit.box(UIKit.C_PANEL, 44, UIKit.C_LINE, 3, 10).duplicate() as StyleBoxFlat
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 22.0 + safe.x
	bar.offset_right = -22.0 - safe.z
	bar.offset_bottom = -18.0 - safe.w
	bar.offset_top = -18.0 - safe.w - 150.0
	var h := UIKit.hbox(8)
	bar.add_child(h)
	var items := [
		[&"build", &"build", "nav.build", func() -> void: open_build()],
		[&"staff", &"people", "nav.staff", func() -> void: open_sheet(staff_sheet)],
		[&"hotel", &"hotel", "nav.hotel", func() -> void: open_sheet(hotel_sheet)],
		[&"reviews", &"review", "nav.reviews", func() -> void: open_sheet(reviews_sheet)],
		[&"dex", &"book", "nav.dex", func() -> void: open_sheet(dex_sheet)],
	]
	for it in items:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 126)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0)
		var pressed := UIKit.box(Color(1, 1, 1, 0.1), 30)
		for s in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, flat)
		b.add_theme_stylebox_override("pressed", pressed)
		var v := UIKit.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := IconView.make(it[1], 62, UIKit.C_TEXT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var lb := UIKit.label(Loc.t(it[2]), 26, UIKit.C_DIM, 600)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(lb)
		b.add_child(v)
		var cb: Callable = it[3]
		b.pressed.connect(cb)
		UIKit.juice(b)
		h.add_child(b)
		nav_btns[it[0]] = b
	root.add_child(bar)
	_bottom_h = 18.0 + safe.w + 150.0

func _build_misc(safe: Vector4) -> void:
	# lupa: alterna entre "ver a torre inteira" e o zoom normal (garante o zoom mesmo sem o gesto de pinça)
	zoom_btn = UIKit.button("", &"ghost", 28)
	zoom_btn.custom_minimum_size = Vector2(92, 92)
	zoom_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_btn.offset_left = 22.0 + safe.x
	zoom_btn.offset_right = 22.0 + safe.x + 92.0
	zoom_btn.offset_bottom = -_bottom_h - 18.0
	zoom_btn.offset_top = -_bottom_h - 18.0 - 92.0
	var zi := IconView.make(&"zoom", 54)
	zi.position = Vector2(19, 19)
	zoom_btn.add_child(zi)
	zoom_btn.pressed.connect(func() -> void: zoom_toggle_requested.emit())
	root.add_child(zoom_btn)
	collect_btn = UIKit.button(Loc.t("hud.collect_all"), &"good", 40)
	collect_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	collect_btn.offset_left = -190.0
	collect_btn.offset_right = 190.0
	collect_btn.offset_bottom = -_bottom_h - 18.0
	collect_btn.offset_top = -_bottom_h - 18.0 - 84.0
	collect_btn.visible = false
	collect_btn.pressed.connect(func() -> void: hotel.collect_all())
	root.add_child(collect_btn)
	rush_banner = _pill(Color("c0392b"))
	rush_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rush_banner.offset_top = _top_h + 8.0
	rush_banner.visible = false
	var rh := UIKit.hbox(10)
	rh.add_child(IconView.make(&"flame", 44))
	rush_label = UIKit.label("", 36, UIKit.C_TEXT, 700)
	rh.add_child(rush_label)
	rush_banner.add_child(rh)
	root.add_child(rush_banner)
	toast_box = UIKit.vbox(10)
	toast_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_box.offset_top = _top_h + 8.0
	toast_box.offset_left = 40.0
	toast_box.offset_right = -40.0
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

# --- ações ----------------------------------------------------------------------------

func _set_speed(i: int) -> void:
	match i:
		0:
			tower.paused = true
		1:
			tower.paused = false
			tower.speed = 1.0
		2:
			tower.paused = false
			tower.speed = 2.0
		3:
			tower.paused = false
			tower.speed = 4.0

func _on_rush() -> void:
	if hotel.rush_t > 0.0:
		return
	if not hotel.activate_rush():
		toast_info(Loc.t("toast.no_rush"))

func _on_claim() -> void:
	var from := claim_btn.global_position + claim_btn.size * 0.5
	var reward := hotel.claim_goal()
	if reward > 0.0:
		fly_coins(from, reward)

func _on_share(text: String) -> void:
	DisplayServer.clipboard_set(text)
	toast_info(Loc.t("toast.copied"), UIKit.C_MINT)

func open_sheet(s: Sheet) -> void:
	if active == s and s.is_open:
		s.close_sheet()
		return
	if active != null and active != s:
		active.close_sheet()
	active = s
	s.open_sheet(hotel)

func open_build() -> void:
	focus_plot_requested.emit()
	open_sheet(build_sheet)

func open_room(idx: int) -> void:
	if active != null and active != room_sheet:
		active.close_sheet()
	room_sheet.floor_idx = idx
	active = room_sheet
	tower.selected_floor = idx
	room_sheet.open_sheet(hotel)
	focus_floor_requested.emit(idx)

func sheet_height() -> float:
	return active.shown_height() if active != null else 0.0

func top_height() -> float:
	return _top_h

func bottom_height() -> float:
	return _bottom_h

func close_all() -> void:
	if active != null:
		active.close_sheet()

## Moedas voando de um ponto da tela até o contador de dinheiro.
func fly_coins(from: Vector2, amount: float) -> void:
	var target := money_icon.global_position + money_icon.size * 0.5
	var n := clampi(int(2.0 + log(maxf(1.0, amount)) / log(4.0)), 3, 9)
	for i in range(n):
		var c := FlyCoin.new()
		root.add_child(c)
		c.start(from, target, float(i) * 0.05)
		if i == n - 1:
			c.on_arrive = _pulse_money

func _pulse_money() -> void:
	money_icon.pivot_offset = money_icon.size * 0.5
	var tw := money_icon.create_tween()
	tw.tween_property(money_icon, "scale", Vector2(1.35, 1.35), 0.07)
	tw.tween_property(money_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

# --- avisos ----------------------------------------------------------------------------

func toast_info(text: String, color: Color = UIKit.C_TEXT) -> void:
	_toast(text, color, "")

func _toast(text: String, color: Color, icon: String) -> void:
	if _toast_count >= 3:
		return
	_toast_count += 1
	var p := _pill(Color("2b1857"))
	var hb := UIKit.hbox(12)
	if icon != "":
		hb.add_child(IconView.make(StringName(icon), 44, color))
	var l := UIKit.label(text, 30, color, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	hb.add_child(l)
	p.add_child(hb)
	p.modulate.a = 0.0
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_toast_done.bind(p))

func _toast_done(p: Control) -> void:
	_toast_count -= 1
	p.queue_free()

func _on_level_up(l: int) -> void:
	_toast(Loc.t("toast.level_up", [l]), UIKit.C_GOLD, "star")

func _on_species(sp: StringName) -> void:
	_toast(Loc.t("toast.species", [Loc.t("species." + str(sp))]), UIKit.C_MINT, "book")

func _on_review(rv: Dictionary) -> void:
	var stars := int(rv.get("stars", 3))
	if stars == 3 and randf() > 0.2:
		return
	if stars == 4 and randf() > 0.35:
		return
	var txt := Loc.review_text(rv)
	var who := Loc.guest_name(str(rv.get("species", "ghost")), int(rv.get("name_seed", 0)))
	var s := "%s  %s" % ["★".repeat(stars) + "☆".repeat(5 - stars), who]
	if txt != "":
		s += "\n" + txt
	_toast(s, UIKit.C_GOLD if stars >= 4 else (UIKit.C_BAD if stars <= 2 else UIKit.C_TEXT), "")

func _on_inspector_result(stars: int, bonus: float) -> void:
	if stars >= 4:
		_toast(Loc.t("toast.inspector_good", [Fmt.coins(bonus)]), UIKit.C_MINT, "check")
	elif stars <= 2:
		_toast(Loc.t("toast.inspector_bad"), UIKit.C_BAD, "close")

func _on_day_ended(rep: Dictionary) -> void:
	_toast(Loc.t("toast.day_end", [int(rep["day"]), Fmt.coins(float(rep["revenue"])), Fmt.coins(float(rep["wages"]))]), UIKit.C_TEXT, "moon")

# --- tutorial: setas ------------------------------------------------------------------------

func _tower_screen(local: Vector2) -> Vector2:
	return tower.get_global_transform_with_canvas() * local

func _center_of(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5

func _update_hint() -> void:
	var kind := ""
	if hotel.goal_done:
		kind = "claim"
	elif not hotel.goals_finished():
		kind = str(hotel.goal_current().get("hint", ""))
	var vs := get_viewport().get_visible_rect().size
	var p := Vector2.ZERO
	var ok := false
	var sheet_open := active != null and active.is_open
	match kind:
		"claim":
			ok = claim_btn.visible
			p = _center_of(claim_btn)
		"bubble":
			for f in range(hotel.floors.size()):
				if hotel.floors[f].pending > 0.05 and not sheet_open:
					p = _tower_screen(Vector2(Geo.FLOOR_W - 70.0, -float(f) * Geo.FLOOR_H - 170.0))
					ok = true
					break
		"plot":
			if tower.scenery.plot_visible and not sheet_open:
				p = _tower_screen(tower.scenery.plot_rect().get_center())
				ok = true
		"build", "staff", "hotel":
			if not sheet_open:
				p = _center_of(nav_btns[StringName(kind)])
				ok = true
		"room":
			if active == room_sheet and room_sheet.up_btn != null and room_sheet.up_btn.is_inside_tree() and room_sheet.up_btn.visible:
				p = _center_of(room_sheet.up_btn)
				ok = true
			elif not sheet_open and hotel.floors.size() > 1:
				p = _tower_screen(tower.floor_center(1))
				ok = true
		"rush":
			if not sheet_open and hotel.rush_charges > 0:
				p = _center_of(rush_btn)
				ok = true
	if ok:
		var lo := _top_h + 90.0
		var hi := vs.y - _bottom_h - 70.0
		var clamped := p.y < lo or p.y > hi
		hint.up = kind == "claim" or p.y < lo         # seta embaixo do alvo apontando para cima
		hint.ring = not clamped
		p.y = clampf(p.y, lo, hi)
		p.x = clampf(p.x, 80.0, vs.x - 80.0)
		hint.position = p
	hint.visible = ok

# --- atualização por quadro ------------------------------------------------------------------

func _process(delta: float) -> void:
	money_shown = lerpf(money_shown, hotel.money, 1.0 - exp(-delta * 9.0))
	if absf(money_shown - hotel.money) < 0.5:
		money_shown = hotel.money
	var mt := Fmt.coins(money_shown)
	if mt != _last_money_text:
		_last_money_text = mt
		money_label.text = mt
	rep_label.text = Fmt.stars(hotel.rep)
	var need := hotel.xp_needed(hotel.level)
	if badge.level != hotel.level or absf(badge.progress - hotel.xp / need) > 0.004:
		badge.level = hotel.level
		badge.progress = hotel.xp / need
		badge.queue_redraw()
	clock_label.text = Loc.t("hud.day", [hotel.day]) + "  " + Fmt.clock(hotel.hour())
	clock_icon.set_kind(&"moon" if hotel.is_night() else &"sun")
	for i in range(speed_btns.size()):
		var on := (i == 0 and tower.paused) or (i == 1 and not tower.paused and tower.speed == 1.0) \
			or (i == 2 and not tower.paused and tower.speed == 2.0) or (i == 3 and not tower.paused and tower.speed == 4.0)
		speed_btns[i].set_pressed_no_signal(on)
	rush_count.text = "x%d" % hotel.rush_charges
	rush_btn.modulate = Color(1, 1, 1, 1.0 if (hotel.rush_charges > 0 and hotel.rush_t <= 0.0) else 0.55)
	var n := 0
	for r: RoomState in hotel.floors:
		if r.pending > 0.05:
			n += 1
	collect_btn.visible = n >= 2 and (active == null)
	rush_banner.visible = hotel.rush_t > 0.0
	if rush_banner.visible:
		rush_label.text = Loc.t("hotel.rush_active", [int(hotel.rush_t)])
	_update_goal()
	_update_hint()

func _update_goal() -> void:
	if hotel.goals_finished():
		goal_label.text = Loc.t("hud.goals_all")
		goal_bar.value = goal_bar.max_value
		goal_reward.visible = false
		claim_btn.visible = false
		return
	var g := hotel.goal_current()
	var tgt := hotel.goal_target()
	var val := minf(hotel.goal_value(), tgt)
	var txt := Loc.t("goal." + str(g["id"]))
	if str(g["kind"]) == "rep":
		txt += " (%.1f/%.1f)" % [val, tgt]
	elif tgt > 1.0:
		txt += " (%d/%d)" % [int(val), int(tgt)]
	goal_label.text = txt
	goal_bar.max_value = tgt
	goal_bar.value = val
	var reward := hotel.goal_reward()
	claim_btn.visible = hotel.goal_done
	goal_reward.visible = not hotel.goal_done
	(goal_reward.get_child(1) as Label).text = Fmt.coins(reward)
	if hotel.goal_done:
		claim_btn.text = Loc.t("hud.goal_claim", [Fmt.coins(reward)])
