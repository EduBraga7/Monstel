class_name RoomDB
extends RefCounted
## Tipos de andar. Níveis são 1-based; cada array tem um valor por nível.
## Textos: "room.<tipo>" e "room.<tipo>.desc" em data/i18n.json.

const BUILDABLE: Array[StringName] = [
	&"suite", &"bar", &"buffet", &"spa", &"boutique", &"gym", &"housekeeping", &"marketing",
]

const DATA := {
	&"lobby": {"kind": &"lobby", "unlock": 1, "cost_mult": 0.0, "max_level": 1},
	&"suite": {
		"kind": &"suite", "unlock": 1, "cost_mult": 1.0, "max_level": 5,
		"beds": [2, 2, 3, 3, 4],
		"comfort": [1, 2, 3, 4, 5],
		"rate": [16.0, 28.0, 48.0, 80.0, 130.0],
		"upgrade": [110.0, 700.0, 4000.0, 24000.0],
	},
	&"bar": {
		"kind": &"facility", "unlock": 2, "cost_mult": 1.3, "max_level": 5, "fav_of": &"vampire",
		"seats": [1, 2, 2, 3, 4],
		"service": [6.0, 5.0, 4.5, 4.0, 3.5],
		"fee": [8.0, 15.0, 28.0, 50.0, 85.0],
		"upgrade": [200.0, 1100.0, 5500.0, 28000.0],
	},
	&"buffet": {
		"kind": &"facility", "unlock": 4, "cost_mult": 1.5, "max_level": 5, "fav_of": &"zombie",
		"seats": [2, 3, 4, 5, 6],
		"service": [8.0, 7.0, 6.0, 5.0, 4.0],
		"fee": [10.0, 19.0, 35.0, 62.0, 105.0],
		"upgrade": [260.0, 1400.0, 7000.0, 34000.0],
	},
	&"spa": {
		"kind": &"facility", "unlock": 3, "cost_mult": 1.6, "max_level": 5, "fav_of": &"mummy",
		"seats": [1, 2, 2, 3, 3],
		"service": [10.0, 9.0, 8.0, 7.0, 6.0],
		"fee": [14.0, 28.0, 52.0, 95.0, 160.0],
		"upgrade": [300.0, 1700.0, 8000.0, 40000.0],
	},
	&"boutique": {
		"kind": &"facility", "unlock": 5, "cost_mult": 1.8, "max_level": 5, "fav_of": &"witch",
		"seats": [2, 3, 3, 4, 5],
		"service": [5.0, 4.5, 4.0, 3.5, 3.0],
		"fee": [12.0, 23.0, 42.0, 76.0, 128.0],
		"upgrade": [340.0, 2000.0, 9500.0, 46000.0],
	},
	&"gym": {
		"kind": &"facility", "unlock": 6, "cost_mult": 1.7, "max_level": 5, "fav_of": &"werewolf",
		"seats": [2, 2, 3, 4, 5],
		"service": [9.0, 8.0, 7.0, 6.0, 5.0],
		"fee": [11.0, 21.0, 39.0, 70.0, 118.0],
		"upgrade": [320.0, 1800.0, 8800.0, 43000.0],
	},
	&"housekeeping": {
		"kind": &"support", "unlock": 3, "cost_mult": 1.2, "max_level": 5,
		"maids": [1, 2, 3, 4, 5],
		"upgrade": [250.0, 1500.0, 7500.0, 36000.0],
	},
	&"marketing": {
		"kind": &"support", "unlock": 5, "cost_mult": 2.0, "max_level": 5,
		"arrival": [1.10, 1.20, 1.32, 1.45, 1.60],
		"upgrade": [600.0, 3500.0, 16000.0, 70000.0],
	},
}

# Elevador (upgrade do hotel, não é um andar).
const ELEVATOR := {
	"max_level": 5,
	"speed": [1.4, 2.0, 2.8, 3.6, 4.5],      # andares por segundo
	"cap": [3, 4, 5, 6, 8],
	"door": [1.6, 1.4, 1.2, 1.0, 0.8],       # segundos por parada
	"upgrade": [180.0, 900.0, 4500.0, 22000.0],
}

# Poços de elevador adicionais (o 1º já vem construído).
const SHAFTS := {
	"max": 3,
	"unlock": [5, 9],            # nível do hotel para construir o 2º e o 3º poço
	"cost": [1500.0, 12000.0],
}

static func kind(t: StringName) -> StringName:
	return DATA[t]["kind"]

static func unlock_level(t: StringName) -> int:
	return int(DATA[t]["unlock"])

static func max_level(t: StringName) -> int:
	return int(DATA[t]["max_level"])

static func has_key(t: StringName, key: String) -> bool:
	return DATA[t].has(key)

## Valor da tabela `key` no nível `level` (1-based, limitado ao último valor).
static func at(t: StringName, key: String, level: int) -> float:
	var arr: Array = DATA[t][key]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])

## Custo para ir de `level` para `level + 1`; -1 se já está no máximo.
static func upgrade_cost(t: StringName, level: int) -> float:
	if level >= max_level(t):
		return -1.0
	var arr: Array = DATA[t]["upgrade"]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])

## Custo de construir um andar do tipo `t` quando já existem `built_count` andares construídos.
static func build_cost(t: StringName, built_count: int) -> float:
	var early := mini(built_count, Balance.FLOOR_COST_KNEE)
	var late := maxi(0, built_count - Balance.FLOOR_COST_KNEE)
	return roundf(Balance.FLOOR_COST_BASE * pow(Balance.FLOOR_COST_GROWTH, float(early)) \
		* pow(Balance.FLOOR_COST_GROWTH_LATE, float(late)) * float(DATA[t]["cost_mult"]))

static func elev(key: String, level: int) -> float:
	var arr: Array = ELEVATOR[key]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])

static func elev_upgrade_cost(level: int) -> float:
	if level >= int(ELEVATOR["max_level"]):
		return -1.0
	var arr: Array = ELEVATOR["upgrade"]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])
