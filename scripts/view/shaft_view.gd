class_name ShaftView
extends Node2D
## Cabos e cabines dos elevadores (os poços em si são desenhados por cada FloorView).

var hotel: Hotel
var alpha := 0.0
var open_amt: Array[float] = []

func setup(h: Hotel) -> void:
	hotel = h

var view_rect := Rect2(-2000, -2000, 6000, 6000)
var _was_open: Array[bool] = []

func _process(delta: float) -> void:
	for i in range(hotel.elevators.size()):
		while open_amt.size() <= i:
			open_amt.append(0.0)
			_was_open.append(false)
		var e: Elevator = hotel.elevators[i]
		open_amt[i] = move_toward(open_amt[i], 1.0 if e.door_open else 0.0, delta * 3.2)
		if e.door_open and not _was_open[i] and view_rect.has_point(Vector2(Geo.shaft_x(i), -e.y * Geo.FLOOR_H)):
			Sfx.play(&"ding", 1.0 + float(i) * 0.12, -9.0)       # ding só das cabines visíveis
		_was_open[i] = e.door_open
	queue_redraw()

func _draw() -> void:
	var top_y := -float(hotel.floors.size()) * Geo.FLOOR_H
	for i in range(hotel.elevators.size()):
		var e: Elevator = hotel.elevators[i]
		var x := Geo.shaft_x(i)
		var y := lerpf(e.prev_y, e.y, alpha)
		var base := -y * Geo.FLOOR_H - 18.0
		draw_line(Vector2(x, top_y + 26), Vector2(x, base - 150), Color("9a94b8"), 4.0)
		var car := Rect2(x - 28, base - 148, 56, 146)
		Art.rrect(self, car.grow(4), Color("8d86a8"), 8.0)
		draw_polygon(PackedVector2Array([car.position, car.position + Vector2(car.size.x, 0), car.end, car.position + Vector2(0, car.size.y)]), PackedColorArray([Color("fff0b8"), Color("fff0b8"), Color("e8bd6a"), Color("e8bd6a")]))
		draw_rect(Rect2(car.position.x, car.end.y - 10, car.size.x, 10), Color(0.35, 0.22, 0.12, 0.7))
		# luz do teto
		draw_rect(Rect2(x - 14, car.position.y + 4, 28, 5), Color("ffffff"))
		# portas de vidro que deslizam
		var open := open_amt[i] if i < open_amt.size() else 0.0
		var pw := (car.size.x * 0.5) * (1.0 - open * 0.85)
		draw_rect(Rect2(car.position.x, car.position.y + 12, pw, car.size.y - 12), Color(0.75, 0.82, 1.0, 0.32))
		draw_rect(Rect2(car.end.x - pw, car.position.y + 12, pw, car.size.y - 12), Color(0.75, 0.82, 1.0, 0.32))
		draw_rect(Rect2(car.position.x + pw - 2, car.position.y + 12, 3, car.size.y - 12), Color(1, 1, 1, 0.5))
		# indicador de andar
		Art.rrect(self, Rect2(x - 15, car.position.y - 22, 30, 18), Color("1a1030"), 5.0)
		draw_string(UIKit.font(700), Vector2(x - 15, car.position.y - 8), str(roundi(y)), HORIZONTAL_ALIGNMENT_CENTER, 30, 14, Color("ffb86b"))
