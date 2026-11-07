class_name BuildSheet
extends Sheet
## Lista de andares que podem ser construídos no terreno vazio do topo.

signal built(floor_idx: int)

var rows: Dictionary = {}       # tipo -> {btn, price}

func build() -> void:
	title.text = Loc.t("sheet.build")
	rows.clear()
	for t in RoomDB.BUILDABLE:
		var c := Sheet.card()
		var h := UIKit.hbox(18)
		c.add_child(h)
		h.add_child(Sheet.swatch(t))
		var mid := UIKit.vbox(2)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(UIKit.label(Loc.t("room." + str(t)), 38, UIKit.C_TEXT, 700))
		var d := UIKit.label(Loc.t("room." + str(t) + ".desc"), 26, UIKit.C_DIM, 400)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(d)
		h.add_child(mid)
		var right := UIKit.vbox(6)
		right.custom_minimum_size.x = 250
		var price := Sheet.price_row(0.0, true)
		right.add_child(price)
		var btn := UIKit.button(Loc.t("btn.build"), &"primary", 34)
		right.add_child(btn)
		btn.pressed.connect(func() -> void: _on_build(t))
		h.add_child(right)
		body.add_child(c)
		rows[t] = {"btn": btn, "price": price}

func _on_build(t: StringName) -> void:
	if hotel.build(t):
		built.emit(hotel.floors.size() - 1)
		close_sheet()

func update() -> void:
	for t in rows:
		var r: Dictionary = rows[t]
		var btn: Button = r["btn"]
		var price: HBoxContainer = r["price"]
		var reason := hotel.block_reason_build(t)
		var cost := hotel.build_cost(t)
		var ok := hotel.money >= cost
		(price.get_child(0) as IconView).visible = reason != &"level"
		(price.get_child(1) as Label).text = Fmt.coins(cost) if reason != &"level" else Loc.t("reason.level", [RoomDB.unlock_level(t)])
		(price.get_child(1) as Label).add_theme_color_override("font_color", UIKit.C_GOLD if ok else UIKit.C_BAD)
		match reason:
			&"":
				btn.text = Loc.t("btn.build")
				btn.disabled = false
			&"money":
				btn.text = Loc.t("btn.build")
				btn.disabled = true
			&"level":
				btn.text = Loc.t("btn.locked")
				btn.disabled = true
			&"max_type":
				btn.text = Loc.t("reason.max_type")
				btn.disabled = true
			_:
				btn.text = Loc.t("reason." + str(reason))
				btn.disabled = true
