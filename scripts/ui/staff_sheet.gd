class_name StaffSheet
extends Sheet
## Contratar e treinar a equipe.

var rows: Dictionary = {}     # tipo -> {info, hire, train, hire_price, train_price}

func build() -> void:
	title.text = Loc.t("sheet.staff")
	rows.clear()
	var note := UIKit.label(Loc.t("staff.wages_note"), 26, UIKit.C_DIM, 400)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	for t in StaffDB.ORDER:
		var c := Sheet.card()
		var v := UIKit.vbox(8)
		c.add_child(v)
		var head := UIKit.hbox(12)
		var nm := UIKit.label(Loc.t("staff." + str(t)), 38, UIKit.C_TEXT, 700)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		var info := UIKit.label("", 28, UIKit.C_MINT, 700)
		head.add_child(info)
		v.add_child(head)
		var d := UIKit.label(Loc.t("staff." + str(t) + ".desc"), 26, UIKit.C_DIM, 400)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		var row := UIKit.hbox(14)
		var hire_box := UIKit.vbox(4)
		hire_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hp := Sheet.price_row(0.0, true)
		hire_box.add_child(hp)
		var hb := UIKit.button(Loc.t("btn.hire"), &"primary", 32)
		hb.pressed.connect(func() -> void:
			hotel.hire(t)
			update())
		hire_box.add_child(hb)
		row.add_child(hire_box)
		var train_box := UIKit.vbox(4)
		train_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tp := Sheet.price_row(0.0, true)
		train_box.add_child(tp)
		var tb := UIKit.button(Loc.t("btn.train"), &"good", 32)
		tb.pressed.connect(func() -> void:
			hotel.train(t)
			update())
		train_box.add_child(tb)
		row.add_child(train_box)
		v.add_child(row)
		body.add_child(c)
		rows[t] = {"info": info, "hire": hb, "train": tb, "hire_price": hp, "train_price": tp}

func update() -> void:
	for t in rows:
		var r: Dictionary = rows[t]
		var n := hotel.staff_count(t)
		var cap := hotel.staff_cap(t)
		(r["info"] as Label).text = Loc.t("staff.count", [n, cap, hotel.staff_level(t)])
		var hb: Button = r["hire"]
		var hr := hotel.block_reason_hire(t)
		var hcost := hotel.hire_cost(t)
		var hp: HBoxContainer = r["hire_price"]
		hp.visible = hcost >= 0.0 and hr != &"level" and hr != &"need_room"
		if hcost >= 0.0:
			(hp.get_child(1) as Label).text = Fmt.coins(hcost)
			(hp.get_child(1) as Label).add_theme_color_override("font_color", UIKit.C_GOLD if hotel.money >= hcost else UIKit.C_BAD)
		hb.disabled = hr != &""
		match hr:
			&"level":
				hb.text = Loc.t("reason.level", [StaffDB.unlock_level(t)])
			&"need_room":
				hb.text = Loc.t("reason.need_room")
			&"cap":
				hb.text = Loc.t("reason.cap")
			_:
				hb.text = Loc.t("btn.hire")
		var tb: Button = r["train"]
		var tr := hotel.block_reason_train(t)
		var tcost := hotel.train_cost(t)
		var tp: HBoxContainer = r["train_price"]
		tp.visible = tcost >= 0.0 and tr != &"nobody"
		if tcost >= 0.0:
			(tp.get_child(1) as Label).text = Fmt.coins(tcost)
			(tp.get_child(1) as Label).add_theme_color_override("font_color", UIKit.C_GOLD if hotel.money >= tcost else UIKit.C_BAD)
		tb.disabled = tr != &""
		match tr:
			&"max":
				tb.text = Loc.t("reason.max")
			&"nobody":
				tb.text = Loc.t("reason.nobody")
			_:
				tb.text = Loc.t("btn.train")
