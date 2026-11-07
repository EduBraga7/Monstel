class_name FloorView
extends Node2D
## Um andar do hotel em corte. O fundo estático é desenhado uma vez (refresh() redesenha);
## a camada Dyn (filho) cuida do que muda a toda hora: camas sujas, velas, vapor.
## Coordenadas locais: x 0..1000, y 0..240 (topo do andar em y=0; chão em y=222).

const W := Geo.FLOOR_W
const H := Geo.FLOOR_H
const FLOOR_Y := 222.0

const PALETTES := {
	&"lobby": {"top": Color("5e3b54"), "bot": Color("3a2337"), "trim": Color("ffb86b")},
	&"suite": {"top": Color("4b3b8e"), "bot": Color("2e2465"), "trim": Color("c9a8ff")},
	&"bar": {"top": Color("72244a"), "bot": Color("441530"), "trim": Color("ff6b8b")},
	&"buffet": {"top": Color("2f6b56"), "bot": Color("1b4636"), "trim": Color("8ef0b8")},
	&"spa": {"top": Color("2b6c88"), "bot": Color("1a4259"), "trim": Color("7be8ff")},
	&"boutique": {"top": Color("8c3c88"), "bot": Color("561f56"), "trim": Color("ff9ee0")},
	&"gym": {"top": Color("88532d"), "bot": Color("54301a"), "trim": Color("ffb36b")},
	&"housekeeping": {"top": Color("4b5d88"), "bot": Color("2c3957"), "trim": Color("a9c6ff")},
	&"marketing": {"top": Color("7b6b2d"), "bot": Color("4d4118"), "trim": Color("ffe27a")},
}
const MATTRESS := [Color("8a78e8"), Color("4fa8e0"), Color("e8566f"), Color("33d3b8"), Color("ffcf4a")]

class Dyn extends Node2D:
	var fv: FloorView
	func _draw() -> void:
		if fv != null:
			fv.draw_dyn(self)

var hotel: Hotel
var idx := 0
var type: StringName = &"suite"
var level := 1
var shafts := 1
var title := ""
var selected := false
var dyn: Dyn
var dyn_t := 0.0
var painter_mode := false          # true: instância só para pintar o fundo dentro de um SubViewport (ver Baker)
var desks := 0                     # balcões da recepção (parte da arte do saguão)
var _baked: Texture2D = null       # fundo já pintado, dividido entre andares iguais; null = desenha ao vivo

const BAKE_SCALE := 1.25           # texels por unidade (zoom máximo é 1.3: fica nítido)

func setup(h: Hotel, i: int) -> void:
	hotel = h
	idx = i
	dyn = Dyn.new()
	dyn.fv = self
	dyn.z_index = 1
	add_child(dyn)
	refresh()

func refresh() -> void:
	var r: RoomState = hotel.floors[idx]
	type = r.type
	level = r.level
	shafts = hotel.elevators.size()
	desks = hotel.desk_count() if type == &"lobby" else 0
	title = Loc.t("room." + str(type))
	_baked = null                                   # enquanto a imagem nova não chega, desenha ao vivo
	var key := _bake_key()
	if Baker.cache.has(key):
		_baked = Baker.cache[key]
	else:
		Baker.request(key, Vector2(W, H), BAKE_SCALE, _make_painter.bind(type, level, shafts, desks), _on_baked.bind(key))
	queue_redraw()
	dyn.queue_redraw()

func _bake_key() -> String:
	return "floor|%s|%d|%d|%d" % [type, level, shafts, desks]

static func _make_painter(t: StringName, lv: int, sh: int, dk: int) -> FloorView:
	var p := FloorView.new()
	p.painter_mode = true
	p.type = t
	p.level = lv
	p.shafts = sh
	p.desks = dk
	return p

func _on_baked(tex: Texture2D, key: String) -> void:
	if key == _bake_key():
		_baked = tex
		queue_redraw()

func _pal() -> Dictionary:
	return PALETTES.get(type, PALETTES[&"suite"])

# --- casca comum --------------------------------------------------------------------

func _draw() -> void:
	if painter_mode:
		_paint()
		return
	if _baked != null:
		draw_texture_rect(_baked, Rect2(0, 0, W, H), false)
	else:
		_paint()
	_torches()
	_plate()

## Tochas na parede externa, a cada 2 andares (ao vivo: somem junto com o andar fora da tela).
func _torches() -> void:
	if idx < 2 or idx % 2 != 0:
		return
	var wy := 120.0
	var wl := Scenery.WALL
	Art.rrect(self, Rect2(-wl + 8, wy, 14, 22), Color("6a5f8a"), 4.0)
	draw_colored_polygon(Art.egg(-wl + 15, wy - 6, 6, 12, 4, 10), Color("ffb347"))
	Art.rrect(self, Rect2(W + 8, wy, 14, 22), Color("6a5f8a"), 4.0)
	draw_colored_polygon(Art.egg(W + 15, wy - 6, 6, 12, 4, 10), Color("ffb347"))

## Fundo estático do andar (tudo menos a placa e as tochas).
func _paint() -> void:
	var p := _pal()
	var top: Color = p["top"]
	var bot: Color = p["bot"]
	var trim: Color = p["trim"]
	# parede de fundo
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, FLOOR_Y), Vector2(0, FLOOR_Y)]), PackedColorArray([top, top, bot, bot]))
	for x in range(300, 1000, 76):
		draw_rect(Rect2(x, 20, 30, FLOOR_Y - 20), Color(1, 1, 1, 0.035))
	# teto e rodapé
	draw_rect(Rect2(0, 0, W, 16), bot.darkened(0.45))
	draw_rect(Rect2(0, 16, W, 5), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(0, 204, W, 18), bot.darkened(0.3))
	draw_rect(Rect2(0, 204, W, 3), trim.darkened(0.2))
	# piso de tábuas
	draw_rect(Rect2(0, FLOOR_Y, W, 18), Color("4a2f3f") if type != &"spa" else Color("2b5266"))
	draw_rect(Rect2(0, FLOOR_Y, W, 4), Color(1, 1, 1, 0.14))
	for x in range(0, 1000, 90):
		draw_rect(Rect2(x, FLOOR_Y + 4, 3, 14), Color(0, 0, 0, 0.22))
	_draw_shafts()
	match type:
		&"lobby":
			_lobby(trim)
		&"suite":
			_suite(trim)
		&"bar":
			_bar()
		&"buffet":
			_buffet()
		&"spa":
			_spa()
		&"boutique":
			_boutique()
		&"gym":
			_gym()
		&"housekeeping":
			_housekeeping()
		&"marketing":
			_marketing()

## Placa do número do andar + nome + estrelas de nível (por cima dos adereços).
func _plate() -> void:
	var sx := Geo.shaft_x(shafts - 1) + 52.0
	draw_circle(Vector2(sx + 26, 44), 22, Color("c9a24a"))
	draw_circle(Vector2(sx + 26, 44), 18, Color("ffe08a"))
	draw_string(UIKit.font(700), Vector2(sx + 26 - 20, 44 + 10), str(idx), HORIZONTAL_ALIGNMENT_CENTER, 40, 28, Color("5a3a12"))
	Art.rrect(self, Rect2(sx + 62, 28, 230, 34), Color(0, 0, 0, 0.55), 12.0)
	draw_string(UIKit.font(600), Vector2(sx + 74, 53), title, HORIZONTAL_ALIGNMENT_LEFT, 206, 24, Color("f7f2ff"))
	if type != &"lobby":
		for s in range(RoomDB.max_level(type)):
			Art.star(self, Vector2(sx + 74 + s * 24, 78), 9.0, Color("ffd166") if s < level else Color(1, 1, 1, 0.2))

func _draw_shafts() -> void:
	var end := Geo.shaft_x(shafts - 1) + Geo.SHAFT_W * 0.5 + 12.0
	# parede do bloco de elevadores (pedra mais escura)
	draw_rect(Rect2(0, 16, end, FLOOR_Y - 16), Color(0.06, 0.04, 0.12))
	draw_rect(Rect2(end, 16, 8, FLOOR_Y - 16), Color(0, 0, 0, 0.35))
	for i in range(shafts):
		var x := Geo.shaft_x(i)
		var w := Geo.SHAFT_W
		Art.rrect(self, Rect2(x - w * 0.5 - 5, 22, w + 10, FLOOR_Y - 22), Color("5f5a78"), 8.0)
		Art.rrect(self, Rect2(x - w * 0.5, 30, w, FLOOR_Y - 30), Color("0c0818"), 5.0)
		# lanterna de chamada acima da porta
		draw_circle(Vector2(x, 20), 5, Color("ffb86b"))

# --- peças reutilizáveis ----------------------------------------------------------------

func _window(x: float, y: float, w: float, h: float) -> void:
	Art.rrect(self, Rect2(x - 6, y - 6, w + 12, h + 12), Color("2a1a3e"), 10.0)
	draw_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), PackedColorArray([Color("15103a"), Color("15103a"), Color("3b2a78"), Color("3b2a78")]))
	draw_circle(Vector2(x + w * 0.7, y + h * 0.3), w * 0.16, Color("fff0b8"))
	draw_circle(Vector2(x + w * 0.76, y + h * 0.26), w * 0.14, Color("15103a"))
	for s in [Vector2(0.2, 0.2), Vector2(0.35, 0.55), Vector2(0.55, 0.15), Vector2(0.15, 0.7)]:
		draw_circle(Vector2(x + w * s.x, y + h * s.y), 2.0, Color(1, 1, 1, 0.8))
	draw_rect(Rect2(x + w * 0.5 - 2, y, 4, h), Color("2a1a3e"))
	draw_rect(Rect2(x, y + h * 0.5 - 2, w, 4), Color("2a1a3e"))

func _picture(x: float, y: float, w: float, h: float, tint: Color) -> void:
	Art.rrect(self, Rect2(x, y, w, h), Color("c9a24a"), 6.0)
	Art.rrect(self, Rect2(x + 5, y + 5, w - 10, h - 10), tint.darkened(0.5), 4.0)
	draw_circle(Vector2(x + w * 0.5, y + h * 0.45), minf(w, h) * 0.22, tint.lightened(0.3))
	draw_rect(Rect2(x + w * 0.3, y + h * 0.7, w * 0.4, h * 0.14), tint.lightened(0.3))

func _plant(x: float, base: float = FLOOR_Y) -> void:
	Art.rrect(self, Rect2(x - 18, base - 30, 36, 30), Color("b05a3c"), 8.0)
	for a in [-0.8, -0.3, 0.2, 0.7]:
		var tip := Vector2(x + sin(a) * 44.0, base - 30.0 - cos(a) * 52.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, base - 28), tip, Vector2(x + 5, base - 28)]), Color("4fc07a"))

func _candle(x: float, base: float) -> void:
	draw_circle(Vector2(x, base - 30), 28.0, Color(1.0, 0.8, 0.4, 0.07))
	Art.rrect(self, Rect2(x - 4, base - 22, 8, 20), Color("f4ecd8"), 3.0)

func _chandelier(x: float, y: float, w: float) -> void:
	draw_line(Vector2(x, 16), Vector2(x, y), Color("c9a24a"), 4.0)
	Art.rrect(self, Rect2(x - w * 0.5, y, w, 8), Color("c9a24a"), 4.0)
	for i in range(5):
		var cx := x - w * 0.5 + 8.0 + float(i) * (w - 16.0) / 4.0
		Art.rrect(self, Rect2(cx - 3, y - 12, 6, 14), Color("f4ecd8"), 2.0)
		draw_circle(Vector2(cx, y - 18), 5.0, Color("ffd978"))
		draw_circle(Vector2(cx, y - 18), 14.0, Color(1.0, 0.85, 0.4, 0.08))

func _rug(x: float, w: float, col: Color) -> void:
	draw_colored_polygon(Art.ellipse(x, FLOOR_Y - 2, w * 0.5, 7, 28), col.darkened(0.2))
	draw_colored_polygon(Art.ellipse(x, FLOOR_Y - 3, w * 0.42, 5, 28), col)

# --- saguão ----------------------------------------------------------------------------

func _lobby(trim: Color) -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	_chandelier(560, 78, 150)
	_window(end + 40, 96, 74, 70)
	_picture(end + 150, 100, 64, 80, Color("8a78e8"))
	# tapete vermelho da porta até o elevador
	Art.rrect(self, Rect2(end + 20, FLOOR_Y - 8, W - end - 60, 8), Color("b32e4d"), 3.0)
	Art.rrect(self, Rect2(end + 20, FLOOR_Y - 8, W - end - 60, 3), Color("d9586f"), 2.0)
	# balcões de recepção
	for i in range(desks):
		var dx: float = Geo.DESK_XS[i]
		Art.rrect(self, Rect2(dx - 56, 146, 112, 76), Color("6b3a2a"), 10.0)
		Art.rrect(self, Rect2(dx - 62, 138, 124, 16), Color("8a4e36"), 8.0)
		Art.rrect(self, Rect2(dx - 62, 138, 124, 5), Color("b46f4c"), 3.0)
		# sininho
		draw_circle(Vector2(dx + 34, 133), 7, Color("ffd166"))
		Art.rrect(self, Rect2(dx + 28, 137, 12, 4), Color("c98a1d"), 2.0)
	# sofá de espera perto do elevador
	Art.rrect(self, Rect2(end + 80, 176, 130, 46), Color("7b3a6a"), 14.0)
	Art.rrect(self, Rect2(end + 74, 160, 142, 30), Color("93497f"), 14.0)
	_plant(end + 250)
	# porta de entrada (parede da direita)
	Art.rrect(self, Rect2(W - 66, 60, 62, FLOOR_Y - 60), Color("2a1a3e"), 14.0)
	Art.rrect(self, Rect2(W - 56, 70, 42, FLOOR_Y - 70), Color("9ad7f0", 0.5), 10.0)
	draw_rect(Rect2(W - 36, 70, 4, FLOOR_Y - 70), Color("2a1a3e"))
	Art.rrect(self, Rect2(W - 130, 90, 64, 26), Color("2a1a3e"), 8.0)
	draw_string(UIKit.font(700), Vector2(W - 130, 110), "OPEN", HORIZONTAL_ALIGNMENT_CENTER, 64, 18, trim)
	_plant(W - 90)

# --- suíte -----------------------------------------------------------------------------

func _suite(trim: Color) -> void:
	var bed_n := int(RoomDB.at(&"suite", "beds", level))
	var end := Geo.shaft_x(shafts - 1) + 60.0
	_window(end + 40, 96, 70, 74)
	if level >= 2:
		_rug(690, 520, Color("5a3a8a") if level < 4 else Color("8a2f55"))
	if level >= 3:
		_chandelier(690, 70, 130)
	if level >= 4:
		for dx in [end + 20.0, end + 126.0]:      # cortinas
			draw_colored_polygon(PackedVector2Array([Vector2(dx, 86), Vector2(dx + 22, 86), Vector2(dx + 30, 188), Vector2(dx - 6, 188)]), Color("a02a54"))
	if level >= 5:
		draw_rect(Rect2(0, 16, W, 6), Color("ffd166"))
		for x in range(int(end) + 20, 1000, 120):
			Art.rrect(self, Rect2(x, 40, 84, 5), Color("ffd166", 0.55), 2.0)
	var mat: Color = MATTRESS[clampi(level - 1, 0, 4)]
	for bi in range(bed_n):
		var bx: float = Geo.BED_XS[bi]
		_picture(bx - 30, 84, 60, 52, Color("c9a8ff") if bi % 2 == 0 else Color("9ae0c0"))
		# cama: cabeceira, colchão, pés
		Art.rrect(self, Rect2(bx - 62, 130, 14, 92), Color("5a3626"), 6.0)
		Art.rrect(self, Rect2(bx - 62, 174, 126, 40), mat.darkened(0.3), 12.0)
		Art.rrect(self, Rect2(bx - 56, 166, 116, 38), mat, 12.0)
		Art.rrect(self, Rect2(bx - 52, 168, 36, 18), Color("fffdfa"), 8.0)        # travesseiro
		Art.rrect(self, Rect2(bx - 10, 170, 70, 34), mat.lightened(0.18), 10.0)   # coberta
		Art.rrect(self, Rect2(bx + 58, 180, 8, 42), Color("5a3626"), 4.0)
		if bi < bed_n - 1:
			var nx := (bx + float(Geo.BED_XS[bi + 1])) * 0.5 + 6.0
			Art.rrect(self, Rect2(nx - 16, 184, 32, 38), Color("5a3626"), 6.0)
			_candle(nx, 188)

# --- facilidades ---------------------------------------------------------------------------

func _seat_count() -> int:
	return int(RoomDB.at(type, "seats", level))

func _bar() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	for sy in [70.0, 112.0]:
		Art.rrect(self, Rect2(end + 120, sy, W - end - 150, 6), Color("5a3626"), 3.0)
		var cols := [Color("ff6b8b"), Color("7be8ff"), Color("ffd166"), Color("8ef0b8"), Color("c9a8ff")]
		var k := 0
		var x := end + 134.0
		while x < W - 60.0:
			var c: Color = cols[k % 5]
			Art.rrect(self, Rect2(x, sy - 30, 14, 30), c, 5.0)
			Art.rrect(self, Rect2(x + 3, sy - 38, 8, 10), c.lightened(0.2), 3.0)
			x += 34.0
			k += 1
	Art.rrect(self, Rect2(W - 330, 28, 150, 32), Color("ff3d6e", 0.25), 12.0)
	draw_string(UIKit.font(700), Vector2(W - 330, 53), "BAR", HORIZONTAL_ALIGNMENT_CENTER, 150, 28, Color("ff7a96"))
	Art.rrect(self, Rect2(end + 130, 150, W - end - 160, 72), Color("3b1f2b"), 10.0)
	Art.rrect(self, Rect2(end + 124, 142, W - end - 148, 16), Color("6a3a45"), 8.0)
	for si in range(_seat_count()):
		var sx: float = Geo.SEAT_XS[si]
		Art.rrect(self, Rect2(sx - 5, 188, 10, 34), Color("8a8aa8"), 3.0)
		draw_colored_polygon(Art.ellipse(sx, 186, 20, 8, 16), Color("c43a63"))

func _buffet() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	for lx in [end + 220.0, 680.0, 860.0]:
		draw_line(Vector2(lx, 16), Vector2(lx, 58), Color("c9a24a"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(lx - 26, 74), Vector2(lx + 26, 74), Vector2(lx + 12, 56), Vector2(lx - 12, 56)]), Color("ffd978"))
		draw_circle(Vector2(lx, 80), 22.0, Color(1, 0.85, 0.4, 0.08))
	Art.rrect(self, Rect2(end + 140, 156, W - end - 170, 66), Color("f2ecf8"), 6.0)
	Art.rrect(self, Rect2(end + 130, 148, W - end - 150, 14), Color("ffffff"), 6.0)
	var x := end + 180.0
	var k := 0
	while x < W - 80.0:
		if k % 2 == 0:       # cérebro numa cúpula
			draw_colored_polygon(Art.ellipse(x, 140, 24, 18, 18), Color("ffa3c4"))
			draw_arc(Vector2(x, 140), 12, PI, TAU, 10, Color("e0678f"), 4.0, true)
		else:                # torta de abóbora
			draw_colored_polygon(Art.ellipse(x, 142, 22, 12, 18), Color("ff9f43"))
			draw_colored_polygon(Art.ellipse(x, 138, 16, 7, 18), Color("ffc26b"))
		x += 90.0
		k += 1
	for si in range(_seat_count()):
		var sx: float = Geo.SEAT_XS[si]
		Art.rrect(self, Rect2(sx - 16, 176, 32, 46), Color("6b3a2a"), 8.0)

func _spa() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	Art.rrect(self, Rect2(end + 150, 56, 260, 84), Color("1d3d52"), 8.0)       # azulejos
	for tx in range(int(end) + 160, int(end) + 400, 40):
		draw_rect(Rect2(tx, 56, 2, 84), Color(1, 1, 1, 0.1))
	Art.rrect(self, Rect2(end + 130, 168, W - end - 160, 52), Color("3ec6e0"), 18.0)
	Art.rrect(self, Rect2(end + 138, 174, W - end - 176, 40), Color("7be8ff"), 14.0)
	for i in range(5):                     # toalhas empilhadas
		Art.rrect(self, Rect2(end + 20 + 0, 190 - i * 8, 62, 8), Color("ffd0e6") if i % 2 == 0 else Color("fff0f6"), 3.0)
	for si in range(_seat_count()):
		var sx: float = Geo.SEAT_XS[si]
		draw_colored_polygon(Art.ellipse(sx, 196, 24, 8, 16), Color(1, 1, 1, 0.2))
	_plant(end + 110)

func _boutique() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	Art.rrect(self, Rect2(end + 20, 70, 100, 130), Color("e9d6ff", 0.25), 50.0)      # espelho oval
	Art.rrect(self, Rect2(end + 28, 78, 84, 114), Color("e9d6ff", 0.35), 42.0)
	for sy in [92.0, 140.0]:
		Art.rrect(self, Rect2(W - 230, sy, 200, 6), Color("5a3626"), 3.0)
		for i in range(4):
			var px := W - 215.0 + float(i) * 48.0
			Art.fill(self, PackedVector2Array([Vector2(px - 12, sy), Vector2(px + 12, sy), Vector2(px + 2, sy - 28)]), Color("5a36a8") if i % 2 == 0 else Color("ff9f43"))
			draw_colored_polygon(Art.ellipse(px, sy, 16, 4, 12), Color("2a1838"))
	for i in range(3):                      # manequins
		var mx := end + 190.0 + float(i) * 120.0
		Art.rrect(self, Rect2(mx - 3, 150, 6, 72), Color("8a8aa8"), 2.0)
		Art.rrect(self, Rect2(mx - 22, 196 + 20, 44, 6), Color("8a8aa8"), 3.0)
		draw_colored_polygon(Art.egg(mx, 128, 22, 26, 20, 20), Color("ff9ee0") if i % 2 == 0 else Color("9ae0ff"))
		draw_colored_polygon(Art.ellipse(mx, 96, 12, 13, 14), Color("f2d9c4"))
		Art.fill(self, PackedVector2Array([Vector2(mx - 14, 90), Vector2(mx + 14, 90), Vector2(mx + 3, 62)]), Color("34205c"))
	for si in range(_seat_count()):
		var sx: float = Geo.SEAT_XS[si]
		draw_colored_polygon(Art.ellipse(sx, 220, 22, 5, 14), Color(0, 0, 0, 0.2))

func _gym() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	Art.rrect(self, Rect2(end + 20, 70, 130, 140), Color("e9d6ff", 0.16), 8.0)       # espelho
	draw_line(Vector2(W - 200, 16), Vector2(W - 200, 120), Color("8a8aa8"), 4.0)
	draw_colored_polygon(Art.ellipse(W - 200, 150, 22, 34, 18), Color("c43a3a"))     # saco de pancada
	# estante de halteres
	Art.rrect(self, Rect2(end + 190, 150, 190, 12), Color("5a3626"), 4.0)
	for i in range(4):
		var hx := end + 214.0 + float(i) * 44.0
		Art.rrect(self, Rect2(hx - 14, 134, 28, 8), Color("8a8aa8"), 3.0)
		draw_circle(Vector2(hx - 14, 138), 9.0, Color("3a3a58"))
		draw_circle(Vector2(hx + 14, 138), 9.0, Color("3a3a58"))
	Art.rrect(self, Rect2(end + 190, 162, 190, 60), Color("3b2a22"), 4.0)
	for si in range(_seat_count()):
		var sx: float = Geo.SEAT_XS[si]
		Art.rrect(self, Rect2(sx - 30, 202, 60, 20), Color("2a2a44"), 6.0)
		Art.rrect(self, Rect2(sx - 20, 192, 40, 10), Color("5a5a88"), 4.0)

func _housekeeping() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	for i in range(3):
		var mx := end + 70.0 + float(i) * 150.0
		Art.rrect(self, Rect2(mx - 44, 112, 88, 110), Color("dfe6f5"), 12.0)
		draw_circle(Vector2(mx, 170), 30.0, Color("8c9ab8"))
		draw_circle(Vector2(mx, 170), 24.0, Color("4a6a9a"))
		draw_arc(Vector2(mx, 170), 14, 0.0, PI, 10, Color(1, 1, 1, 0.5), 4.0, true)
		Art.rrect(self, Rect2(mx - 30, 122, 60, 12), Color("b9c6e0"), 5.0)
	for sy in [70.0, 110.0]:
		Art.rrect(self, Rect2(end + 520, sy, 190, 6), Color("5a3626"), 3.0)
		for i in range(5):
			Art.rrect(self, Rect2(end + 530 + i * 34, sy - 22, 28, 22), Color("fff0f6") if i % 2 == 0 else Color("cfe6ff"), 4.0)
	Art.rrect(self, Rect2(W - 120, 170, 60, 52), Color("6a8ac0"), 8.0)           # balde
	Art.rrect(self, Rect2(W - 100, 100, 6, 74), Color("b9a07a"), 3.0)             # esfregão

func _marketing() -> void:
	var end := Geo.shaft_x(shafts - 1) + 60.0
	Art.rrect(self, Rect2(end + 40, 56, 190, 110), Color("2a1838"), 10.0)           # quadro com gráfico
	Art.rrect(self, Rect2(end + 48, 64, 174, 94), Color("f2ecf8"), 6.0)
	var pts := PackedVector2Array([Vector2(end + 62, 140), Vector2(end + 100, 120), Vector2(end + 136, 128), Vector2(end + 176, 92), Vector2(end + 208, 76)])
	draw_polyline(pts, Color("2fd8bd"), 5.0, true)
	for i in range(3):
		_picture(end + 270 + i * 90, 70, 66, 88, [Color("ff7a96"), Color("7be8ff"), Color("ffd166")][i])
	Art.rrect(self, Rect2(W - 330, 156, 240, 14), Color("6b3a2a"), 6.0)
	Art.rrect(self, Rect2(W - 320, 168, 14, 54), Color("6b3a2a"), 4.0)
	Art.rrect(self, Rect2(W - 116, 168, 14, 54), Color("6b3a2a"), 4.0)
	Art.rrect(self, Rect2(W - 260, 112, 70, 44), Color("2a1838"), 6.0)               # monitor
	Art.rrect(self, Rect2(W - 254, 118, 58, 32), Color("5eead4"), 4.0)
	Art.fill(self, PackedVector2Array([Vector2(W - 170, 140), Vector2(W - 134, 126), Vector2(W - 134, 156)]), Color("ffd166"))  # megafone

# --- camada dinâmica ---------------------------------------------------------------------------

func draw_dyn(c: CanvasItem) -> void:
	var r: RoomState = hotel.floors[idx]
	if r.type == &"suite":
		for bi in range(r.beds.size()):
			var b: RoomState.Bed = r.beds[bi]
			var bx: float = Geo.BED_XS[bi]
			if b.dirty:
				# cama bagunçada + moscas
				c.draw_colored_polygon(Art.ellipse(bx + 4, 190, 50, 12, 18), Color(0.25, 0.2, 0.1, 0.5))
				for k in range(3):
					var a := dyn_t * 4.0 + float(k) * 2.1
					c.draw_circle(Vector2(bx + cos(a) * 26.0, 150.0 + sin(a * 1.3) * 12.0), 2.6, Color("1b1230"))
				if b.claimed:
					Art.rrect(c, Rect2(bx - 22, 128, 44, 22), Color(0, 0, 0, 0.45), 8.0)
					c.draw_string(UIKit.font(600), Vector2(bx - 18, 145), "...", HORIZONTAL_ALIGNMENT_CENTER, 36, 20, Color("a9c6ff"))
			if b.occupant != null or b.reserved != null:
				pass
		# velas: brilho que pisca
		for bi in range(r.beds.size() - 1):
			var nx: float = (float(Geo.BED_XS[bi]) + float(Geo.BED_XS[bi + 1])) * 0.5 + 6.0
			var fl := 1.0 + sin(dyn_t * 9.0 + float(bi) * 1.7) * 0.18
			c.draw_colored_polygon(Art.egg(nx, 168, 4.5 * fl, 9 * fl, 3, 10), Color("ffd978"))
	elif RoomDB.kind(r.type) == &"facility":
		if r.type == &"spa":
			for k in range(7):
				var u := fmod(dyn_t * 0.35 + float(k) * 0.143, 1.0)
				var bxp := 560.0 + float(k) * 52.0
				c.draw_circle(Vector2(bxp + sin(u * 9.0) * 6.0, 170.0 - u * 70.0), 7.0 * (1.0 - u * 0.5), Color(1, 1, 1, 0.22 * (1.0 - u)))
		if not r.queue.is_empty():
			Art.rrect(c, Rect2(Geo.FAC_WAIT_X0 - 16, 118, 20 + r.queue.size() * 26, 22), Color(0, 0, 0, 0.45), 10.0)
			c.draw_string(UIKit.font(600), Vector2(Geo.FAC_WAIT_X0 - 8, 135), Loc.t("hud.queue", [r.queue.size()]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7f2ff"))
	elif r.type == &"lobby":
		if hotel.reception_queue.size() >= 3:
			var n := hotel.reception_queue.size()
			Art.rrect(c, Rect2(Geo.QUEUE_X0 - 18, 110, 100, 24), Color(0, 0, 0, 0.5), 10.0)
			c.draw_string(UIKit.font(600), Vector2(Geo.QUEUE_X0 - 10, 128), Loc.t("hud.queue", [n]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffd166"))
	if selected:
		Art.rrect(c, Rect2(2, 2, W - 4, H - 4), Color(0, 0, 0, 0), 6.0, Color("ffd166"), 6.0)

func tick(delta: float) -> void:
	dyn_t += delta
	dyn.queue_redraw()
