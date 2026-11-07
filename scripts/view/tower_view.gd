class_name TowerView
extends Node2D
## Ponte entre a simulação (Hotel) e a tela: cria/atualiza andares, monstros, balões de moedas e efeitos.
## Todas as posições aqui são locais da torre (x 0..1000, y negativo para cima, chão do saguão em y=0).

signal floor_tapped(idx: int)
signal plot_tapped
signal coins_collected_at(amount: float, world_pos: Vector2)

const H := Geo.FLOOR_H
const W := Geo.FLOOR_W

var hotel: Hotel
var sky: SkyLayer
var scenery: Scenery
var floor_layer: Node2D
var floor_views: Array[FloorView] = []
var shaft_view: ShaftView
var monster_layer: Node2D
var coin_layer: Node2D
var fx_layer: Node2D
var monsters: Dictionary = {}          # id do hóspede -> MonsterView
var maid_views: Array[MonsterView] = []
var bubbles: Dictionary = {}           # andar -> CoinBubble
var speed := 1.0
var paused := false
var view_rect := Rect2(-2000, -2000, 6000, 6000)   # área visível, em coordenadas locais (definida pelo GameScreen)
var look_world := Vector2.ZERO
var selected_floor := -1

var _acc := 0.0
var _t := 0.0

func setup(h: Hotel) -> void:
	hotel = h
	scenery = Scenery.new()
	add_child(scenery)
	scenery.setup(h)
	floor_layer = Node2D.new()
	add_child(floor_layer)
	for i in range(h.floors.size()):
		_add_floor_view(i, false)
	shaft_view = ShaftView.new()
	shaft_view.z_index = 1
	add_child(shaft_view)
	shaft_view.setup(h)
	monster_layer = Node2D.new()
	monster_layer.z_index = 2
	add_child(monster_layer)
	coin_layer = Node2D.new()
	coin_layer.z_index = 3
	add_child(coin_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 4
	add_child(fx_layer)
	h.room_built.connect(_on_room_built)
	h.room_upgraded.connect(_on_room_upgraded)
	h.staff_changed.connect(_on_staff_changed)
	h.coin_spawned.connect(_on_coin_spawned)
	h.coins_collected.connect(_on_coins_collected)

func _add_floor_view(i: int, animate: bool) -> FloorView:
	var fv := FloorView.new()
	fv.position = Vector2(0, -float(i + 1) * H)
	floor_layer.add_child(fv)
	fv.setup(hotel, i)
	floor_views.append(fv)
	if animate:
		fv.modulate.a = 0.0
		var tw := fv.create_tween()
		tw.tween_property(fv, "modulate:a", 1.0, 0.5)
	return fv

# --- sinais da simulação --------------------------------------------------------

func _on_room_built(idx: int) -> void:
	_add_floor_view(idx, true)
	scenery.refresh()
	var c := Vector2(W * 0.5, -float(idx) * H - H * 0.5)
	popup(c, Loc.t("fx.built"), Color("7ee081"), 54, 1.6)
	for k in range(10):
		puff(Vector2(randf_range(60.0, W - 60.0), -float(idx) * H - 24.0))

func _on_room_upgraded(idx: int) -> void:
	floor_views[idx].refresh()
	var c := Vector2(W * 0.5, -float(idx) * H - H * 0.5)
	popup(c, Loc.t("fx.upgraded"), Color("ffd166"), 50, 1.4)
	for k in range(8):
		sparkle(c + Vector2(randf_range(-260.0, 260.0), randf_range(-70.0, 70.0)))

func _on_staff_changed() -> void:
	if floor_views.is_empty():
		return
	if floor_views[0].shafts != hotel.elevators.size() or floor_views[0].type == &"lobby":
		for fv in floor_views:
			fv.refresh()

func _on_coin_spawned(f: int, amount: float) -> void:
	if f < floor_views.size() and view_rect.has_point(Vector2(W * 0.5, -float(f) * H - H * 0.5)) and amount < 1.0e12:
		popup(Vector2(W - 150.0, -float(f) * H - 120.0), "+" + Fmt.coins(amount), Color("ffd166"), 30, 0.9)

func _on_coins_collected(f: int, amount: float) -> void:
	var pos := Vector2(W - 70.0, -float(f) * H - 170.0)
	popup(pos, "+" + Fmt.coins(amount), Color("ffe08a"), 46, 1.1)
	coins_collected_at.emit(amount, to_global(pos))

# --- efeitos -----------------------------------------------------------------------

func popup(at: Vector2, text: String, col: Color, px: int = 40, life: float = 1.2) -> void:
	var f := FxText.make(text, col, px, life)
	f.position = at
	fx_layer.add_child(f)

func puff(at: Vector2) -> void:
	var p := Puff.new()
	p.position = at
	fx_layer.add_child(p)

func sparkle(at: Vector2) -> void:
	var p := Puff.new()
	p.sparkle = true
	p.position = at
	fx_layer.add_child(p)

class Puff extends Node2D:
	var t := 0.0
	var sparkle := false
	var vel := Vector2.ZERO
	func _ready() -> void:
		vel = Vector2(randf_range(-30.0, 30.0), randf_range(-50.0, -10.0))
	func _process(delta: float) -> void:
		t += delta
		position += vel * delta
		if t > 0.8:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var u := t / 0.8
		if sparkle:
			Art.star(self, Vector2.ZERO, 16.0 * (1.0 - u), Color(1, 0.9, 0.5, 1.0 - u))
		else:
			draw_circle(Vector2.ZERO, 14.0 + u * 22.0, Color(0.85, 0.8, 0.95, 0.5 * (1.0 - u)))

# --- laço principal -------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta, 0.25)
	_t += delta
	if not paused:
		_acc += delta * speed
		var n := 0
		while _acc >= Balance.DT and n < 12:
			hotel.step(Balance.DT)
			_acc -= Balance.DT
			n += 1
		if n >= 12:
			_acc = 0.0
	var alpha := clampf(_acc / Balance.DT, 0.0, 1.0)
	shaft_view.alpha = alpha
	shaft_view.view_rect = view_rect
	_sync_monsters(delta, alpha)
	_sync_bubbles()
	_update_floors(delta)
	if sky != null:
		sky.set_hour(hotel.hour())

func _update_floors(delta: float) -> void:
	if scenery.plot_item != null:                      # terreno vazio: só desenha quando está na tela
		scenery.plot_item.visible = scenery.plot_visible and scenery.plot_rect().intersects(view_rect)
	for fv in floor_views:
		var r := Rect2(0.0, fv.position.y, W, H)
		var vis := r.intersects(view_rect)
		fv.visible = vis
		if vis:
			fv.selected = fv.idx == selected_floor
			fv.tick(delta)

func _sync_monsters(delta: float, alpha: float) -> void:
	var seen := {}
	var vr := view_rect.grow(220.0)
	for g in hotel.guests:
		if g.state == Guest.S.DEAD:
			continue
		seen[g.id] = true
		var mv: MonsterView = monsters.get(g.id)
		if mv == null:
			mv = MonsterView.new()
			mv.bind_guest(g)
			monster_layer.add_child(mv)
			monsters[g.id] = mv
		if g.bed_floor >= 0 and g.bed_floor < hotel.floors.size():
			mv.blanket = FloorView.MATTRESS[clampi(hotel.floors[g.bed_floor].level - 1, 0, 4)]
		var in_view := vr.has_point(mv.position) or mv.position == Vector2.ZERO
		mv.visible = in_view
		if in_view:
			mv.update_view(delta, alpha, look_world)
	for id in monsters.keys():
		if not seen.has(id):
			(monsters[id] as MonsterView).queue_free()
			monsters.erase(id)
	while maid_views.size() < hotel.maids.size():
		var mv2 := MonsterView.new()
		mv2.bind_maid(hotel.maids[maid_views.size()])
		monster_layer.add_child(mv2)
		maid_views.append(mv2)
	for mv3 in maid_views:
		mv3.update_view(delta, alpha, look_world)

func _sync_bubbles() -> void:
	for f in range(hotel.floors.size()):
		var r: RoomState = hotel.floors[f]
		if r.pending > 0.05:
			var b: CoinBubble = bubbles.get(f)
			if b == null:
				b = CoinBubble.new()
				b.setup(f)
				b.position = Vector2(W - 70.0, -float(f) * H - 170.0)
				coin_layer.add_child(b)
				bubbles[f] = b
			b.set_amount(r.pending)
			var vis := view_rect.has_point(b.position)
			b.visible = vis
			b.set_process(vis)
		elif bubbles.has(f):
			(bubbles[f] as CoinBubble).queue_free()
			bubbles.erase(f)

# --- toques --------------------------------------------------------------------------

## Trata um toque em coordenadas locais da torre. Devolve true se algo foi acionado.
func tap(local: Vector2) -> bool:
	for f in bubbles.keys():
		var b: CoinBubble = bubbles[f]
		if local.distance_to(b.position) < 64.0:
			hotel.collect(int(f))
			return true
	for id in monsters.keys():                      # cumprimentar VIP tocando nele
		var mv: MonsterView = monsters[id]
		if mv.guest != null and mv.guest.vip and not mv.guest.greeted and local.distance_to(mv.position + Vector2(0, -46)) < 76.0:
			if hotel.greet(mv.guest):
				popup(mv.position + Vector2(0, -150), Loc.t("toast.greeted"), Color("ffd166"), 42, 1.2)
				return true
	if scenery.plot_visible and scenery.plot_rect().has_point(local):
		plot_tapped.emit()
		return true
	if local.x >= 0.0 and local.x <= W and local.y <= 0.0:
		var f2 := int(floor(-local.y / H))
		if f2 >= 0 and f2 < hotel.floors.size():
			floor_tapped.emit(f2)
			return true
	return false

func floor_center(f: int) -> Vector2:
	return Vector2(W * 0.5, -float(f) * H - H * 0.5)

func top_extent() -> float:
	return scenery.top_y() - (H if scenery.plot_visible else 0.0) - 420.0

func collect_all_visible() -> float:
	return hotel.collect_all()
