class_name HotelSheet
extends Sheet
## Gestão do hotel como um todo: elevadores, preços e o booster de Hora do Rush.

var elev_info: Label
var elev_btn: Button
var elev_price: HBoxContainer
var shaft_btn: Button
var shaft_price: HBoxContainer
var shaft_info: Label
var price_btns: Dictionary = {}     # "suite"/"fac" -> Array[Button]
var price_desc: Dictionary = {}
var rush_btn: Button
var rush_info: Label
var rep_label: Label

func build() -> void:
	title.text = Loc.t("sheet.hotel")
	# --- reputação
	var rc := Sheet.card()
	var rv := UIKit.vbox(4)
	rc.add_child(rv)
	rep_label = UIKit.label("", 40, UIKit.C_GOLD, 700)
	rv.add_child(rep_label)
	var rd := UIKit.label(Loc.t("hotel.rep_desc"), 26, UIKit.C_DIM, 400)
	rd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(rd)
	body.add_child(rc)
	# --- elevador
	var ec := Sheet.card()
	var ev := UIKit.vbox(8)
	ec.add_child(ev)
	ev.add_child(UIKit.label(Loc.t("hotel.elevator"), 40, UIKit.C_TEXT, 700))
	elev_info = UIKit.label("", 28, UIKit.C_DIM, 400)
	elev_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(elev_info)
	var er := UIKit.hbox(14)
	elev_price = Sheet.price_row(0.0, true)
	elev_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	er.add_child(elev_price)
	elev_btn = UIKit.button(Loc.t("btn.upgrade"), &"primary", 32)
	elev_btn.pressed.connect(func() -> void:
		hotel.upgrade_elevator())
	er.add_child(elev_btn)
	ev.add_child(er)
	shaft_info = UIKit.label("", 28, UIKit.C_DIM, 400)
	shaft_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(shaft_info)
	var sr := UIKit.hbox(14)
	shaft_price = Sheet.price_row(0.0, true)
	shaft_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(shaft_price)
	shaft_btn = UIKit.button(Loc.t("btn.build_shaft"), &"primary", 32)
	shaft_btn.pressed.connect(func() -> void:
		hotel.build_shaft())
	sr.add_child(shaft_btn)
	ev.add_child(sr)
	body.add_child(ec)
	# --- preços
	var pc := Sheet.card()
	var pv := UIKit.vbox(10)
	pc.add_child(pv)
	pv.add_child(UIKit.label(Loc.t("hotel.prices"), 40, UIKit.C_TEXT, 700))
	for kind in [&"suite", &"fac"]:
		pv.add_child(UIKit.label(Loc.t("hotel.price." + str(kind)), 30, UIKit.C_MINT, 700))
		var row := UIKit.hbox(10)
		var btns: Array[Button] = []
		for i in range(3):
			var b := UIKit.button(Loc.t("price." + str(i)), &"segment", 30)
			b.toggle_mode = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void:
				hotel.set_price(&"suite" if kind == &"suite" else &"fac", i)
				update())
			row.add_child(b)
			btns.append(b)
		price_btns[kind] = btns
		pv.add_child(row)
		var pd := UIKit.label("", 26, UIKit.C_DIM, 400)
		pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(pd)
		price_desc[kind] = pd
	body.add_child(pc)
	# --- hora do rush
	var uc := Sheet.card()
	var uv := UIKit.vbox(8)
	uc.add_child(uv)
	uv.add_child(UIKit.label(Loc.t("hotel.rush"), 40, UIKit.C_TEXT, 700))
	var ud := UIKit.label(Loc.t("hotel.rush_desc"), 26, UIKit.C_DIM, 400)
	ud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uv.add_child(ud)
	rush_info = UIKit.label("", 30, UIKit.C_GOLD, 700)
	uv.add_child(rush_info)
	rush_btn = UIKit.button(Loc.t("btn.rush"), &"good", 34)
	rush_btn.pressed.connect(func() -> void:
		hotel.activate_rush()
		update())
	uv.add_child(rush_btn)
	body.add_child(uc)

func update() -> void:
	rep_label.text = Loc.t("hotel.rep", [Fmt.stars(hotel.rep)])
	var lvl := hotel.elevator_level
	elev_info.text = Loc.t("hotel.elev_info", [lvl, RoomDB.elev("speed", lvl), int(RoomDB.elev("cap", lvl)), hotel.elevators.size()])
	var cost := hotel.elevator_upgrade_cost()
	elev_price.visible = cost >= 0.0
	elev_btn.visible = cost >= 0.0
	if cost >= 0.0:
		(elev_price.get_child(1) as Label).text = Fmt.coins(cost)
		(elev_price.get_child(1) as Label).add_theme_color_override("font_color", UIKit.C_GOLD if hotel.money >= cost else UIKit.C_BAD)
		elev_btn.disabled = hotel.money < cost
	var sc := hotel.shaft_cost()
	var reason := hotel.block_reason_shaft()
	shaft_info.text = Loc.t("hotel.shaft_info", [hotel.elevators.size(), int(RoomDB.SHAFTS["max"])])
	shaft_price.visible = sc >= 0.0 and reason != &"level"
	shaft_btn.visible = sc >= 0.0
	if sc >= 0.0:
		(shaft_price.get_child(1) as Label).text = Fmt.coins(sc)
		(shaft_price.get_child(1) as Label).add_theme_color_override("font_color", UIKit.C_GOLD if hotel.money >= sc else UIKit.C_BAD)
		shaft_btn.disabled = reason != &""
		shaft_btn.text = Loc.t("reason.level", [int((RoomDB.SHAFTS["unlock"] as Array)[hotel.elevators.size() - 1])]) if reason == &"level" else Loc.t("btn.build_shaft")
	for kind in price_btns:
		var cur := hotel.price_suite if kind == &"suite" else hotel.price_fac
		var btns: Array = price_btns[kind]
		for i in range(btns.size()):
			(btns[i] as Button).button_pressed = i == cur
		(price_desc[kind] as Label).text = Loc.t("hotel.price_desc." + str(kind) + "." + str(cur))
	rush_info.text = Loc.t("hotel.rush_charges", [hotel.rush_charges]) if hotel.rush_t <= 0.0 else Loc.t("hotel.rush_active", [int(hotel.rush_t)])
	rush_btn.disabled = hotel.rush_charges <= 0 or hotel.rush_t > 0.0
