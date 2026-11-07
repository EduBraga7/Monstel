class_name IconView
extends Control
## Ícones vetoriais desenhados por código (não dependem de fonte emoji nem de imagens).

var kind: StringName = &"coin"
var tint := Color("f7f2ff")

static func make(k: StringName, px: float = 56.0, c: Color = Color("f7f2ff")) -> IconView:
	var v := IconView.new()
	v.kind = k
	v.tint = c
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

func set_kind(k: StringName) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var u := s / 56.0
	match kind:
		&"coin":
			Art.coin(self, c, s * 0.44)
		&"star":
			Art.star(self, c, s * 0.46, tint)
		&"heart":
			Art.heart(self, c, s * 0.5, tint)
		&"plus":
			Art.rrect(self, Rect2(c.x - 4 * u, c.y - 18 * u, 8 * u, 36 * u), tint, 4 * u)
			Art.rrect(self, Rect2(c.x - 18 * u, c.y - 4 * u, 36 * u, 8 * u), tint, 4 * u)
		&"lock":
			Art.lock_icon(self, c, s * 0.9, tint)
		&"gear":
			for i in range(8):
				var a := TAU * float(i) / 8.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 19 * u, 5.5 * u, tint)
			draw_circle(c, 17 * u, tint)
			draw_circle(c, 7 * u, Color(0, 0, 0, 0.45))
		&"build":    # prédio com janelas
			Art.rrect(self, Rect2(c.x - 17 * u, c.y - 22 * u, 34 * u, 44 * u), tint, 5 * u)
			for iy in range(3):
				for ix in range(2):
					Art.rrect(self, Rect2(c.x - 11 * u + ix * 13 * u, c.y - 15 * u + iy * 13 * u, 8 * u, 8 * u), Color(0, 0, 0, 0.4), 2 * u)
		&"people":
			draw_circle(c + Vector2(-9 * u, -8 * u), 7 * u, tint)
			draw_circle(c + Vector2(10 * u, -6 * u), 6 * u, tint.darkened(0.12))
			Art.fill(self, Art.egg(c.x - 9 * u, c.y + 14 * u, 13 * u, 14 * u, 4 * u, 18), tint)
			Art.fill(self, Art.egg(c.x + 10 * u, c.y + 15 * u, 11 * u, 12 * u, 3 * u, 18), tint.darkened(0.12))
		&"hotel":    # elevador / porta dupla
			Art.rrect(self, Rect2(c.x - 18 * u, c.y - 22 * u, 36 * u, 44 * u), tint, 6 * u)
			Art.rrect(self, Rect2(c.x - 13 * u, c.y - 12 * u, 11 * u, 28 * u), Color(0, 0, 0, 0.4), 3 * u)
			Art.rrect(self, Rect2(c.x + 2 * u, c.y - 12 * u, 11 * u, 28 * u), Color(0, 0, 0, 0.4), 3 * u)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6 * u, -16 * u), c + Vector2(6 * u, -16 * u), c + Vector2(0, -21 * u)]), Color(0, 0, 0, 0.5))
		&"review":   # balão de fala com estrela
			Art.rrect(self, Rect2(c.x - 22 * u, c.y - 20 * u, 44 * u, 34 * u), tint, 10 * u)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8 * u, 12 * u), c + Vector2(-14 * u, 24 * u), c + Vector2(2 * u, 12 * u)]), tint)
			Art.star(self, c + Vector2(0, -3 * u), 10 * u, Color("ff9f43"))
		&"book":
			Art.rrect(self, Rect2(c.x - 20 * u, c.y - 22 * u, 40 * u, 44 * u), tint, 6 * u)
			Art.rrect(self, Rect2(c.x - 14 * u, c.y - 16 * u, 6 * u, 32 * u), Color(0, 0, 0, 0.35), 3 * u)
			draw_circle(c + Vector2(4 * u, -3 * u), 7 * u, Color(0, 0, 0, 0.4))
		&"flame":
			Art.fill(self, Art.egg(c.x, c.y + 4 * u, 14 * u, 24 * u, 14 * u, 20), Color("ff6b3d"))
			Art.fill(self, Art.egg(c.x, c.y + 9 * u, 8 * u, 13 * u, 8 * u, 16), Color("ffd166"))
		&"moon":
			draw_circle(c, 18 * u, tint)
			draw_circle(c + Vector2(8 * u, -5 * u), 15 * u, Color("2b1857"))
		&"sun":
			for i in range(8):
				var a := TAU * float(i) / 8.0
				Art.line(self, c + Vector2(cos(a), sin(a)) * 18 * u, c + Vector2(cos(a), sin(a)) * 25 * u, 4 * u, tint)
			draw_circle(c, 13 * u, tint)
		&"check":
			Art.line(self, c + Vector2(-14 * u, 1 * u), c + Vector2(-4 * u, 11 * u), 7 * u, tint)
			Art.line(self, c + Vector2(-4 * u, 11 * u), c + Vector2(15 * u, -10 * u), 7 * u, tint)
		&"close":
			Art.line(self, c + Vector2(-13 * u, -13 * u), c + Vector2(13 * u, 13 * u), 7 * u, tint)
			Art.line(self, c + Vector2(13 * u, -13 * u), c + Vector2(-13 * u, 13 * u), 7 * u, tint)
		&"up":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18 * u), c + Vector2(17 * u, 2 * u), c + Vector2(6 * u, 2 * u), c + Vector2(6 * u, 18 * u), c + Vector2(-6 * u, 18 * u), c + Vector2(-6 * u, 2 * u), c + Vector2(-17 * u, 2 * u)]), tint)
		&"pause":
			Art.rrect(self, Rect2(c.x - 14 * u, c.y - 16 * u, 10 * u, 32 * u), tint, 3 * u)
			Art.rrect(self, Rect2(c.x + 4 * u, c.y - 16 * u, 10 * u, 32 * u), tint, 3 * u)
		&"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11 * u, -17 * u), c + Vector2(17 * u, 0), c + Vector2(-11 * u, 17 * u)]), tint)
		&"fast":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-18 * u, -14 * u), c + Vector2(0, 0), c + Vector2(-18 * u, 14 * u)]), tint)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14 * u), c + Vector2(18 * u, 0), c + Vector2(0, 14 * u)]), tint)
		&"zoom":     # lupa
			draw_circle(c + Vector2(-4 * u, -4 * u), 17 * u, tint)
			draw_circle(c + Vector2(-4 * u, -4 * u), 11 * u, Color("2b1857"))
			Art.line(self, c + Vector2(8 * u, 8 * u), c + Vector2(20 * u, 20 * u), 7 * u, tint)
		&"bell":
			Art.fill(self, Art.egg(c.x, c.y - 2 * u, 16 * u, 18 * u, 6 * u, 20), tint)
			Art.rrect(self, Rect2(c.x - 20 * u, c.y + 8 * u, 40 * u, 7 * u), tint, 3 * u)
			draw_circle(c + Vector2(0, 20 * u), 5 * u, tint)
		_:
			draw_circle(c, s * 0.3, tint)
