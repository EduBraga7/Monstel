class_name MonsterAtlas
extends RefCounted
## Pré-renderiza (uma vez, no boot) as poses de cada espécie num atlas com 2x de resolução.
## Os monstros passam a custar 1 desenho de textura por quadro (em vez de ~35 polígonos recalculados)
## e as bordas ficam suavizadas por supersampling, já que o renderer Compatibility não tem MSAA 2D.

const SCALE := 2.0
const CELL := Vector2i(280, 300)                 # tamanho da célula em px do atlas
const FEET := Vector2(140.0, 262.0)              # onde ficam os pés dentro da célula
const LYING_ORIGIN := Vector2(205.0, 150.0)      # origem da pose deitada (rotacionada) na célula
const COLS := 8
const SPECIES: Array[StringName] = [&"ghost", &"zombie", &"vampire", &"mummy", &"witch", &"werewolf"]
# variante -> [humor, piscando, rotação]
const VARIANTS := {
	"n": [MonsterArt.Mood.NEUTRAL, 0.0, 0.0],
	"b": [MonsterArt.Mood.NEUTRAL, 1.0, 0.0],
	"h": [MonsterArt.Mood.HAPPY, 0.0, 0.0],
	"a": [MonsterArt.Mood.ANGRY, 0.0, 0.0],
	"s": [MonsterArt.Mood.SCARED, 0.0, 0.0],
	"z": [MonsterArt.Mood.SLEEPY, 0.0, -PI / 2.0],
}
const BAT_T := [-0.112, -0.024, 0.024, 0.112]    # fases do bater de asas (sin(t*14) = -1 .. 1)

static var baked := false
static var texture: Texture2D = null
static var material: CanvasItemMaterial = null
static var _cells: Dictionary = {}
static var _entries: Array = []
static var _shadow: Dictionary = {}

static func release() -> void:
	texture = null
	material = null
	baked = false
	_cells.clear()
	_entries.clear()
	_shadow.clear()

class Painter extends Node2D:
	func _draw() -> void:
		for i in range(MonsterAtlas._entries.size()):
			var e: Dictionary = MonsterAtlas._entries[i]
			var org := Vector2(float(i % MonsterAtlas.COLS) * MonsterAtlas.CELL.x, float(i / MonsterAtlas.COLS) * MonsterAtlas.CELL.y)
			var rot: float = e["rot"]
			var pos := org + (MonsterAtlas.LYING_ORIGIN if rot != 0.0 else MonsterAtlas.FEET)
			MonsterArt.draw(self, e["species"], float(e["t"]), 0.0, int(e["mood"]), float(e["blink"]), Vector2(0.3, 0.0), 1.0, pos, rot, Vector2(MonsterAtlas.SCALE, MonsterAtlas.SCALE), false)

static func _list() -> void:
	_entries.clear()
	_cells.clear()
	for sp in SPECIES:
		for v in VARIANTS.keys():
			var d: Array = VARIANTS[v]
			_entries.append({"species": sp, "variant": v, "mood": d[0], "blink": d[1], "rot": d[2], "t": 0.9})
	for i in range(4):
		_entries.append({"species": &"bat", "variant": "f%d" % i, "mood": MonsterArt.Mood.NEUTRAL, "blink": 0.0, "rot": 0.0, "t": BAT_T[i]})
	for i in range(_entries.size()):
		var e: Dictionary = _entries[i]
		var org := Vector2(float(i % COLS) * CELL.x, float(i / COLS) * CELL.y)
		_cells["%s/%s" % [e["species"], e["variant"]]] = Rect2(org, Vector2(CELL))

## Gera o atlas. Em headless (sem renderer) não faz nada e os monstros usam o desenho procedural.
static func bake(host: Node) -> void:
	if baked or DisplayServer.get_name() == "headless":
		return
	_list()
	var rows := int(ceil(float(_entries.size()) / float(COLS)))
	var sv := SubViewport.new()
	sv.size = Vector2i(COLS * CELL.x, rows * CELL.y)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Painter.new()
	sv.add_child(painter)
	host.add_child(sv)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	sv.queue_free()
	if img == null or img.is_empty():
		return
	img.generate_mipmaps()
	texture = ImageTexture.create_from_image(img)
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	baked = true

static func cell(species: StringName, variant: String) -> Rect2:
	var key := "%s/%s" % [species, variant]
	if _cells.has(key):
		return _cells[key]
	return _cells.get("%s/n" % species, Rect2())

static func shadow_points(species: StringName) -> PackedVector2Array:
	var w := 20.0 if species == &"ghost" else (14.0 if species == &"bat" else 26.0)
	var key := int(w)
	if not _shadow.has(key):
		_shadow[key] = Art.ellipse(0, 0, w, w * 0.22, 20)
	return _shadow[key]
