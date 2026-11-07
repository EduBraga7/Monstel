class_name UIKit
extends RefCounted
## Paleta, fontes e construtores de controles com tema único (roxo-noite, menta e abóbora).

const C_BG := Color("14082a")
const C_PANEL := Color("2b1857")
const C_PANEL2 := Color("3c2575")
const C_LINE := Color("5b3fa6")
const C_ACCENT := Color("ff9f43")
const C_MINT := Color("2fd8bd")
const C_PINK := Color("ff7eb6")
const C_TEXT := Color("f7f2ff")
const C_DIM := Color("b7a8e8")
const C_GOLD := Color("ffd166")
const C_GOOD := Color("7ee081")
const C_BAD := Color("ff6b8b")

static var _fonts: Dictionary = {}
static var _boxes: Dictionary = {}

## Solta os recursos em cache (chamado ao fechar o jogo para não sobrar "recursos em uso" no log).
static func release() -> void:
	_fonts.clear()
	_boxes.clear()

## Fonte Fredoka variável no peso pedido (300 a 700).
static func font(weight: int = 500) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka-Variable.ttf")
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: weight}
	_fonts[weight] = fv
	return fv

static func box(color: Color, radius: int = 28, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var key := [color, radius, border, border_w, shadow]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	_boxes[key] = sb
	return sb

static func sheet_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.corner_radius_top_left = 44
	sb.corner_radius_top_right = 44
	sb.border_color = C_LINE
	sb.border_width_top = 6
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	sb.anti_aliasing = true
	return sb

static func label(text: String, size: int = 36, color: Color = C_TEXT, weight: int = 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func kind_color(kind: StringName) -> Color:
	match kind:
		&"primary":
			return C_ACCENT
		&"good":
			return C_MINT
		&"danger":
			return C_BAD
		&"ghost":
			return C_PANEL2
	return C_PANEL2

static func _btn_box(base: Color, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(30)
	sb.anti_aliasing = true
	sb.border_color = base.darkened(0.35)
	sb.border_width_bottom = 3 if pressed else 8
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16 + (5 if pressed else 0)
	sb.content_margin_bottom = 16 - (5 if pressed else 0) + 5
	return sb

static func button(text: String, kind: StringName = &"primary", size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", size)
	var base := kind_color(kind)
	var txt := Color("2a1200") if kind == &"primary" or kind == &"good" else C_TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, txt)
	b.add_theme_color_override("font_disabled_color", Color("8b7fb5"))
	b.add_theme_stylebox_override("normal", _btn_box(base, false))
	b.add_theme_stylebox_override("hover", _btn_box(base.lightened(0.06), false))
	b.add_theme_stylebox_override("pressed", _btn_box(base.darkened(0.1), true))
	b.add_theme_stylebox_override("disabled", _btn_box(Color("3a3257"), false))
	if kind == &"segment":
		# seletor: o item ligado (pressed) vira menta com texto escuro
		var on := Color("2a1200")
		b.add_theme_stylebox_override("normal", _btn_box(C_PANEL2, false))
		b.add_theme_stylebox_override("hover", _btn_box(C_PANEL2.lightened(0.06), false))
		b.add_theme_stylebox_override("pressed", _btn_box(C_MINT, true))
		b.add_theme_stylebox_override("hover_pressed", _btn_box(C_MINT, true))
		b.add_theme_color_override("font_pressed_color", on)
		b.add_theme_color_override("font_hover_pressed_color", on)
		b.add_theme_color_override("font_color", C_TEXT)
		b.add_theme_color_override("font_hover_color", C_TEXT)
	juice(b)
	return b

## Efeito de "apertar": escala curta ao pressionar e volta elástica ao soltar.
static func juice(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	if c is BaseButton:
		var bb := c as BaseButton
		bb.pressed.connect(func() -> void:
			Sfx.play(&"click")
			Haptics.tap(10))
		bb.button_down.connect(func() -> void:
			var tw := bb.create_tween()
			tw.tween_property(bb, "scale", Vector2(0.94, 0.94), 0.06))
		bb.button_up.connect(func() -> void:
			var tw := bb.create_tween()
			tw.tween_property(bb, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

static func panel(color: Color = C_PANEL2, radius: int = 28, pad: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(color, radius).duplicate() as StyleBoxFlat
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p

static func hbox(sep: int = 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Margens de segurança (notch, barra de gestos) em unidades do viewport: x=esq, y=topo, z=dir, w=base.
static func safe_insets(node: Node) -> Vector4:
	var win := node.get_window()
	if win == null:
		return Vector4.ZERO
	var vp := node.get_viewport().get_visible_rect().size
	var sc := float(win.size.y) / maxf(1.0, vp.y)
	if sc <= 0.0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0 or OS.get_name() != "Android" and OS.get_name() != "iOS":
		return Vector4.ZERO
	var left := float(safe.position.x) / sc
	var top := float(safe.position.y) / sc
	var right := float(screen.x - safe.end.x) / sc
	var bottom := float(screen.y - safe.end.y) / sc
	return Vector4(maxf(0.0, left), maxf(0.0, top), maxf(0.0, right), maxf(0.0, bottom))
