class_name RoomState
extends RefCounted
## Estado de um andar do hotel (saguão, suíte, facilidade ou apoio).

class Bed:
	var occupant: Guest = null
	var reserved: Guest = null
	var dirty := false
	var claimed := false            # uma camareira já está a caminho
	var clean_t := 0.0
	var mess := 1.0
	func is_free() -> bool:
		return occupant == null and reserved == null and not dirty

class Station:                      # balcão do saguão ou assento de facilidade
	var occupant: Guest = null
	var reserved: Guest = null
	var timer := 0.0
	func is_free() -> bool:
		return occupant == null and reserved == null

var type: StringName = &"suite"
var level := 1
var floor_idx := 0
var pending := 0.0                  # moedas esperando coleta
var pending_n := 0
var total_earned := 0.0
var beds: Array[Bed] = []
var stations: Array[Station] = []
var queue: Array[Guest] = []        # fila da facilidade

func refresh_capacity() -> void:
	match RoomDB.kind(type):
		&"suite":
			var n := int(RoomDB.at(type, "beds", level))
			while beds.size() < n:
				beds.append(Bed.new())
		&"facility":
			var n2 := int(RoomDB.at(type, "seats", level))
			while stations.size() < n2:
				stations.append(Station.new())
