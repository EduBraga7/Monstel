class_name SettingsSheet
extends Sheet
## Configurações: som, música, vibração, idioma, nome do hotel, modo foto e voltar ao título.

signal photo_requested
signal menu_requested
signal reset_requested
signal name_changed

var _toggles: Dictionary = {}       # chave -> Button
var _lang_btns: Array[Button] = []
var _name_edit: LineEdit

func build() -> void:
	title.text = Loc.t("settings.title")
	_toggles.clear()
	_lang_btns.clear()
	var c1 := Sheet.card()
	var v1 := UIKit.vbox(10)
	c1.add_child(v1)
	for it in [["music", "settings.music"], ["sfx", "settings.sfx"], ["haptics", "settings.haptics"]]:
		var row := UIKit.hbox(12)
		var l := UIKit.label(Loc.t(it[1]), 34, UIKit.C_TEXT, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := UIKit.button("", &"segment", 30)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(190, 64)
		var key: String = it[0]
		b.pressed.connect(func() -> void:
			Save.set_setting(key, not bool(Save.settings.get(key, true)))
			update())
		row.add_child(b)
		v1.add_child(row)
		_toggles[key] = b
	body.add_child(c1)
	var c2 := Sheet.card()
	var v2 := UIKit.vbox(10)
	c2.add_child(v2)
	v2.add_child(UIKit.label(Loc.t("settings.language"), 34, UIKit.C_TEXT, 600))
	var lr := UIKit.hbox(12)
	for l2 in [["pt", "Português"], ["en", "English"]]:
		var lb := UIKit.button(l2[1], &"segment", 32)
		lb.toggle_mode = true
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var code: String = l2[0]
		lb.pressed.connect(func() -> void:
			Save.set_setting("lang", code)
			_rebuild())
		lr.add_child(lb)
		_lang_btns.append(lb)
	v2.add_child(lr)
	body.add_child(c2)
	var c3 := Sheet.card()
	var v3 := UIKit.vbox(10)
	c3.add_child(v3)
	v3.add_child(UIKit.label(Loc.t("settings.hotel_name"), 34, UIKit.C_TEXT, 600))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 18
	_name_edit.text = Save.hotel_name()
	_name_edit.add_theme_font_override("font", UIKit.font(600))
	_name_edit.add_theme_font_size_override("font_size", 36)
	_name_edit.add_theme_stylebox_override("normal", UIKit.box(Color("1b0f38"), 22, UIKit.C_LINE, 3))
	_name_edit.add_theme_stylebox_override("focus", UIKit.box(Color("1b0f38"), 22, UIKit.C_MINT, 3))
	_name_edit.custom_minimum_size = Vector2(0, 76)
	_name_edit.text_submitted.connect(_save_name)
	_name_edit.focus_exited.connect(func() -> void: _save_name(_name_edit.text))
	v3.add_child(_name_edit)
	body.add_child(c3)
	var photo := UIKit.button(Loc.t("settings.photo"), &"primary", 36)
	photo.pressed.connect(func() -> void:
		close_sheet()
		photo_requested.emit())
	body.add_child(photo)
	var menu := UIKit.button(Loc.t("settings.menu"), &"ghost", 34)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	body.add_child(menu)
	var reset := UIKit.button(Loc.t("settings.reset"), &"danger", 32)
	reset.pressed.connect(func() -> void: reset_requested.emit())
	body.add_child(reset)

func _rebuild() -> void:
	for c in body.get_children():
		c.queue_free()
	build()
	update()

func _save_name(txt: String) -> void:
	var t := txt.strip_edges()
	if t == "" or t == Save.hotel_name():
		return
	Save.set_setting("hotel_name", t)
	name_changed.emit()

func update() -> void:
	for key in _toggles:
		var b: Button = _toggles[key]
		var on := bool(Save.settings.get(key, true))
		b.text = Loc.t("settings.on") if on else Loc.t("settings.off")
		b.set_pressed_no_signal(on)
	var cur := Loc.lang
	for i in range(_lang_btns.size()):
		_lang_btns[i].set_pressed_no_signal((i == 0 and cur == "pt") or (i == 1 and cur == "en"))
