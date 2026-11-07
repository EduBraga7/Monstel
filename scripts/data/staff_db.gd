class_name StaffDB
extends RefCounted
## Funções da equipe. "hire" lista o custo de contratar a 1ª, 2ª, ... unidade.
## "train" é o custo de subir o nível de treino (vale para todas as unidades do tipo).
## Textos: "staff.<tipo>" e "staff.<tipo>.desc".

const ORDER: Array[StringName] = [&"receptionist", &"maid", &"bellhop", &"cashier"]

const DATA := {
	&"receptionist": {
		"cap": 2, "unlock": 2, "wage": 14.0,
		"hire": [200.0, 1400.0],
		"train": [400.0, 2200.0, 10000.0, 45000.0],
		"speed": [1.0, 1.2, 1.45, 1.75, 2.1],      # velocidade do check-in
	},
	&"maid": {
		"cap": 5, "unlock": 3, "wage": 10.0,       # o teto real é o nível da Governança
		"hire": [150.0, 450.0, 1100.0, 2600.0, 6000.0],
		"train": [300.0, 1800.0, 8000.0, 38000.0],
		"speed": [1.0, 1.3, 1.7, 2.2, 2.8],        # velocidade da limpeza
	},
	&"bellhop": {
		"cap": 2, "unlock": 4, "wage": 10.0,
		"hire": [300.0, 1600.0],
		"train": [350.0, 2000.0, 9000.0, 40000.0],
		"door": [0.85, 0.75, 0.65, 0.55, 0.45],    # multiplica o tempo de porta do elevador
	},
	&"cashier": {
		"cap": 1, "unlock": 3, "wage": 16.0,
		"hire": [600.0],
		"train": [700.0, 3500.0, 14000.0, 50000.0],
		"interval": [40.0, 28.0, 20.0, 14.0, 10.0], # segundos entre coletas automáticas
	},
}
const MAX_LEVEL := 5

static func cap(t: StringName) -> int:
	return int(DATA[t]["cap"])

static func unlock_level(t: StringName) -> int:
	return int(DATA[t]["unlock"])

static func wage(t: StringName) -> float:
	return float(DATA[t]["wage"])

## Custo de contratar a próxima unidade, dado quantas já existem; -1 se já está no teto.
static func hire_cost(t: StringName, owned: int) -> float:
	var arr: Array = DATA[t]["hire"]
	if owned >= arr.size():
		return -1.0
	return float(arr[owned])

## Custo de treinar do nível `level` para `level + 1`; -1 se já está no máximo.
static func train_cost(t: StringName, level: int) -> float:
	if level >= MAX_LEVEL:
		return -1.0
	var arr: Array = DATA[t]["train"]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])

static func at(t: StringName, key: String, level: int) -> float:
	var arr: Array = DATA[t][key]
	return float(arr[clampi(level - 1, 0, arr.size() - 1)])
