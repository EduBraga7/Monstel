class_name RoomSheet
extends Sheet
## Detalhes de um andar: estatísticas atuais, próxima melhoria e coleta.

signal upgraded(floor_idx: int)

var floor_idx := 0
var stat_box: VBoxContainer
var up_box: VBoxContainer
var up_btn: Button
var up_price_label: Label
var collect_btn: Button
var _stars_holder: HBoxContainer

const KEYS := {
	&"suite": ["beds", "comfort", "rate"],
	&"facility": ["seats", "service", "fee"],
	&"housekeeping": ["maids"],
	&"marketing": ["arrival"],
}

func _fmt_stat(key: String, v: float) -> String:
	match key:
		"rate", "fee":
			return Fmt.coins(v)
		"service":
			return "%.1fs" % v
		"arrival":
			return "x%.2f" % v
	return str(int(v))

func build() -> void:
	var r: RoomState = hotel.floors[floor_idx]
	title.text = "%d · %s" % [floor_idx, Loc.t("room." + str(r.type))]
	var top := UIKit.hbox(14)
	top.add_child(Sheet.swatch(r.type, 84.0))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stars_holder = HBoxContainer.new()
	v.add_child(_stars_holder)
	var d := UIKit.label(Loc.t("room." + str(r.type) + ".desc"), 26, UIKit.C_DIM, 400)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	top.add_child(v)
	body.add_child(top)
	var sc := Sheet.card()
	stat_box = UIKit.vbox(6)
	sc.add_child(stat_box)
	body.add_child(sc)
	collect_btn = UIKit.button("", &"good", 34)
	collect_btn.pressed.connect(func() -> void:
		hotel.collect(floor_idx))
	body.add_child(collect_btn)
	if r.type != &"lobby":
		var uc := Sheet.card()
		up_box = UIKit.vbox(8)
		uc.add_child(up_box)
		body.add_child(uc)
		up_btn = UIKit.button(Loc.t("btn.upgrade"), &"primary", 36)
		up_btn.pressed.connect(func() -> void:
			if hotel.upgrade_room(floor_idx):
				upgraded.emit(floor_idx)
				build_rebuild())

func build_rebuild() -> void:
	for c in body.get_children():
		c.queue_free()
	build()
	update()

func _stat_line(label_text: String, value_text: String, next_text: String = "") -> HBoxContainer:
	var h := UIKit.hbox(10)
	var l := UIKit.label(label_text, 30, UIKit.C_DIM, 500)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UIKit.label(value_text, 32, UIKit.C_TEXT, 700))
	if next_text != "":
		h.add_child(UIKit.label("→", 30, UIKit.C_DIM, 500))
		h.add_child(UIKit.label(next_text, 32, UIKit.C_MINT, 700))
	return h

func update() -> void:
	if floor_idx >= hotel.floors.size():
		return
	var r: RoomState = hotel.floors[floor_idx]
	for c in _stars_holder.get_children():
		c.queue_free()
	if r.type != &"lobby":
		_stars_holder.add_child(Sheet.stars_row(r.level, RoomDB.max_level(r.type)))
	for c in stat_box.get_children():
		c.queue_free()
	var kind := RoomDB.kind(r.type)
	match kind:
		&"suite":
			var used := 0
			var dirty := 0
			for b: RoomState.Bed in r.beds:
				if b.occupant != null or b.reserved != null:
					used += 1
				if b.dirty:
					dirty += 1
			stat_box.add_child(_stat_line(Loc.t("stat.occupied"), "%d/%d" % [used, r.beds.size()]))
			if dirty > 0:
				stat_box.add_child(_stat_line(Loc.t("stat.dirty"), str(dirty)))
		&"facility":
			var using := 0
			for s: RoomState.Station in r.stations:
				if s.occupant != null:
					using += 1
			stat_box.add_child(_stat_line(Loc.t("stat.using"), "%d/%d" % [using, r.stations.size()]))
			stat_box.add_child(_stat_line(Loc.t("stat.queue"), str(r.queue.size())))
		&"lobby":
			stat_box.add_child(_stat_line(Loc.t("stat.desks"), str(hotel.desk_count())))
			stat_box.add_child(_stat_line(Loc.t("stat.queue"), str(hotel.reception_queue.size())))
	var keys: Array = KEYS.get(kind, [])
	for k in keys:
		var cur := RoomDB.at(r.type, k, r.level)
		var nxt := RoomDB.at(r.type, k, r.level + 1) if r.level < RoomDB.max_level(r.type) else cur
		var nx := _fmt_stat(k, nxt) if absf(nxt - cur) > 0.001 else ""
		stat_box.add_child(_stat_line(Loc.t("stat." + k), _fmt_stat(k, cur), nx))
	stat_box.add_child(_stat_line(Loc.t("stat.earned"), Fmt.coins(r.total_earned)))
	collect_btn.visible = r.pending > 0.05
	collect_btn.text = Loc.t("btn.collect", [Fmt.coins(r.pending)])
	# melhoria
	if up_box != null:
		for c in up_box.get_children():
			c.get_parent().remove_child(c)
			if c != up_btn:
				c.queue_free()
		var cost := hotel.upgrade_cost(floor_idx)
		if cost < 0.0:
			up_box.add_child(UIKit.label(Loc.t("reason.max"), 34, UIKit.C_MINT, 700))
		else:
			up_box.add_child(UIKit.label(Loc.t("sheet.next_level", [r.level + 1]), 32, UIKit.C_TEXT, 700))
			up_box.add_child(Sheet.price_row(cost, hotel.money >= cost))
			up_btn.disabled = hotel.money < cost
			up_box.add_child(up_btn)
