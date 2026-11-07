class_name Guest
extends RefCounted
## Dados de um hóspede. A lógica fica em GuestAI.

enum S { WALK, QUEUE, CHECKIN, WAIT_ROOM, WAIT_ELEV, RIDE, FLY, IN_BED, QUEUE_FAC, USING_FAC, PAYING, BALK_STOP, DEAD }

var id := 0
var species: StringName = &"ghost"
var vip := false
var inspector := false
var name_seed := 0
var mood := 0                       # 0 neutro, 1 feliz, 2 irritado
var emote: StringName = &""         # ícone sobre a cabeça: heart, angry, zzz, star
var emote_t := 0.0

# movimento
var state: int = S.WALK
var after: int = S.QUEUE            # estado ao terminar a caminhada
var state_t := 0.0                  # tempo no estado atual
var wait_clock := 0.0               # tempo esperando (fila/elevador) para a satisfação
var x := 0.0
var prev_x := 0.0
var floor_f := 0.0                  # andar atual (float durante a viagem)
var prev_floor := 0.0
var tx := 0.0
var speed := 150.0
var facing := -1.0

# rota
var dest_floor := 0
var dir := 0                        # -1 desce, +1 sobe (usado na fila do elevador)
var goal_x := 0.0
var goal_state: int = S.QUEUE
var in_car := false
var car_idx := 0                    # em qual cabine está/esteve

# estadia
var needs_bed := false              # ocupa uma vaga "no pipeline" até ganhar cama
var has_bed := false                # o relógio da estadia corre
var bed_floor := -1
var bed_idx := -1
var stay_total := 40.0
var stay_left := 40.0
var room_rate := 0.0
var fac_type: StringName = &""
var fac_time := 0.0
var fac_floor := -1
var fac_seat := -1
var fac_done := false
var fac_visits := 0
var paid := 0.0
var stuck_flag := false
var greeted := false

# satisfação
var sat_delta := 0.0
var factors: Dictionary = {}

func add_factor(key: StringName, delta: float) -> void:
	sat_delta += delta
	factors[key] = float(factors.get(key, 0.0)) + delta
