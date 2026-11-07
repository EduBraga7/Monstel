class_name FxText
extends Node2D
## Texto que sobe e some (ganhos, avisos). Se autodestrói.

var text := ""
var color := Color.WHITE
var font_px := 40
var life := 1.2
var rise := 90.0
var t := 0.0

static func make(txt: String, col: Color = Color.WHITE, px: int = 40, seconds: float = 1.2) -> FxText:
	var f := FxText.new()
	f.text = txt
	f.color = col
	f.font_px = px
	f.life = seconds
	return f

func _process(delta: float) -> void:
	t += delta
	position.y -= rise * delta * (1.0 - t / life * 0.6)
	var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 7.0)
	scale = Vector2(pop, pop)
	modulate.a = 1.0 - smoothstep(life * 0.65, life, t)
	if t >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var f := UIKit.font(700)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	draw_string_outline(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, 9, Color("2a1838"))
	draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
