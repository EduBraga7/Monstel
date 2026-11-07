class_name Scenery
extends Node2D
## Terreno, paredes externas, telhado, placa e o terreno vazio do próximo andar.
## Desenhado uma vez (refresh() quando a torre cresce).

const W := Geo.FLOOR_W
const H := Geo.FLOOR_H
const WALL := 30.0
const GROUND_RECT := Rect2(-900.0, -230.0, 2900.0, 400.0)   # parte do cenário pré-renderizada (colinas, jardim, fundação)
const ROOF_RECT := Rect2(-90.0, -312.0, 1180.0, 322.0)      # telhado, relativo à base (y=0 é o beiral)
const GROUND_SCALE := 1.0
const ROOF_SCALE := 1.25

var hotel: Hotel
var sign_text := "Hotel Boo"
var plot_visible := true
## root = cenário completo; as outras são instâncias auxiliares que desenham uma parte:
## plot (terreno vazio, só ao vivo quando visível), sign (texto da placa), paint_ground / paint_roof (pintores do Baker).
var kind := "root"
var plot_item: Scenery
var sign_item: Scenery
var ground_sprite: Sprite2D
var roof_sprite: Sprite2D
var _ground_ready := false
var _roof_ready := false

func setup(h: Hotel) -> void:
	hotel = h
	# ordem de desenho (filhos desenham depois do próprio nó): chão pré-renderizado, terreno vazio, telhado pré-renderizado, texto da placa
	ground_sprite = _new_sprite()
	plot_item = _new_part("plot")
	roof_sprite = _new_sprite()
	sign_item = _new_part("sign")
	Baker.request("scenery|ground", GROUND_RECT.size, GROUND_SCALE, _make_painter.bind("paint_ground", -GROUND_RECT.position), _on_ground_baked)
	Baker.request("scenery|roof", ROOF_RECT.size, ROOF_SCALE, _make_painter.bind("paint_roof", -ROOF_RECT.position), _on_roof_baked)
	if Baker.cache.has("scenery|ground"):
		_on_ground_baked(Baker.cache["scenery|ground"])
	if Baker.cache.has("scenery|roof"):
		_on_roof_baked(Baker.cache["scenery|roof"])
	refresh()

func _new_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.material = Baker.premult_material()
	s.visible = false
	add_child(s)
	return s

func _new_part(k: String) -> Scenery:
	var p := Scenery.new()
	p.kind = k
	p.hotel = hotel
	add_child(p)
	return p

static func _make_painter(k: String, pos: Vector2) -> Scenery:
	var p := Scenery.new()
	p.kind = k
	p.position = pos
	return p

func _on_ground_baked(tex: Texture2D) -> void:
	ground_sprite.texture = tex
	ground_sprite.position = GROUND_RECT.position
	ground_sprite.scale = GROUND_RECT.size / tex.get_size()
	ground_sprite.visible = true
	_ground_ready = true
	queue_redraw()

func _on_roof_baked(tex: Texture2D) -> void:
	roof_sprite.texture = tex
	roof_sprite.scale = ROOF_RECT.size / tex.get_size()
	roof_sprite.visible = true
	_roof_ready = true
	refresh()
	queue_redraw()

func refresh() -> void:
	plot_visible = hotel.floors.size() < Balance.MAX_FLOORS
	var roof_base := top_y() - (H if plot_visible else 0.0)
	if plot_item != null:
		plot_item.plot_visible = plot_visible
		plot_item.queue_redraw()
	if roof_sprite != null:
		roof_sprite.position = ROOF_RECT.position + Vector2(0.0, roof_base)
	if sign_item != null:
		sign_item.sign_text = sign_text
		sign_item.queue_redraw()
	queue_redraw()

## Topo (y negativo) do último andar construído.
func top_y() -> float:
	return -float(hotel.floors.size()) * H

func plot_rect() -> Rect2:
	return Rect2(0.0, top_y() - H, W, H)

func _draw() -> void:
	match kind:
		"paint_ground":
			_far_hills()
			_ground_details()
			_decor()
		"paint_roof":
			_roof(0.0)
		"plot":
			if plot_visible:
				_plot(plot_rect())
		"sign":
			_sign_text(top_y() - (H if plot_visible else 0.0))
		_:
			var roof_base := top_y() - (H if plot_visible else 0.0)
			_ground_fill()
			if not _ground_ready:                 # antes de a imagem ficar pronta (ou sem renderer): desenha ao vivo
				_far_hills()
				_ground_details()
				_decor()
			_walls(roof_base)
			if not _roof_ready:
				_roof(roof_base)

func _far_hills() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(-900, 0))
	for i in range(0, 25):
		var x := -900.0 + float(i) * 100.0
		pts.append(Vector2(x, -120.0 - sin(float(i) * 0.9) * 55.0 - cos(float(i) * 0.37) * 40.0))
	pts.append(Vector2(1600, 0))
	draw_colored_polygon(pts, Color("1d0f3d"))
	# árvores tortas na colina distante
	for tx in [-380.0, -120.0, 1180.0, 1380.0]:
		var base := Vector2(tx, -40.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 0), base + Vector2(9, 0), base + Vector2(3, -110), base + Vector2(-5, -150), base + Vector2(-12, -110)]), Color("150a2e"))
		draw_line(base + Vector2(0, -90), base + Vector2(-44, -128), Color("150a2e"), 6.0)
		draw_line(base + Vector2(2, -112), base + Vector2(40, -140), Color("150a2e"), 5.0)

func _ground_fill() -> void:
	draw_polygon(PackedVector2Array([Vector2(-900, 0), Vector2(2000, 0), Vector2(2000, 700), Vector2(-900, 700)]), PackedColorArray([Color("2f8a74"), Color("2f8a74"), Color("0f3a40"), Color("0f3a40")]))

func _ground_details() -> void:
	draw_rect(Rect2(-900, 0, 2900, 8), Color("52b896"))
	# fundação de pedra e calçada
	draw_rect(Rect2(-WALL, 0, W + WALL * 2, 34), Color("3b3252"))
	draw_rect(Rect2(-WALL, 0, W + WALL * 2, 6), Color("6a5f8a"))
	for x in range(-int(WALL), int(W + WALL), 60):
		draw_rect(Rect2(x, 6, 3, 28), Color(0, 0, 0, 0.25))
	Art.rrect(self, Rect2(W - 120, 0, 700, 22), Color("5b5078"), 6.0)

## Elementos do jardim espalhados em três fileiras (as de trás primeiro), longe do caminho da porta.
func _decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for row in range(3):
		var y := 62.0 + float(row) * 44.0
		var s := 0.72 + float(row) * 0.2
		var x := -110.0 + rng.randf() * 40.0
		while x < 1130.0:
			var kind := rng.randi() % 7
			var jy := y + rng.randf_range(-8.0, 8.0)
			match kind:
				0, 1:
					_tombstone(x, jy, s * rng.randf_range(0.9, 1.15))
				2:
					_bush(x, jy, s)
				3:
					_pumpkin(x, jy, s)
				4:
					_tuft(x, jy, s)
				5:
					_mushrooms(x, jy, s)
				6:
					_fence(x, jy, s)
			x += rng.randf_range(80.0, 150.0) * (1.0 + (2.0 - float(row)) * 0.05)
	# poste de luz junto da entrada
	Art.rrect(self, Rect2(W + 58, -150, 10, 168), Color("1a1030"), 4.0)
	draw_circle(Vector2(W + 63, -162), 17.0, Color("ffd978"))
	draw_circle(Vector2(W + 63, -162), 52.0, Color(1.0, 0.85, 0.4, 0.1))

func _shadow(x: float, y: float, w: float) -> void:
	draw_colored_polygon(Art.ellipse(x, y + 3.0, w, w * 0.22, 14), Color(0, 0, 0, 0.22))

func _tombstone(x: float, y: float, s: float) -> void:
	var w := 50.0 * s
	var h := 66.0 * s
	_shadow(x, y, w * 0.7)
	Art.rrect(self, Rect2(x - w * 0.5, y - h, w, h), Color("9a93b8"), w * 0.5)
	Art.rrect(self, Rect2(x - w * 0.5, y - h * 0.55, w, h * 0.55), Color("9a93b8"), 4.0)
	Art.rrect(self, Rect2(x - w * 0.5, y - h * 0.1, w, h * 0.1), Color("7d769d"), 3.0)
	Art.rrect(self, Rect2(x - w * 0.1, y - h * 0.82, w * 0.2, h * 0.46), Color("6a6390"), 3.0)
	Art.rrect(self, Rect2(x - w * 0.27, y - h * 0.68, w * 0.54, h * 0.13), Color("6a6390"), 3.0)

func _bush(x: float, y: float, s: float) -> void:
	_shadow(x, y, 46.0 * s)
	for k in range(3):
		var c := Color("1f6b4d") if k != 1 else Color("2a8a62")
		draw_circle(Vector2(x + float(k - 1) * 26.0 * s, y - 16.0 * s - float(k % 2) * 8.0 * s), 24.0 * s, c)

func _pumpkin(x: float, y: float, s: float) -> void:
	_shadow(x, y, 34.0 * s)
	draw_colored_polygon(Art.ellipse(x, y - 22.0 * s, 32.0 * s, 24.0 * s, 20), Color("ff9f43"))
	draw_colored_polygon(Art.ellipse(x - 15.0 * s, y - 22.0 * s, 15.0 * s, 24.0 * s, 16), Color("e8801f"))
	draw_colored_polygon(Art.ellipse(x + 15.0 * s, y - 22.0 * s, 15.0 * s, 24.0 * s, 16), Color("e8801f"))
	draw_rect(Rect2(x - 3.0 * s, y - 52.0 * s, 6.0 * s, 10.0 * s), Color("4a7a3a"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 15.0 * s, y - 28.0 * s), Vector2(x - 5.0 * s, y - 28.0 * s), Vector2(x - 10.0 * s, y - 38.0 * s)]), Color("ffe08a"))
	draw_colored_polygon(PackedVector2Array([Vector2(x + 15.0 * s, y - 28.0 * s), Vector2(x + 5.0 * s, y - 28.0 * s), Vector2(x + 10.0 * s, y - 38.0 * s)]), Color("ffe08a"))
	Art.rrect(self, Rect2(x - 15.0 * s, y - 20.0 * s, 30.0 * s, 8.0 * s), Color("ffe08a"), 4.0)

func _tuft(x: float, y: float, s: float) -> void:
	for k in range(5):
		var bx := x + float(k - 2) * 7.0 * s
		var hh := (24.0 + float((k * 7) % 5) * 5.0) * s
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 4.0 * s, y), Vector2(bx + 4.0 * s, y), Vector2(bx + float(k - 2) * 3.0 * s, y - hh)]), Color("3fae7e") if k % 2 == 0 else Color("2a8a62"))

func _mushrooms(x: float, y: float, s: float) -> void:
	_shadow(x, y, 30.0 * s)
	for k in range(2):
		var mx := x + float(k) * 26.0 * s - 10.0 * s
		var sz := (1.0 if k == 0 else 0.7) * s
		Art.rrect(self, Rect2(mx - 6.0 * sz, y - 24.0 * sz, 12.0 * sz, 24.0 * sz), Color("f2e8d0"), 4.0)
		draw_colored_polygon(Art.egg(mx, y - 26.0 * sz, 20.0 * sz, 18.0 * sz, 5.0 * sz, 18), Color("e8435f"))
		draw_circle(Vector2(mx - 7.0 * sz, y - 32.0 * sz), 3.2 * sz, Color("fff0f0"))
		draw_circle(Vector2(mx + 6.0 * sz, y - 28.0 * sz), 2.6 * sz, Color("fff0f0"))

func _fence(x: float, y: float, s: float) -> void:
	for k in range(3):
		var fx := x + float(k) * 22.0 * s
		Art.rrect(self, Rect2(fx, y - 54.0 * s, 8.0 * s, 56.0 * s), Color("1a1030"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - 3.0 * s, y - 54.0 * s), Vector2(fx + 11.0 * s, y - 54.0 * s), Vector2(fx + 4.0 * s, y - 70.0 * s)]), Color("1a1030"))
	draw_rect(Rect2(x - 4.0 * s, y - 34.0 * s, 62.0 * s, 6.0 * s), Color("1a1030"))

func _walls(roof_base: float) -> void:
	var top := roof_base
	for side in [-1.0, 1.0]:
		var x0 := -WALL if side < 0.0 else W
		draw_rect(Rect2(x0, top, WALL, -top), Color("3d3356"))
		draw_rect(Rect2(x0 if side < 0.0 else x0 + WALL - 5, top, 5, -top), Color(0, 0, 0, 0.25))
		var y := top
		var k := 0
		while y < 0.0:
			draw_rect(Rect2(x0, y, WALL, 3), Color(0, 0, 0, 0.28))
			if k % 2 == 0:
				draw_rect(Rect2(x0 + 14, y, 3, 26), Color(0, 0, 0, 0.2))
			y += 26.0
			k += 1

func _plot(r: Rect2) -> void:
	# terreno vazio: parede de fundo escura + andaime + "+"
	draw_rect(r, Color(0.08, 0.05, 0.16, 0.85))
	var step := 36.0
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y + 4, 14, 14), Color("ffd166", 0.35))
		draw_rect(Rect2(x, r.end.y - 18, 14, 14), Color("ffd166", 0.35))
		x += step * 2.0
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x + 4, y, 14, 14), Color("ffd166", 0.35))
		draw_rect(Rect2(r.end.x - 18, y, 14, 14), Color("ffd166", 0.35))
		y += step * 2.0
	for i in range(5):                       # vigas diagonais do andaime
		var bx := r.position.x + 120.0 + float(i) * 190.0
		draw_line(Vector2(bx, r.end.y - 16), Vector2(bx + 150.0, r.position.y + 20), Color("b9a07a", 0.35), 6.0)
	var c := r.get_center()
	draw_circle(c, 52, Color("ffd166", 0.25))
	draw_circle(c, 44, Color("ffd166"))
	Art.rrect(self, Rect2(c.x - 5, c.y - 24, 10, 48), Color("5a3a12"), 4.0)
	Art.rrect(self, Rect2(c.x - 24, c.y - 5, 48, 10), Color("5a3a12"), 4.0)

func _roof(base: float) -> void:
	var peak := base - 250.0
	var pts := PackedVector2Array([Vector2(-WALL - 50, base), Vector2(W / 2.0, peak), Vector2(W + WALL + 50, base)])
	Art.fill_v(self, pts, Color("4a2b8f"), Color("2a1660"))
	var rows := 7                            # telhas
	for r in range(rows):
		var u := (float(r) + 1.0) / float(rows + 1)
		var y := lerpf(peak, base, u)
		var half := lerpf(10.0, W / 2.0 + WALL + 50.0, u)
		draw_rect(Rect2(W / 2.0 - half, y, half * 2.0, 4), Color(0, 0, 0, 0.18))
		var x := W / 2.0 - half + 18.0
		var off := 0.0 if r % 2 == 0 else 24.0
		while x + off < W / 2.0 + half - 10.0:
			draw_rect(Rect2(x + off, y, 3, lerpf(peak, base, (float(r) + 2.0) / float(rows + 1)) - y), Color(0, 0, 0, 0.14))
			x += 48.0
	draw_rect(Rect2(-WALL - 60, base - 8, W + WALL * 2 + 120, 14), Color("1a0f3a"))
	var wc := Vector2(W / 2.0, base - 128.0)  # janela redonda do sótão acesa
	draw_circle(wc, 54, Color("2a1838"))
	draw_circle(wc, 44, Color("ffd978"))
	draw_rect(Rect2(wc.x - 2, wc.y - 44, 4, 88), Color("2a1838"))
	draw_rect(Rect2(wc.x - 44, wc.y - 2, 88, 4), Color("2a1838"))
	Art.rrect(self, Rect2(W * 0.78, base - 190, 56, 120), Color("3d3356"), 6.0)       # chaminé
	Art.rrect(self, Rect2(W * 0.78 - 6, base - 200, 68, 16), Color("5b5078"), 5.0)
	draw_line(Vector2(W / 2.0, peak), Vector2(W / 2.0, peak - 56), Color("1a1030"), 5.0)      # catavento
	draw_colored_polygon(PackedVector2Array([Vector2(W / 2.0 - 22, peak - 44), Vector2(W / 2.0 + 22, peak - 38), Vector2(W / 2.0 - 22, peak - 28)]), Color("1a1030"))
	# placa com o nome, pendurada no beiral
	var sw := 330.0
	var sx := W / 2.0 - sw / 2.0
	var sy := base - 74.0
	draw_line(Vector2(sx + 30, base - 14), Vector2(sx + 30, sy + 8), Color("c9a24a"), 4.0)
	draw_line(Vector2(sx + sw - 30, base - 14), Vector2(sx + sw - 30, sy + 8), Color("c9a24a"), 4.0)
	Art.rrect(self, Rect2(sx, sy, sw, 62), Color("c9a24a"), 16.0)
	Art.rrect(self, Rect2(sx + 6, sy + 6, sw - 12, 50), Color("2a1838"), 12.0)

## Texto da placa (ao vivo, por cima do telhado pré-renderizado: o nome do hotel muda).
func _sign_text(base: float) -> void:
	var sw := 330.0
	var sx := W / 2.0 - sw / 2.0
	var sy := base - 74.0
	draw_string(UIKit.font(700), Vector2(sx + 12, sy + 42), sign_text, HORIZONTAL_ALIGNMENT_CENTER, sw - 24, 32, Color("ffd978"))
