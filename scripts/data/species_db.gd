class_name SpeciesDB
extends RefCounted
## Espécies de hóspedes. Textos (nome, frase) ficam em data/i18n.json sob "species.<id>".
##  min_comfort: conforto mínimo da suíte que a espécie aceita sem reclamar
##  budget:      multiplicador da tarifa que ela paga
##  patience:    multiplicador da tolerância a filas
##  speed:       multiplicador da velocidade de caminhada
##  stay:        multiplicador da duração da estadia
##  mess:        multiplicador do tempo de limpeza do quarto
##  tip:         multiplicador da gorjeta
##  fav:         facilidade preferida ("" = nenhuma)
##  needs:       tipo de andar que precisa existir para a espécie aparecer ("" = nenhum)
##  night/day:   multiplicador da tarifa se o check-in foi à noite/de dia

const ORDER: Array[StringName] = [&"ghost", &"zombie", &"vampire", &"mummy", &"witch", &"werewolf"]

const DATA := {
	&"ghost": {
		"min_comfort": 1, "budget": 0.7, "patience": 1.2, "speed": 1.0, "stay": 1.0, "mess": 0.3,
		"tip": 1.0, "fav": &"", "flies": true, "weight": 30.0, "needs": &"", "unlock": 1,
		"night": 1.0, "day": 1.0,
	},
	&"zombie": {
		"min_comfort": 1, "budget": 0.9, "patience": 1.6, "speed": 0.55, "stay": 1.2, "mess": 1.2,
		"tip": 0.8, "fav": &"buffet", "flies": false, "weight": 30.0, "needs": &"", "unlock": 1,
		"night": 1.0, "day": 1.0,
	},
	&"vampire": {
		"min_comfort": 2, "budget": 1.3, "patience": 0.9, "speed": 1.0, "stay": 1.0, "mess": 0.6,
		"tip": 1.1, "fav": &"bar", "flies": false, "weight": 22.0, "needs": &"bar", "unlock": 2,
		"night": 1.3, "day": 0.8,
	},
	&"mummy": {
		"min_comfort": 2, "budget": 1.1, "patience": 1.0, "speed": 0.8, "stay": 1.1, "mess": 0.8,
		"tip": 1.0, "fav": &"spa", "flies": false, "weight": 20.0, "needs": &"spa", "unlock": 3,
		"night": 1.0, "day": 1.0,
	},
	&"witch": {
		"min_comfort": 3, "budget": 1.5, "patience": 0.8, "speed": 1.0, "stay": 0.9, "mess": 0.7,
		"tip": 1.8, "fav": &"boutique", "flies": false, "weight": 16.0, "needs": &"boutique", "unlock": 5,
		"night": 1.0, "day": 1.0,
	},
	&"werewolf": {
		"min_comfort": 2, "budget": 1.2, "patience": 0.9, "speed": 1.3, "stay": 1.0, "mess": 2.0,
		"tip": 1.0, "fav": &"gym", "flies": false, "weight": 16.0, "needs": &"gym", "unlock": 6,
		"night": 1.0, "day": 1.0,
	},
}

static func f(id: StringName, key: String) -> float:
	return float(DATA[id][key])

static func i(id: StringName, key: String) -> int:
	return int(DATA[id][key])

static func s(id: StringName, key: String) -> StringName:
	return DATA[id][key]

static func b(id: StringName, key: String) -> bool:
	return bool(DATA[id][key])
