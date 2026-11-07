extends Node
## Textos da interface (autoload "Loc"). Dados em data/i18n.json: {"pt": {chave: texto}, "en": {...}}.
## Uso: Loc.t("menu.play") ou Loc.t("hud.day", [3]) (formatação estilo printf).

signal language_changed

const LANGS: Array[String] = ["pt", "en"]

var lang := "pt"
var _tables: Dictionary = {}
var _reviews: Dictionary = {}
var _missing: Dictionary = {}

func _ready() -> void:
	_tables = _load_json("res://data/i18n.json")
	_reviews = _load_json("res://data/reviews.json")
	lang = "pt" if OS.get_locale_language() == "pt" else "en"

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Arquivo de textos ausente: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_warning("JSON inválido: " + path)
	return {}

func set_language(l: String) -> void:
	if LANGS.has(l) and l != lang:
		lang = l
		language_changed.emit()

func has_key(key: String) -> bool:
	var table: Dictionary = _tables.get(lang, {})
	return table.has(key)

func t(key: String, args: Array = []) -> String:
	var table: Dictionary = _tables.get(lang, {})
	var s: String = str(table.get(key, ""))
	if s == "":
		var en: Dictionary = _tables.get("en", {})
		s = str(en.get(key, ""))
	if s == "":
		if not _missing.has(key):
			_missing[key] = true
			push_warning("i18n faltando: " + key)
		return key
	if args.is_empty():
		return s
	return s % args

## Texto de uma avaliação: escolhido de data/reviews.json por espécie, fator, tom e semente.
func review_text(rv: Dictionary) -> String:
	var table: Dictionary = _reviews.get(lang, {})
	var species := str(rv.get("species", "ghost"))
	var factor := str(rv.get("factor", "generic"))
	var stars := int(rv.get("stars", 3))
	var tone := "good" if stars >= 4 else ("bad" if stars <= 2 else "mid")
	var seed_v := absi(int(rv.get("seed", 0)))
	# o fator que causou a nota ganha prioridade: pool do fator (tom da nota) -> espécie -> genérico
	var factor_tone := tone
	if factor != "generic" and bool(rv.get("positive", true)) == false and tone != "bad":
		factor_tone = "bad"
	var pf: Array = []
	var by_factor: Dictionary = table.get("factor", {})
	if by_factor.has(factor):
		var fp: Dictionary = by_factor[factor]
		if fp.has(factor_tone):
			pf = fp[factor_tone]
	var ps: Array = []
	var by_species: Dictionary = table.get("species", {})
	if by_species.has(species):
		var sp: Dictionary = by_species[species]
		if sp.has(tone):
			ps = sp[tone]
	var pg: Array = []
	var generic: Dictionary = table.get("generic", {})
	if generic.has(tone):
		pg = generic[tone]
	var roll := seed_v % 10
	var pool: Array = pf if (roll < 5 and not pf.is_empty()) else (ps if (roll < 8 and not ps.is_empty()) else pg)
	if pool.is_empty():
		pool = pf if not pf.is_empty() else (ps if not ps.is_empty() else pg)
	if pool.is_empty():
		return ""
	return str(pool[(seed_v / 10) % pool.size()])

## Nome do hóspede, montado de listas por espécie.
func guest_name(species: String, name_seed: int) -> String:
	var table: Dictionary = _reviews.get(lang, {})
	var names: Dictionary = table.get("names", {})
	var list: Array = names.get(species, [])
	if list.is_empty():
		return species.capitalize()
	return str(list[name_seed % list.size()])
