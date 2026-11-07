class_name FlyCoin
extends Node2D
## Moeda que voa do balão coletado até o contador de dinheiro.

var target := Vector2.ZERO
var from := Vector2.ZERO
var t := -0.0
var delay := 0.0
var dur := 0.6
var on_arrive: Callable = Callable()
var _ctrl := Vector2.ZERO

func start(a: Vector2, b: Vector2, wait: float) -> void:
	from = a
	target = b
	delay = wait
	t = -wait
	position = a
	visible = false
	_ctrl = (a + b) * 0.5 + Vector2(randf_range(-160.0, 160.0), randf_range(-140.0, 20.0))

func _process(delta: float) -> void:
	t += delta
	if t < 0.0:
		return
	visible = true
	var u := clampf(t / dur, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	position = from.lerp(_ctrl, e).lerp(_ctrl.lerp(target, e), e)
	scale = Vector2.ONE * (1.0 - 0.35 * e)
	queue_redraw()
	if u >= 1.0:
		if on_arrive.is_valid():
			on_arrive.call()
		queue_free()

func _draw() -> void:
	Art.coin(self, Vector2.ZERO, 22.0, cos(t * 14.0))
