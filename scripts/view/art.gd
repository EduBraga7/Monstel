class_name Art
extends RefCounted
## Utilidades de desenho procedural: formas arredondadas, gradientes e ícones simples.
## No Godot 4.7 as linhas do _draw não têm anti-aliasing: prefira polígonos e traços >= 4 px.

static var _sb_cache: Dictionary = {}

static func release() -> void:
	_sb_cache.clear()

# --- geometria ---------------------------------------------------------------

static func ellipse(cx: float, cy: float, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts

## Forma de ovo: metade de cima com raio vertical ry_top, metade de baixo com ry_bot.
static func egg(cx: float, cy: float, rx: float, ry_top: float, ry_bot: float, n: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var c := cos(a)
		var ry := ry_top if c >= 0.0 else ry_bot
		pts.append(Vector2(cx + sin(a) * rx, cy - c * ry))
	return pts

static func star_pts(c: Vector2, r_out: float, r_in: float, points: int = 5, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(points)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

static func heart_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(28):
		var t := TAU * float(i) / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * (s / 17.0))
	return pts

# --- preenchimento -------------------------------------------------------------

## Preenche o polígono com gradiente vertical (topo -> base).
static func fill_v(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	if pts.size() < 3:
		return
	var min_y := pts[0].y
	var max_y := pts[0].y
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	var span := maxf(0.001, max_y - min_y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - min_y) / span))
	ci.draw_polygon(pts, cols)

static func fill(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, color)

static func rrect(ci: CanvasItem, rect: Rect2, color: Color, radius: float = 16.0, border: Color = Color(0, 0, 0, 0), border_w: float = 0.0) -> void:
	var key := [color, radius, border, border_w]
	var sb: StyleBoxFlat = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		if border_w > 0.0:
			sb.border_color = border
			sb.set_border_width_all(int(border_w))
		_sb_cache[key] = sb
	ci.draw_style_box(sb, rect)

static func disc(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_circle(c, r, color)

## Anel (borda) desenhado como polígono grosso para não depender de linha antialiasada.
static func ring(ci: CanvasItem, c: Vector2, r: float, w: float, color: Color, n: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_polyline(pts, color, maxf(4.0, w), true)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, w: float, color: Color) -> void:
	ci.draw_line(a, b, color, maxf(3.0, w), true)

## Arco entre dois ângulos (radianos) como polilinha.
static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, w: float, color: Color, n: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_polyline(pts, color, maxf(3.0, w), true)

# --- ícones --------------------------------------------------------------------

static func coin(ci: CanvasItem, c: Vector2, r: float, spin: float = 1.0) -> void:
	var rx := r * clampf(absf(spin), 0.15, 1.0)
	ci.draw_colored_polygon(ellipse(c.x, c.y, rx, r, 20), Color("c98a1d"))
	ci.draw_colored_polygon(ellipse(c.x, c.y, rx * 0.88, r * 0.88, 20), Color("ffd166"))
	ci.draw_colored_polygon(ellipse(c.x - rx * 0.1, c.y - r * 0.1, rx * 0.56, r * 0.56, 16), Color("ffe49a"))
	if rx > r * 0.5:
		ci.draw_colored_polygon(star_pts(c, r * 0.4, r * 0.18, 5), Color("d99a2b"))

static func star(ci: CanvasItem, c: Vector2, r: float, color: Color = Color("ffd166")) -> void:
	ci.draw_colored_polygon(star_pts(c, r, r * 0.46), color.darkened(0.25))
	ci.draw_colored_polygon(star_pts(c, r * 0.86, r * 0.4), color)

static func heart(ci: CanvasItem, c: Vector2, s: float, color: Color = Color("ff6b8b")) -> void:
	ci.draw_colored_polygon(heart_pts(c, s), color)
	ci.draw_colored_polygon(ellipse(c.x - s * 0.3, c.y - s * 0.28, s * 0.14, s * 0.1, 10), Color(1, 1, 1, 0.55))

static func lock_icon(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	arc(ci, c + Vector2(0, -s * 0.15), s * 0.28, PI, TAU, s * 0.12, color)
	rrect(ci, Rect2(c.x - s * 0.36, c.y - s * 0.12, s * 0.72, s * 0.55), color, s * 0.1)
	ci.draw_circle(c + Vector2(0, s * 0.14), s * 0.07, color.darkened(0.55))
