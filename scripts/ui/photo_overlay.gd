class_name PhotoOverlay
extends Control
## Modo Foto: esconde a interface e mostra um cartão com o nome e as estatísticas do hotel.

signal closed
signal save_requested

var _buttons: HBoxContainer
var _toast: Label

func setup(hotel_name: String, floors: int, rep: float, level: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	var sb := UIKit.box(Color(0.1, 0.05, 0.2, 0.86), 36, UIKit.C_LINE, 3, 14).duplicate() as StyleBoxFlat
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 30.0
	card.offset_right = -30.0
	card.offset_bottom = -40.0
	card.offset_top = -330.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var v := UIKit.vbox(8)
	card.add_child(v)
	var n := UIKit.label(hotel_name, 64, UIKit.C_GOLD, 700)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_constant_override("outline_size", 10)
	n.add_theme_color_override("font_outline_color", Color("2a1838"))
	v.add_child(n)
	var st := UIKit.label(Loc.t("photo.stats", [floors, Fmt.stars(rep), level]), 34, UIKit.C_TEXT, 600)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	_toast = UIKit.label("", 28, UIKit.C_MINT, 600)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_toast)
	_buttons = UIKit.hbox(16)
	var save := UIKit.button(Loc.t("photo.save"), &"primary", 36)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func() -> void: save_requested.emit())
	_buttons.add_child(save)
	var close := UIKit.button(Loc.t("photo.close"), &"ghost", 36)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: closed.emit())
	_buttons.add_child(close)
	v.add_child(_buttons)

func set_buttons_visible(v: bool) -> void:
	_buttons.visible = v

func flash(text: String) -> void:
	_toast.text = text
