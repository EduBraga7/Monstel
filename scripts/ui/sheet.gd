class_name Sheet
extends PanelContainer
## Painel que sobe da base da tela. Subclasses preenchem `body` em build() e atualizam em update().

signal closed

var hotel: Hotel
var title: Label
var scroll: ScrollContainer
var body: VBoxContainer
var is_open := false
var height_frac := 0.56

var _h := 1000.0
var _tw: Tween
var _acc := 0.0

func _init() -> void:
	var sb := UIKit.sheet_box()
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 34
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var outer := UIKit.vbox(12)
	add_child(outer)
	var head := UIKit.hbox(12)
	title = UIKit.label("", 46, UIKit.C_TEXT, 700)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	var close := UIKit.button("X", &"ghost", 40)
	close.custom_minimum_size = Vector2(84, 72)
	close.pressed.connect(close_sheet)
	head.add_child(close)
	outer.add_child(head)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	body = UIKit.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

func open_sheet(h: Hotel) -> void:
	hotel = h
	_h = get_viewport_rect().size.y * height_frac
	for c in body.get_children():
		c.queue_free()
	build()
	update()
	visible = true
	is_open = true
	Sfx.play(&"open")
	offset_top = 0.0
	offset_bottom = _h
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "offset_top", -_h, 0.28)
	_tw.tween_property(self, "offset_bottom", 0.0, 0.28)

func close_sheet() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play(&"close")
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(self, "offset_top", 0.0, 0.2)
	_tw.tween_property(self, "offset_bottom", _h, 0.2)
	_tw.chain().tween_callback(func() -> void: visible = false)
	closed.emit()

func _process(delta: float) -> void:
	if not is_open:
		return
	_acc += delta
	if _acc >= 0.4:
		_acc = 0.0
		update()

## Altura em pixels que o painel ocupa (para a câmera enquadrar o andar acima dele).
func shown_height() -> float:
	return _h if is_open else 0.0

# --- a sobrescrever -------------------------------------------------------------

func build() -> void:
	pass

func update() -> void:
	pass

# --- peças de interface reutilizáveis ------------------------------------------------

static func card() -> PanelContainer:
	return UIKit.panel(UIKit.C_PANEL2, 26, 20)

static func price_row(amount: float, ok: bool) -> HBoxContainer:
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(IconView.make(&"coin", 40))
	h.add_child(UIKit.label(Fmt.coins(amount), 38, UIKit.C_GOLD if ok else UIKit.C_BAD, 700))
	return h

static func stars_row(level: int, max_level: int, px: float = 30.0) -> HBoxContainer:
	var h := UIKit.hbox(2)
	for s in range(max_level):
		h.add_child(IconView.make(&"star", px, Color("ffd166") if s < level else Color(1, 1, 1, 0.2)))
	return h

static func swatch(type: StringName, px: float = 92.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pal: Dictionary = FloorView.PALETTES.get(type, FloorView.PALETTES[&"suite"])
	c.draw.connect(Sheet._paint_swatch.bind(c, type, pal))
	return c

static func _paint_swatch(c: Control, type: StringName, pal: Dictionary) -> void:
	Art.rrect(c, Rect2(Vector2.ZERO, c.size), pal["top"], 22.0, pal["trim"], 4.0)
	var ctr := c.size * 0.5
	var tint: Color = pal["trim"]
	match type:
		&"suite":
			Art.rrect(c, Rect2(ctr.x - 26, ctr.y + 2, 52, 18), tint, 7.0)
			Art.rrect(c, Rect2(ctr.x - 28, ctr.y - 14, 12, 34), tint.darkened(0.2), 5.0)
		&"bar":
			Art.rrect(c, Rect2(ctr.x - 8, ctr.y - 24, 16, 34), tint, 6.0)
			Art.rrect(c, Rect2(ctr.x - 24, ctr.y + 10, 48, 8), tint, 4.0)
		&"buffet":
			c.draw_colored_polygon(Art.ellipse(ctr.x, ctr.y - 2, 24, 18, 18), tint)
			Art.rrect(c, Rect2(ctr.x - 30, ctr.y + 12, 60, 8), tint.darkened(0.25), 4.0)
		&"spa":
			Art.rrect(c, Rect2(ctr.x - 28, ctr.y - 2, 56, 22), tint, 11.0)
			for k in range(3):
				c.draw_circle(Vector2(ctr.x - 14 + k * 14, ctr.y - 14 - (k % 2) * 6), 5, Color(1, 1, 1, 0.7))
		&"boutique":
			c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x - 24, ctr.y + 14), Vector2(ctr.x + 24, ctr.y + 14), Vector2(ctr.x + 4, ctr.y - 28)]), tint)
			c.draw_colored_polygon(Art.ellipse(ctr.x, ctr.y + 14, 30, 7, 14), tint.darkened(0.3))
		&"gym":
			Art.rrect(c, Rect2(ctr.x - 28, ctr.y - 5, 56, 10), tint, 4.0)
			Art.rrect(c, Rect2(ctr.x - 32, ctr.y - 17, 14, 34), tint.darkened(0.25), 5.0)
			Art.rrect(c, Rect2(ctr.x + 18, ctr.y - 17, 14, 34), tint.darkened(0.25), 5.0)
		&"housekeeping":
			c.draw_circle(ctr, 22, tint)
			c.draw_circle(ctr, 14, pal["bot"])
		&"marketing":
			c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x - 26, ctr.y - 4), Vector2(ctr.x + 18, ctr.y - 24), Vector2(ctr.x + 18, ctr.y + 22), Vector2(ctr.x - 26, ctr.y + 8)]), tint)
		_:
			Art.star(c, ctr, 24.0, tint)

## Retrato da espécie (recorte do atlas). `dark` = silhueta de espécie ainda não descoberta.
static func avatar(species: StringName, px: float = 120.0, dark: bool = false) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px * 1.07)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if MonsterAtlas.baked:
		var at := AtlasTexture.new()
		at.atlas = MonsterAtlas.texture
		at.region = MonsterAtlas.cell(species, "n")
		tr.texture = at
		tr.material = MonsterAtlas.material
		if dark:
			tr.modulate = Color(0.12, 0.07, 0.22, 1.0)
	return tr

## Rótulo de motivo quando algo não pode ser feito.
static func reason_text(reason: StringName, extra: Array = []) -> String:
	return Loc.t("reason." + str(reason), extra)
