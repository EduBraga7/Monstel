class_name MonsterArt
extends RefCounted
## Desenho procedural dos monstrinhos (hóspedes e equipe). Origem = pés, olhando para a direita.
## Não guarda estado: tudo vem dos parâmetros, então a mesma função serve para hóspedes, galeria e fotos.

enum Mood { NEUTRAL, HAPPY, ANGRY, SLEEPY, SCARED }

const INK := Color("2a1838")
const WHITE := Color("fffdfa")

## Altura aproximada (px) de cada espécie, usada para posicionar balões de emoção.
static func height_of(species: StringName) -> float:
	match species:
		&"witch":
			return 122.0
		&"werewolf":
			return 90.0
		&"ghost":
			return 92.0
		&"bat":
			return 60.0
	return 84.0

## ci: alvo do desenho; t: tempo (s); walk: 0..1 intensidade da caminhada;
## mood: Mood; blink: 0..1 (olho fechado); look: direção do olhar (-1..1).
static func draw(ci: CanvasItem, species: StringName, t: float, walk: float, mood: int, blink: float, look: Vector2, flip: float = 1.0, base_pos: Vector2 = Vector2.ZERO, base_rot: float = 0.0, base_scale: Vector2 = Vector2.ONE, shadow: bool = true) -> void:
	var phase := t * 9.0
	var bob := absf(sin(phase)) * 5.0 * walk
	var tilt := sin(phase) * 0.07 * walk
	var shadow_w := 26.0
	if species == &"ghost":
		shadow_w = 20.0 + sin(t * 2.2) * 2.0
	if base_rot == 0.0 and shadow:
		ci.draw_set_transform(base_pos, 0.0, base_scale)
		ci.draw_colored_polygon(Art.ellipse(0, 0, shadow_w, shadow_w * 0.22, 20), Color(0, 0, 0, 0.26))
	ci.draw_set_transform(base_pos + Vector2(0, -bob * base_scale.y), tilt * flip + base_rot, Vector2(flip * base_scale.x, base_scale.y))
	match species:
		&"ghost":
			_ghost(ci, t, mood, blink, look, base_rot == 0.0)
		&"zombie":
			_zombie(ci, t, walk, mood, blink, look)
		&"vampire":
			_vampire(ci, t, walk, mood, blink, look)
		&"mummy":
			_mummy(ci, t, walk, mood, blink, look)
		&"witch":
			_witch(ci, t, walk, mood, blink, look)
		&"werewolf":
			_werewolf(ci, t, walk, mood, blink, look)
		&"bat":
			_bat(ci, t, mood, blink, look)
		_:
			_ghost(ci, t, mood, blink, look)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- partes do rosto --------------------------------------------------------------

static func _eyes(ci: CanvasItem, c: Vector2, spread: float, er: float, mood: int, blink: float, look: Vector2, iris: Color = INK, sclera: Color = WHITE) -> void:
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * spread, 0)
		if mood == Mood.HAPPY:
			Art.arc(ci, e + Vector2(0, er * 0.45), er * 0.95, PI * 1.12, PI * 1.88, 5.0, INK)
		elif mood == Mood.SLEEPY:
			Art.arc(ci, e + Vector2(0, -er * 0.2), er * 0.9, PI * 0.15, PI * 0.85, 5.0, INK)
		else:
			var rr := er * (1.18 if mood == Mood.SCARED else 1.0)
			var eh := rr * (1.0 - blink * 0.92)
			ci.draw_colored_polygon(Art.ellipse(e.x, e.y, rr, eh, 20), sclera)
			var pr := rr * (0.36 if mood == Mood.SCARED else 0.62)
			var po := Vector2(look.x * rr * 0.34, look.y * rr * 0.26)
			ci.draw_colored_polygon(Art.ellipse(e.x + po.x, e.y + po.y, pr, maxf(1.5, pr * (1.0 - blink * 0.85)), 16), iris)
			if blink < 0.5:
				ci.draw_circle(e + po + Vector2(-pr * 0.34, -pr * 0.34), pr * 0.3, WHITE)
		if mood == Mood.ANGRY:
			Art.line(ci, e + Vector2(side * er * 1.15, -er * 1.55), e + Vector2(-side * er * 0.75, -er * 0.95), 5.0, INK)

static func _mouth(ci: CanvasItem, c: Vector2, w: float, mood: int, t: float) -> void:
	match mood:
		Mood.HAPPY:
			var pts := PackedVector2Array()
			for i in range(13):
				var a := PI * float(i) / 12.0
				pts.append(c + Vector2(cos(a) * w, sin(a) * w * 0.95))
			ci.draw_colored_polygon(pts, Color("5a1d3a"))
			ci.draw_colored_polygon(Art.ellipse(c.x, c.y + w * 0.62, w * 0.55, w * 0.3, 12), Color("ff7a9c"))
		Mood.ANGRY:
			Art.arc(ci, c + Vector2(0, w * 0.85), w * 0.95, PI * 1.2, PI * 1.8, 5.0, INK)
		Mood.SLEEPY:
			ci.draw_colored_polygon(Art.ellipse(c.x, c.y + 3, w * 0.3, w * 0.24 + sin(t * 2.0) * 1.6, 12), INK)
		Mood.SCARED:
			var zz := PackedVector2Array()
			for i in range(7):
				zz.append(c + Vector2(-w * 0.8 + float(i) * w * 0.267, (3.0 if i % 2 == 0 else -3.0) + sin(t * 30.0) * 1.0))
			ci.draw_polyline(zz, INK, 4.5, true)
		_:
			Art.arc(ci, c + Vector2(0, -w * 0.15), w * 0.85, PI * 0.15, PI * 0.85, 5.0, INK)

static func _blush(ci: CanvasItem, c: Vector2, spread: float, r: float) -> void:
	ci.draw_colored_polygon(Art.ellipse(c.x - spread, c.y, r, r * 0.62, 12), Color(1.0, 0.45, 0.62, 0.5))
	ci.draw_colored_polygon(Art.ellipse(c.x + spread, c.y, r, r * 0.62, 12), Color(1.0, 0.45, 0.62, 0.5))

static func _shine(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	ci.draw_colored_polygon(Art.ellipse(c.x, c.y, rx, ry, 14), Color(1, 1, 1, 0.22))

static func _foot(ci: CanvasItem, x: float, lift: float, col: Color) -> void:
	ci.draw_colored_polygon(Art.ellipse(x, -3.0 - lift, 10.5, 6.5, 14), col)

# --- espécies ----------------------------------------------------------------------

static func _ghost(ci: CanvasItem, t: float, mood: int, blink: float, look: Vector2, glow: bool = true) -> void:
	var hv := -12.0 + sin(t * 2.2) * 4.0
	var w := 30.0
	var top := -80.0 + hv
	var bot := -12.0 + hv
	if glow:
		ci.draw_circle(Vector2(0, (top + bot) * 0.5), 46.0, Color(0.72, 0.86, 1.0, 0.07))
	var pts := PackedVector2Array()
	for i in range(17):
		var ang := PI + PI * float(i) / 16.0
		pts.append(Vector2(cos(ang) * w, top + w + sin(ang) * w * 1.1))
	pts.append(Vector2(w, bot - 4.0))
	var steps := 32
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		pts.append(Vector2(w - 2.0 * w * u, bot - 2.0 + absf(sin(u * PI * 4.0 + t * 2.0)) * 10.0))
	pts.append(Vector2(-w, bot - 4.0))
	for s in [-1.0, 1.0]:
		var wave := sin(t * 3.0 + (0.0 if s < 0.0 else 1.6)) * 4.0
		ci.draw_colored_polygon(Art.ellipse(s * (w + 1.0), -46.0 + hv + wave, 6.5, 11.0, 12), Color(0.9, 0.96, 1.0, 0.95))
	Art.fill_v(ci, pts, Color(0.98, 1.0, 1.0, 0.97), Color(0.7, 0.84, 0.97, 0.92))
	_shine(ci, Vector2(-10, top + 22), 9.0, 14.0)
	var fc := Vector2(0, top + 38.0)
	_eyes(ci, fc, 11.0, 7.6, mood, blink, look)
	_mouth(ci, fc + Vector2(0, 17), 7.0, mood, t)
	_blush(ci, fc + Vector2(0, 11), 20.0, 6.0)

static func _zombie(ci: CanvasItem, t: float, walk: float, mood: int, blink: float, look: Vector2) -> void:
	var skin_t := Color("b8ecaa")
	var skin_b := Color("76c984")
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(t * 9.0 + (0.0 if s < 0.0 else PI))) * 4.0 * walk
		Art.rrect(ci, Rect2(s * 12.0 - 8.0, -22.0 - lift, 16.0, 20.0), Color("3f4470"), 6.0)
		_foot(ci, s * 12.0, lift, Color("2c2f52"))
	# braços esticados à frente
	var reach := 8.0 + sin(t * 4.0) * 2.0
	Art.rrect(ci, Rect2(14.0, -52.0 + reach * 0.3, 30.0, 12.0), skin_b, 6.0)
	Art.rrect(ci, Rect2(-32.0, -50.0, 16.0, 26.0), skin_b, 7.0)
	Art.fill_v(ci, Art.egg(0, -42.0, 28.0, 34.0, 24.0, 32), skin_t, skin_b)
	# camisa rasgada
	var shirt := PackedVector2Array([Vector2(-26, -34), Vector2(26, -34), Vector2(24, -18)])
	for i in range(6):
		shirt.append(Vector2(24.0 - float(i) * 9.6, -18.0 + (7.0 if i % 2 == 0 else 0.0)))
	shirt.append(Vector2(-24, -18))
	Art.fill(ci, shirt, Color("5f78c4"))
	Art.line(ci, Vector2(-8, -34), Vector2(-6, -22), 3.0, Color("3d4f95"))
	_shine(ci, Vector2(-11, -64), 8.0, 11.0)
	var fc := Vector2(0, -56.0)
	_eyes(ci, fc + Vector2(-1, 0), 11.0, 7.2, mood, blink, look)
	if mood == Mood.NEUTRAL or mood == Mood.ANGRY:           # olho direito maior, meio desencontrado
		ci.draw_colored_polygon(Art.ellipse(fc.x + 10.0, fc.y, 9.8, 9.8 * (1.0 - blink * 0.9), 18), WHITE)
		ci.draw_circle(fc + Vector2(10.0 + look.x * 3.0, look.y * 2.5), 4.4, INK)
	# pontos da testa
	Art.line(ci, Vector2(-16, -76), Vector2(-6, -72), 3.0, Color("3f6e47"))
	Art.line(ci, Vector2(-14, -72), Vector2(-10, -77), 3.0, Color("3f6e47"))
	_mouth(ci, fc + Vector2(0, 17), 7.5, mood, t)
	_blush(ci, fc + Vector2(0, 11), 20.0, 5.5)

static func _vampire(ci: CanvasItem, t: float, walk: float, mood: int, blink: float, look: Vector2) -> void:
	var flap := sin(t * 4.0) * 2.0
	# capa
	var cape := PackedVector2Array([Vector2(-26, -62), Vector2(26, -62), Vector2(48 + flap, -6), Vector2(30, -12), Vector2(14, -4), Vector2(0, -12), Vector2(-14, -4), Vector2(-30, -12), Vector2(-48 - flap, -6)])
	Art.fill(ci, cape, Color("c43a63"))
	var cape_in := PackedVector2Array([Vector2(-22, -58), Vector2(22, -58), Vector2(42 + flap, -10), Vector2(28, -14), Vector2(14, -8), Vector2(0, -14), Vector2(-14, -8), Vector2(-28, -14), Vector2(-42 - flap, -10)])
	Art.fill_v(ci, cape_in, Color("3b2a6b"), Color("221640"))
	# gola alta
	Art.fill(ci, PackedVector2Array([Vector2(-30, -78), Vector2(-14, -62), Vector2(-26, -56)]), Color("221640"))
	Art.fill(ci, PackedVector2Array([Vector2(30, -78), Vector2(14, -62), Vector2(26, -56)]), Color("221640"))
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(t * 9.0 + (0.0 if s < 0.0 else PI))) * 4.0 * walk
		Art.rrect(ci, Rect2(s * 10.0 - 6.0, -20.0 - lift, 12.0, 18.0), Color("221640"), 5.0)
		_foot(ci, s * 10.0, lift, Color("120a26"))
	Art.fill_v(ci, Art.egg(0, -44.0, 24.0, 32.0, 24.0, 32), Color("f2eaff"), Color("cfc0f4"))
	# cabelo com bico de viúva
	var hair := Art.ellipse(0, -66.0, 25.0, 13.0, 22)
	Art.fill(ci, hair, Color("1b1230"))
	Art.fill(ci, PackedVector2Array([Vector2(-10, -64), Vector2(0, -52), Vector2(10, -64)]), Color("1b1230"))
	# gravata borboleta
	Art.fill(ci, PackedVector2Array([Vector2(0, -28), Vector2(-11, -34), Vector2(-11, -22)]), Color("e03a5e"))
	Art.fill(ci, PackedVector2Array([Vector2(0, -28), Vector2(11, -34), Vector2(11, -22)]), Color("e03a5e"))
	ci.draw_circle(Vector2(0, -28), 3.5, Color("ff7a96"))
	var fc := Vector2(0, -50.0)
	_eyes(ci, fc, 10.5, 6.8, mood, blink, look, Color("a3162f"))
	_mouth(ci, fc + Vector2(0, 14), 7.0, mood, t)
	# presas
	Art.fill(ci, PackedVector2Array([Vector2(-5, fc.y + 13), Vector2(-1.5, fc.y + 13), Vector2(-3.2, fc.y + 21)]), WHITE)
	Art.fill(ci, PackedVector2Array([Vector2(5, fc.y + 13), Vector2(1.5, fc.y + 13), Vector2(3.2, fc.y + 21)]), WHITE)
	_blush(ci, fc + Vector2(0, 8), 18.0, 5.0)

static func _mummy(ci: CanvasItem, t: float, walk: float, mood: int, blink: float, look: Vector2) -> void:
	var tail_w := sin(t * 5.0) * 4.0
	var tail := PackedVector2Array([Vector2(-22, -24), Vector2(-34, -20 + tail_w), Vector2(-46, -10 - tail_w), Vector2(-58, -12 + tail_w)])
	ci.draw_polyline(tail, Color("d9c48c"), 6.0, true)
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(t * 9.0 + (0.0 if s < 0.0 else PI))) * 3.0 * walk
		Art.rrect(ci, Rect2(s * 11.0 - 7.0, -20.0 - lift, 14.0, 18.0), Color("e4d3a0"), 6.0)
		_foot(ci, s * 11.0, lift, Color("cdb97f"))
	var cy := -42.0
	var rx := 27.0
	var ry_t := 34.0
	var ry_b := 24.0
	Art.fill_v(ci, Art.egg(0, cy, rx, ry_t, ry_b, 32), Color("f8efce"), Color("dccb95"))
	# faixas: larguras seguem o contorno do ovo
	var ys := [-70.0, -62.0, -34.0, -26.0, -19.0]
	for yb in ys:
		var dy: float = yb - cy
		var ry: float = ry_t if dy < 0.0 else ry_b
		var half: float = rx * sqrt(maxf(0.0, 1.0 - (dy / ry) * (dy / ry)))
		Art.fill(ci, PackedVector2Array([Vector2(-half, yb - 3), Vector2(half, yb - 6), Vector2(half, yb + 1), Vector2(-half, yb + 4)]), Color("c9b57d"))
	_shine(ci, Vector2(-11, -64), 8.0, 11.0)
	# faixa que cobre um dos olhos
	Art.fill(ci, PackedVector2Array([Vector2(-24, -61), Vector2(0, -64), Vector2(0, -50), Vector2(-24, -47)]), Color("efe0b0"))
	Art.line(ci, Vector2(-24, -61), Vector2(0, -64), 3.0, Color("c9b57d"))
	var fc := Vector2(0, -56.0)
	_eyes(ci, fc + Vector2(6, 0), 5.5, 7.0, mood, blink, look)
	_mouth(ci, fc + Vector2(0, 18), 6.5, mood, t)
	_blush(ci, fc + Vector2(0, 12), 19.0, 5.0)

static func _witch(ci: CanvasItem, t: float, walk: float, mood: int, blink: float, look: Vector2) -> void:
	var sway := sin(t * 3.0) * 1.5
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(t * 9.0 + (0.0 if s < 0.0 else PI))) * 4.0 * walk
		_foot(ci, s * 9.0, lift, Color("2a1838"))
	Art.fill_v(ci, PackedVector2Array([Vector2(-28, -6), Vector2(28, -6), Vector2(14, -50), Vector2(-14, -50)]), Color("9a6be6"), Color("5a36a8"))
	Art.line(ci, Vector2(-26, -8), Vector2(26, -8), 5.0, Color("ffb86b"))
	for i in range(4):
		ci.draw_circle(Vector2(-14.0 + float(i) * 9.0, -24.0 + float(i % 2) * 8.0), 2.6, Color("ffd166"))
	# cabelo
	Art.fill_v(ci, Art.ellipse(0, -52.0, 25.0, 22.0, 24), Color("2e1a4a"), Color("1b1030"))
	Art.fill_v(ci, Art.ellipse(0, -55.0, 21.0, 20.0, 26), Color("cdf3b0"), Color("98d98c"))
	_shine(ci, Vector2(-9, -62), 6.0, 8.0)
	# chapéu
	Art.fill(ci, Art.ellipse(0, -72.0, 33.0, 8.5, 24), Color("34205c"))
	var cone := PackedVector2Array([Vector2(-20, -74), Vector2(20, -74), Vector2(9 + sway, -104), Vector2(4 + sway * 2.0, -122), Vector2(-4, -108)])
	Art.fill_v(ci, cone, Color("5a36a8"), Color("34205c"))
	Art.fill(ci, PackedVector2Array([Vector2(-19.5, -75), Vector2(19.5, -75), Vector2(18, -83), Vector2(-18, -83)]), Color("ff9f43"))
	Art.rrect(ci, Rect2(-5, -85, 10, 13), Color("ffd166"), 3.0)
	var fc := Vector2(0, -55.0)
	_eyes(ci, fc, 10.0, 6.6, mood, blink, look, Color("2a1838"))
	ci.draw_colored_polygon(Art.ellipse(0, fc.y + 7.0, 3.6, 3.0, 10), Color("7ec86f"))
	_mouth(ci, fc + Vector2(0, 15), 6.5, mood, t)
	_blush(ci, fc + Vector2(0, 9), 17.0, 5.0)

static func _werewolf(ci: CanvasItem, t: float, walk: float, mood: int, blink: float, look: Vector2) -> void:
	var wag := sin(t * 7.0) * 6.0
	var tail := PackedVector2Array([Vector2(-24, -18), Vector2(-40, -26 + wag), Vector2(-50, -44 + wag), Vector2(-46, -58 + wag * 0.5)])
	ci.draw_polyline(tail, Color("8a5a3a"), 11.0, true)
	for s in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(t * 9.0 + (0.0 if s < 0.0 else PI))) * 4.0 * walk
		Art.rrect(ci, Rect2(s * 13.0 - 8.0, -20.0 - lift, 16.0, 18.0), Color("8a5a3a"), 6.0)
		_foot(ci, s * 13.0, lift, Color("6a4129"))
		for k in range(3):
			ci.draw_colored_polygon(PackedVector2Array([Vector2(s * 13.0 - 6.0 + k * 6.0, -4 - lift), Vector2(s * 13.0 - 4.0 + k * 6.0, -4 - lift), Vector2(s * 13.0 - 5.0 + k * 6.0, 0 - lift)]), WHITE)
	# orelhas
	for s in [-1.0, 1.0]:
		Art.fill(ci, PackedVector2Array([Vector2(s * 10.0, -76), Vector2(s * 20.0, -96), Vector2(s * 30.0, -68)]), Color("8a5a3a"))
		Art.fill(ci, PackedVector2Array([Vector2(s * 14.0, -76), Vector2(s * 20.0, -90), Vector2(s * 25.0, -72)]), Color("f0a3a8"))
	Art.fill_v(ci, Art.egg(0, -44.0, 32.0, 34.0, 26.0, 34), Color("b98457"), Color("86563a"))
	# tufos nas laterais
	for s in [-1.0, 1.0]:
		for k in range(3):
			var y := -52.0 + float(k) * 12.0
			Art.fill(ci, PackedVector2Array([Vector2(s * 30.0, y), Vector2(s * 40.0, y + 4), Vector2(s * 29.0, y + 9)]), Color("a06f48"))
	ci.draw_colored_polygon(Art.ellipse(0, -28.0, 18.0, 17.0, 20), Color("e8c8a0"))
	_shine(ci, Vector2(-14, -64), 9.0, 11.0)
	var fc := Vector2(0, -58.0)
	_eyes(ci, fc, 12.0, 7.0, mood, blink, look, Color("1b1230"), Color("ffe980"))
	# focinho
	ci.draw_colored_polygon(Art.ellipse(0, fc.y + 14.0, 15.0, 10.5, 18), Color("ead0ac"))
	ci.draw_colored_polygon(Art.ellipse(0, fc.y + 8.5, 5.5, 4.0, 12), INK)
	_mouth(ci, fc + Vector2(0, 19), 6.5, mood, t)
	Art.fill(ci, PackedVector2Array([Vector2(-6, fc.y + 21), Vector2(-3, fc.y + 21), Vector2(-4.5, fc.y + 27)]), WHITE)
	Art.fill(ci, PackedVector2Array([Vector2(6, fc.y + 21), Vector2(3, fc.y + 21), Vector2(4.5, fc.y + 27)]), WHITE)
	_blush(ci, fc + Vector2(0, 11), 22.0, 5.5)

## Morcego (camareira): voa, então não tem pés; usa a mesma escala dos outros.
static func _bat(ci: CanvasItem, t: float, mood: int, blink: float, look: Vector2) -> void:
	var flap := sin(t * 14.0)
	var hv := -34.0 + sin(t * 3.0) * 3.0
	for s in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(s * 12.0, hv - 6), Vector2(s * 34.0, hv - 20 - flap * 10.0), Vector2(s * 46.0, hv - 4 - flap * 14.0), Vector2(s * 38.0, hv + 4 - flap * 8.0), Vector2(s * 28.0, hv + 2 - flap * 6.0), Vector2(s * 20.0, hv + 8)])
		Art.fill(ci, wing, Color("5a4a86"))
	Art.fill_v(ci, Art.egg(0, hv, 17.0, 20.0, 18.0, 24), Color("7a66b0"), Color("4c3d78"))
	for s in [-1.0, 1.0]:
		Art.fill(ci, PackedVector2Array([Vector2(s * 7.0, hv - 15), Vector2(s * 12.0, hv - 30), Vector2(s * 16.0, hv - 12)]), Color("5a4a86"))
	var fc := Vector2(0, hv - 3.0)
	_eyes(ci, fc, 7.5, 5.6, mood, blink, look)
	_mouth(ci, fc + Vector2(0, 11), 5.0, mood, t)

# --- balões e acessórios ---------------------------------------------------------------

## Balão de emoção sobre a cabeça. kind: heart, angry, zzz, star, nobed, bang, coin.
static func draw_emote(ci: CanvasItem, kind: StringName, t: float, at: Vector2) -> void:
	if kind == &"":
		return
	var pop := 1.0 + sin(t * 8.0) * 0.04
	var r := 19.0 * pop
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-5, r - 4), at + Vector2(5, r - 4), at + Vector2(0, r + 8)]), Color(1, 1, 1, 0.96))
	ci.draw_circle(at, r, Color(1, 1, 1, 0.96))
	match kind:
		&"heart":
			Art.heart(ci, at + Vector2(0, 1), 12.0)
		&"angry":
			var c := Color("ff4d6d")
			Art.line(ci, at + Vector2(-8, -3), at + Vector2(-2, -3), 4.0, c)
			Art.line(ci, at + Vector2(-5, -8), at + Vector2(-5, 2), 4.0, c)
			Art.line(ci, at + Vector2(2, 1), at + Vector2(8, 1), 4.0, c)
			Art.line(ci, at + Vector2(5, -4), at + Vector2(5, 6), 4.0, c)
		&"zzz":
			ci.draw_string(UIKit.font(700), at + Vector2(-9, 9), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("6a5acd"))
		&"star":
			Art.star(ci, at, 12.0)
		&"nobed":
			ci.draw_circle(at, 12.0, Color("ff4d6d"))
			Art.rrect(ci, Rect2(at.x - 8, at.y - 2.5, 16, 5), WHITE, 2.0)
		&"bang":
			ci.draw_string(UIKit.font(700), at + Vector2(-5, 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ff4d6d"))
		&"coin":
			Art.coin(ci, at, 12.0)

## Chapéu e óculos do inspetor secreto (por cima do monstro).
static func draw_detective(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_colored_polygon(Art.ellipse(at.x, at.y + 4.0, 30.0, 7.0, 18), Color("3a3a50"))
	Art.rrect(ci, Rect2(at.x - 18.0, at.y - 18.0, 36.0, 24.0), Color("4a4a66"), 8.0)
	Art.rrect(ci, Rect2(at.x - 18.0, at.y - 4.0, 36.0, 7.0), Color("e8435f"), 2.0)
	ci.draw_circle(at + Vector2(-10.0, 30.0), 9.0, Color(0, 0, 0, 0.0))
	ci.draw_arc(at + Vector2(-10.0, 32.0), 11.0, 0.0, TAU, 16, Color("1b1230"), 3.5, true)
	ci.draw_arc(at + Vector2(10.0, 32.0), 11.0, 0.0, TAU, 16, Color("1b1230"), 3.5, true)
	ci.draw_line(at + Vector2(-1.0, 32.0), at + Vector2(1.0, 32.0), Color("1b1230"), 3.5)

static func draw_crown(ci: CanvasItem, at: Vector2) -> void:
	var pts := PackedVector2Array([at + Vector2(-14, 8), at + Vector2(-16, -8), at + Vector2(-7, 0), at + Vector2(0, -12), at + Vector2(7, 0), at + Vector2(16, -8), at + Vector2(14, 8)])
	Art.fill(ci, pts, Color("ffd166"))
	Art.line(ci, at + Vector2(-14, 8), at + Vector2(14, 8), 4.0, Color("d9a02b"))
	ci.draw_circle(at + Vector2(0, -2), 2.6, Color("ff4d6d"))
