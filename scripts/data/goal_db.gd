class_name GoalDB
extends RefCounted
## Cadeia de metas (a ordem importa: as primeiras funcionam como tutorial).
## kind: taps | served | upgrades | rep | level | build_type | staff | suite_level | shafts | rush | floors
## Texto: "goal.<id>" em data/i18n.json. Recompensa: ver Hotel.goal_reward().
## hint: pista visual do tutorial (bubble | build | staff | hotel | plot | rush | "")

const GOALS: Array[Dictionary] = [
	{"id": "tap_coin", "kind": "taps", "n": 1, "hint": "bubble"},
	{"id": "build_suite2", "kind": "build_type", "t": "suite", "n": 2, "hint": "plot"},
	{"id": "serve_5", "kind": "served", "n": 5, "hint": ""},
	{"id": "upgrade_1", "kind": "upgrades", "n": 1, "hint": "room"},
	{"id": "level_2", "kind": "level", "n": 2, "hint": ""},
	{"id": "build_bar", "kind": "build_type", "t": "bar", "n": 1, "hint": "build"},
	{"id": "serve_15", "kind": "served", "n": 15, "hint": ""},
	{"id": "build_suite3", "kind": "build_type", "t": "suite", "n": 3, "hint": "plot"},
	{"id": "level_3", "kind": "level", "n": 3, "hint": ""},
	{"id": "build_housekeeping", "kind": "build_type", "t": "housekeeping", "n": 1, "hint": "build"},
	{"id": "hire_maid", "kind": "staff", "t": "maid", "n": 1, "hint": "staff"},
	{"id": "rep_35", "kind": "rep", "v": 3.5, "hint": ""},
	{"id": "build_spa", "kind": "build_type", "t": "spa", "n": 1, "hint": "build"},
	{"id": "hire_receptionist", "kind": "staff", "t": "receptionist", "n": 1, "hint": "staff"},
	{"id": "serve_40", "kind": "served", "n": 40, "hint": ""},
	{"id": "floors_6", "kind": "floors", "n": 6, "hint": ""},
	{"id": "use_rush", "kind": "rush", "n": 1, "hint": "hotel"},
	{"id": "level_5", "kind": "level", "n": 5, "hint": ""},
	{"id": "build_buffet", "kind": "build_type", "t": "buffet", "n": 1, "hint": "build"},
	{"id": "hire_cashier", "kind": "staff", "t": "cashier", "n": 1, "hint": "staff"},
	{"id": "rep_40", "kind": "rep", "v": 4.0, "hint": ""},
	{"id": "suite_l3", "kind": "suite_level", "n": 3, "hint": ""},
	{"id": "build_shaft2", "kind": "shafts", "n": 2, "hint": "hotel"},
	{"id": "build_boutique", "kind": "build_type", "t": "boutique", "n": 1, "hint": "build"},
	{"id": "floors_10", "kind": "floors", "n": 10, "hint": ""},
	{"id": "serve_150", "kind": "served", "n": 150, "hint": ""},
	{"id": "build_gym", "kind": "build_type", "t": "gym", "n": 1, "hint": "build"},
	{"id": "build_marketing", "kind": "build_type", "t": "marketing", "n": 1, "hint": "build"},
	{"id": "rep_45", "kind": "rep", "v": 4.5, "hint": ""},
	{"id": "suite_l5", "kind": "suite_level", "n": 5, "hint": ""},
	{"id": "floors_15", "kind": "floors", "n": 15, "hint": ""},
	{"id": "serve_600", "kind": "served", "n": 600, "hint": ""},
	{"id": "floors_20", "kind": "floors", "n": 20, "hint": ""},
	{"id": "rep_48", "kind": "rep", "v": 4.8, "hint": ""},
	{"id": "serve_2000", "kind": "served", "n": 2000, "hint": ""},
]

static func count() -> int:
	return GOALS.size()

static func get_goal(i: int) -> Dictionary:
	return GOALS[clampi(i, 0, GOALS.size() - 1)]
