extends Node
## Persistência (autoload "Save"): hotel + configurações num JSON versionado.
## Escrita segura: grava num .tmp, guarda o arquivo anterior como .bak e só então troca.

const VERSION := 1

var path := "user://monstel_save.json"            # variáveis (não const) para os testes redirecionarem o arquivo
var bak_path := "user://monstel_save.bak.json"

var settings := {
	"lang": "",
	"sfx": true,
	"music": true,
	"haptics": true,
	"hotel_name": "",
	"daily_day": -1,
	"daily_streak": 0,
}
var hotel_data: Dictionary = {}
var saved_at := 0
var test_mode := false             # QA/capturas: não grava nada no disco

func _ready() -> void:
	load_all()
	apply_settings()

func has_save() -> bool:
	return not hotel_data.is_empty()

func load_all() -> void:
	hotel_data = {}
	for p in [path, bak_path]:
		var d := _read(p)
		if d.is_empty() or int(d.get("version", 0)) < 1:
			continue
		hotel_data = d.get("hotel", {})
		saved_at = int(d.get("saved_at", 0))
		var s: Dictionary = d.get("settings", {})
		for k in s:
			if settings.has(k):
				settings[k] = s[k]
		return

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var js := JSON.new()                                  # (parse_string registraria um ERROR no log com arquivo corrompido)
	if js.parse(f.get_as_text()) != OK:
		return {}
	return js.data if js.data is Dictionary else {}

func save_hotel(h: Hotel) -> bool:
	hotel_data = h.to_dict()
	saved_at = int(Time.get_unix_time_from_system())
	return _write()

func save_settings() -> void:
	_write()

func _write() -> bool:
	if test_mode:
		return true
	var d := {"version": VERSION, "saved_at": saved_at, "settings": settings, "hotel": hotel_data}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, bak_path)
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK

func delete_save() -> void:
	hotel_data = {}
	saved_at = 0
	settings["hotel_name"] = ""
	for p in [path, bak_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	save_settings()

func apply_settings() -> void:
	var l := str(settings.get("lang", ""))
	if l != "":
		Loc.set_language(l)
	Sfx.set_sfx_enabled(bool(settings.get("sfx", true)))
	Sfx.set_music_enabled(bool(settings.get("music", true)))
	Haptics.enabled = bool(settings.get("haptics", true))

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	apply_settings()
	save_settings()

## Nome do hotel (com padrão no idioma atual).
func hotel_name() -> String:
	var n := str(settings.get("hotel_name", ""))
	return n if n != "" else Loc.t("name.default")

## Dia (UTC) como número, para a recompensa diária.
func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)
