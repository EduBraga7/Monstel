class_name SkyLayer
extends CanvasLayer
## Céu em tela cheia atrás do mundo; as cores seguem a hora do dia do hotel.

var rect: ColorRect
var mat: ShaderMaterial
var _t := 0.0

# (hora, cor do topo, cor do horizonte, noite 0..1)
const KEYS := [
	[0.0, Color("070316"), Color("221046"), 1.0],
	[4.5, Color("0a0420"), Color("2b1354"), 1.0],
	[6.5, Color("3a2d86"), Color("ff9a6b"), 0.45],
	[9.0, Color("6b84e6"), Color("d8c8f7"), 0.0],
	[16.0, Color("6a7fdc"), Color("d6c2f2"), 0.0],
	[18.5, Color("4a2b8f"), Color("ff7a59"), 0.45],
	[20.5, Color("14072f"), Color("43206b"), 0.95],
	[24.0, Color("070316"), Color("221046"), 1.0],
]

func _init() -> void:
	layer = -10
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/sky.gdshader")
	rect.material = mat
	add_child(rect)

func _process(delta: float) -> void:
	_t += delta
	mat.set_shader_parameter("time_s", _t)
	var vs := get_viewport().get_visible_rect().size
	mat.set_shader_parameter("aspect", vs.x / maxf(1.0, vs.y))

func set_hour(h: float) -> void:
	var i := 0
	while i < KEYS.size() - 2 and h >= float(KEYS[i + 1][0]):
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var u := clampf((h - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	mat.set_shader_parameter("top_color", (a[1] as Color).lerp(b[1], u))
	mat.set_shader_parameter("bottom_color", (a[2] as Color).lerp(b[2], u))
	mat.set_shader_parameter("night", lerpf(float(a[3]), float(b[3]), u))

func set_scroll(y: float) -> void:
	mat.set_shader_parameter("scroll", y)

func set_moon(pos: Vector2) -> void:
	mat.set_shader_parameter("moon_pos", pos)
