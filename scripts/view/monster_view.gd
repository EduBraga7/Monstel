class_name MonsterView
extends Node2D
## Vista de um hóspede (ou da camareira-morcego). Lê o estado da simulação, interpola entre passos
## e desenha a pose pré-renderizada do atlas (ou o desenho procedural, se o atlas não existir).
## O corpo fica num filho "Body" (atrás) com blend pré-multiplicado; este nó desenha só as sobreposições.

class Body extends Node2D:
	var mv: MonsterView
	func _draw() -> void:
		mv.draw_body(self)

var guest: Guest = null
var maid: StaffMember = null
var species: StringName = &"ghost"
var t := 0.0
var walk := 0.0
var blink := 0.0
var flip := 1.0
var look := Vector2.ZERO
var mood: int = MonsterArt.Mood.NEUTRAL
var pop := 0.0
var blanket := Color("8a78e8")
var lying := false
var body: Body

var _blink_t := 0.0
var _next_blink := 2.0

func _init() -> void:
	body = Body.new()
	body.mv = self
	body.show_behind_parent = true
	add_child(body)

func bind_guest(g: Guest) -> void:
	guest = g
	species = g.species
	t = randf() * 10.0
	_next_blink = randf_range(1.0, 4.0)

func bind_maid(m: StaffMember) -> void:
	maid = m
	species = &"bat"
	t = randf() * 10.0

func update_view(delta: float, alpha: float, look_target: Vector2) -> void:
	t += delta
	pop = minf(1.0, pop + delta * 4.5)
	_blink_t += delta
	if _blink_t >= _next_blink:
		blink = 1.0
		_blink_t = 0.0
		_next_blink = randf_range(2.0, 5.5)
	blink = move_toward(blink, 0.0, delta * 9.0)
	if guest != null:
		var x := lerpf(guest.prev_x, guest.x, alpha)
		var fl := lerpf(guest.prev_floor, guest.floor_f, alpha)
		position = Vector2(x, -fl * Geo.FLOOR_H - 18.0)
		var moving := absf(guest.x - guest.prev_x) > 0.02 or absf(guest.floor_f - guest.prev_floor) > 0.0005
		if guest.state == Guest.S.RIDE:
			moving = false
		walk = move_toward(walk, 1.0 if moving else 0.0, delta * 8.0)
		flip = 1.0 if guest.facing >= 0.0 else -1.0
		lying = guest.state == Guest.S.IN_BED
		mood = _mood_for(guest)
	elif maid != null:
		position = Vector2(Geo.SERVICE_X, -lerpf(maid.prev_floor, maid.floor_f, alpha) * Geo.FLOOR_H - 18.0)
		walk = 0.0
		mood = MonsterArt.Mood.HAPPY if maid.st == StaffMember.St.CLEAN else MonsterArt.Mood.NEUTRAL
		flip = -1.0
	look = Vector2.ZERO
	if not MonsterAtlas.baked and get_parent() != null:
		var d := look_target - (get_parent() as Node2D).to_global(position)
		look = (d / 260.0).limit_length(1.0)
	body.queue_redraw()
	queue_redraw()

func _mood_for(g: Guest) -> int:
	if g.emote == &"heart":
		return MonsterArt.Mood.HAPPY
	if g.emote == &"angry":
		return MonsterArt.Mood.ANGRY
	match g.state:
		Guest.S.IN_BED:
			return MonsterArt.Mood.SLEEPY
		Guest.S.USING_FAC:
			return MonsterArt.Mood.HAPPY
		Guest.S.QUEUE, Guest.S.WAIT_ELEV, Guest.S.QUEUE_FAC:
			return MonsterArt.Mood.ANGRY if g.wait_clock > 12.0 * SpeciesDB.f(g.species, "patience") else MonsterArt.Mood.NEUTRAL
		Guest.S.PAYING, Guest.S.WALK, Guest.S.FLY:
			if g.paid > 0.0 and not g.has_bed:
				return MonsterArt.Mood.HAPPY if g.mood == 1 else (MonsterArt.Mood.ANGRY if g.mood == 2 else MonsterArt.Mood.NEUTRAL)
		Guest.S.BALK_STOP:
			return MonsterArt.Mood.SCARED
	return MonsterArt.Mood.NEUTRAL

func _variant() -> String:
	if species == &"bat":
		return "f%d" % (int(t * 12.0) % 4)
	match mood:
		MonsterArt.Mood.HAPPY:
			return "h"
		MonsterArt.Mood.ANGRY:
			return "a"
		MonsterArt.Mood.SCARED:
			return "s"
	return "b" if blink > 0.5 else "n"

## Desenha o corpo no nó `c` (o filho Body).
func draw_body(c: CanvasItem) -> void:
	var s := 0.55 + 0.45 * ease(pop, -2.2) if pop < 1.0 else 1.0
	var sc := Vector2(1.0 + (1.0 - s) * 0.5, s)
	var bob := absf(sin(t * 9.0)) * 5.0 * walk
	var tilt := sin(t * 9.0) * 0.07 * walk
	if MonsterAtlas.baked:
		c.material = MonsterAtlas.material
		var cs := Vector2(MonsterAtlas.CELL) / MonsterAtlas.SCALE
		if lying:
			var src_z := MonsterAtlas.cell(species, "z")
			c.draw_texture_rect_region(MonsterAtlas.texture, Rect2(Vector2(52, -80) - MonsterAtlas.LYING_ORIGIN / MonsterAtlas.SCALE, cs), src_z)
			return
		if species != &"bat":
			c.draw_colored_polygon(MonsterAtlas.shadow_points(species), Color(0, 0, 0, 0.26))
		var hover := sin(t * 2.2) * 4.0 if species == &"ghost" else 0.0
		c.draw_set_transform(Vector2(0, -bob + hover), tilt * flip, Vector2(flip * sc.x, sc.y))
		c.draw_texture_rect_region(MonsterAtlas.texture, Rect2(-MonsterAtlas.FEET / MonsterAtlas.SCALE, cs), MonsterAtlas.cell(species, _variant()))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		c.material = null
		if lying:
			MonsterArt.draw(c, species, t, 0.0, MonsterArt.Mood.SLEEPY, 0.0, Vector2.ZERO, 1.0, Vector2(52, -80), -PI / 2.0)
		else:
			MonsterArt.draw(c, species, t, walk, mood, blink, look, flip, Vector2.ZERO, 0.0, sc)

## Sobreposições (por cima do corpo): coberta, "zzz", coroa de VIP e balão de emoção.
func _draw() -> void:
	if lying:
		Art.rrect(self, Rect2(-2, -102, 70, 54), blanket.lightened(0.18), 14.0)
		Art.rrect(self, Rect2(-2, -102, 70, 12), blanket.lightened(0.34), 8.0)
		for k in range(3):
			var u := fmod(t * 0.5 + float(k) * 0.33, 1.0)
			draw_string(UIKit.font(700), Vector2(-34.0 + u * 22.0, -112.0 - u * 50.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 + u * 14), Color(1, 1, 1, 1.0 - u))
		return
	var h := MonsterArt.height_of(species)
	if guest != null:
		if guest.vip:
			MonsterArt.draw_crown(self, Vector2(0, -h - 6))
		if guest.inspector:
			MonsterArt.draw_detective(self, Vector2(0, -h + 14))
		if guest.emote != &"":
			MonsterArt.draw_emote(self, guest.emote, t, Vector2(0, -h - 30))
		elif guest.inspector:
			MonsterArt.draw_emote(self, &"bang", t, Vector2(0, -h - 30))
