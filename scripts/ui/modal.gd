class_name Modal
extends Control
## Janela de diálogo com fundo escurecido. Emite `chosen(id)` com o id do botão tocado.

signal chosen(id: String)

var card: PanelContainer
var extra_ctrl: Control

## buttons: lista de [id, texto, tipo]. icon: nome de ícone opcional no topo.
static func open(host: Node, title_text: String, body_text: String, buttons: Array, extra: Control = null, icon: StringName = &"") -> Modal:
	var m := Modal.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)          # antes de entrar na árvore (senão o tamanho não fecha)
	m._build(title_text, body_text, buttons, extra, icon)
	host.add_child(m)
	return m

func _build(title_text: String, body_text: String, buttons: Array, extra: Control, icon: StringName) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	card = PanelContainer.new()
	var sb := UIKit.box(UIKit.C_PANEL, 44, UIKit.C_LINE, 4, 24).duplicate() as StyleBoxFlat
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 36
	sb.content_margin_bottom = 36
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(860, 0)
	center.add_child(card)
	var v := UIKit.vbox(18)
	card.add_child(v)
	if icon != &"":
		var ic := IconView.make(icon, 96, UIKit.C_GOLD)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
	var t := UIKit.label(title_text, 52, UIKit.C_TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 760
	v.add_child(t)
	if body_text != "":
		var b := UIKit.label(body_text, 32, UIKit.C_DIM, 500)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 760
		v.add_child(b)
	if extra != null:
		extra_ctrl = extra
		v.add_child(extra)
	var row := UIKit.hbox(16)
	for bd in buttons:
		var btn := UIKit.button(str(bd[1]), StringName(str(bd[2])), 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := str(bd[0])
		btn.pressed.connect(_pick.bind(id))
		row.add_child(btn)
	v.add_child(row)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	card.scale = Vector2(0.86, 0.86)
	modulate.a = 0.0
	tree_entered.connect(_animate_in)

func _animate_in() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pick(id: String) -> void:
	chosen.emit(id)
	queue_free()
