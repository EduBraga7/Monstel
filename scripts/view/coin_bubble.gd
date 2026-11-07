class_name CoinBubble
extends Node2D
## Balão de moedas pendentes sobre um andar. Tocar nele coleta.

var floor_idx := 0
var amount := 0.0
var t := 0.0
var _label_w := 60.0
var _label := ""

func setup(f: int) -> void:
	floor_idx = f
	t = randf() * 6.0

func set_amount(a: float) -> void:
	if absf(a - amount) > 0.01:
		amount = a
		_label = Fmt.coins(a)
		_label_w = UIKit.font(700).get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(t * 3.0) * 5.0
	var c := Vector2(0, bob)
	var pulse := 1.0 + sin(t * 6.0) * 0.05
	draw_circle(c, 54.0 * pulse, Color(1.0, 0.9, 0.5, 0.16))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 34), c + Vector2(9, 34), c + Vector2(0, 52)]), Color("fff6d8"))
	draw_circle(c, 40.0, Color("fff6d8"))
	draw_circle(c, 40.0, Color("e8b445"), false, 5.0, true)
	Art.coin(self, c + Vector2(0, -1), 25.0, cos(t * 2.4))
	var w := _label_w + 30.0
	Art.rrect(self, Rect2(-w * 0.5, 56.0 + bob, w, 36), Color(0.16, 0.09, 0.22, 0.92), 18.0)
	draw_string(UIKit.font(700), Vector2(-_label_w * 0.5, 82.0 + bob), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffd166"))
