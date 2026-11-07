extends SceneTree
## Gera os ícones do Android a partir de SVG (sem renderer): legado 192, adaptativo 432 (frente e fundo).
## Uso: tools\dev.bat script res://tools/gen_icons.gd   (depois: tools\dev.bat import)

const OUT := "res://assets/icons/"

# Arte do ícone sem o fundo (viewBox 0 0 128 128): torre, telhado, janelas, fantasminha e lua crescente.
const ART := """
<mask id="bite"><rect width="128" height="128" fill="white"/><circle cx="104" cy="25" r="10" fill="black"/></mask>
<circle cx="99" cy="29" r="12" fill="#ffe9a8" mask="url(#bite)"/>
<rect x="34" y="42" width="60" height="70" rx="6" fill="#6a49b8"/>
<polygon points="28,44 64,12 100,44" fill="#ff8a3d"/>
<rect x="42" y="54" width="14" height="14" rx="3" fill="#ffd36b"/>
<rect x="72" y="54" width="14" height="14" rx="3" fill="#ffd36b"/>
<path d="M50 112 V86 a14 14 0 0 1 28 0 V112 l-5 -5 l-4 5 l-5 -5 l-4 5 l-5 -5 z" fill="#f4fff8"/>
<circle cx="59" cy="90" r="2.6" fill="#1a1033"/>
<circle cx="69" cy="90" r="2.6" fill="#1a1033"/>
<path d="M59.5 96 q4.5 4 9 0" stroke="#1a1033" stroke-width="2" fill="none" stroke-linecap="round"/>
<circle cx="55" cy="95" r="2.4" fill="#ff9ec4" opacity="0.8"/>
<circle cx="73" cy="95" r="2.4" fill="#ff9ec4" opacity="0.8"/>
"""

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var icon_svg := FileAccess.get_file_as_string("res://icon.svg")
	_save(icon_svg, 1.5, "icon_192.png")                       # ícone legado (já com cantos arredondados)
	# adaptativo: a "zona segura" é o círculo central de ~66% (288 de 432 px); a arte fica em ~220x250 no centro
	var fg := '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432"><g transform="translate(56 61) scale(2.5)">%s</g></svg>' % ART
	_save(fg, 1.0, "icon_fg_432.png")
	var bg := '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3f2c78"/><stop offset="1" stop-color="#1a1033"/></linearGradient></defs><rect width="432" height="432" fill="url(#g)"/></svg>'
	_save(bg, 1.0, "icon_bg_432.png")
	# monocromático (Android 13: ícone temático): silhueta branca da torre e do fantasma
	var mono := '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432"><g transform="translate(56 61) scale(2.5)" fill="#ffffff"><polygon points="28,44 64,12 100,44"/><rect x="34" y="46" width="60" height="66" rx="6"/></g></svg>'
	_save(mono, 1.0, "icon_mono_432.png")
	quit(0)

func _save(svg: String, scale: float, file_name: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK or img.is_empty():
		push_error("falha ao rasterizar " + file_name)
		return
	var path := ProjectSettings.globalize_path(OUT + file_name)
	var e2 := img.save_png(path)
	print("%s  %dx%d  (%s)" % [file_name, img.get_width(), img.get_height(), "ok" if e2 == OK else "erro ao salvar"])
