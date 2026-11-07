class_name WorldInput
extends Control
## Camada de entrada do mundo (fica sob a interface). Converte mouse/toque em: toque, arrastar, soltar e zoom.
## No Android o toque vira evento de mouse (emulate_mouse_from_touch), o pinch chega como MagnifyGesture.

signal tapped(pos: Vector2)
signal dragged(rel: Vector2)
signal released(velocity: Vector2)
signal zoomed(factor: float, at: Vector2)

const TAP_SLOP := 20.0

var _down := false
var _dragging := false
var _acc := Vector2.ZERO
var _press_ms := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down = true
				_dragging = false
				_acc = Vector2.ZERO
				_press_ms = Time.get_ticks_msec()
			elif _down:
				_down = false
				var dur := float(Time.get_ticks_msec() - _press_ms) / 1000.0
				if not _dragging and dur < 0.6:
					tapped.emit(mb.position)
				elif _dragging:
					released.emit(Vector2.ZERO)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoomed.emit(1.12, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoomed.emit(1.0 / 1.12, mb.position)
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if not _dragging:
			_acc += mm.relative
			if _acc.length() >= TAP_SLOP:
				_dragging = true
				dragged.emit(_acc)
		else:
			dragged.emit(mm.relative)
			_last_velocity = mm.velocity
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoomed.emit(mg.factor, mg.position)

var _last_velocity := Vector2.ZERO
