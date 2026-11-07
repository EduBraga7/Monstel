class_name Elevator
extends RefCounted
## Uma cabine de elevador. Algoritmo estilo SCAN: segue na direção atual enquanto houver pedidos.
## As filas de espera são compartilhadas entre as cabines (Hotel.elev_queue); quem chega primeiro leva.

enum St { IDLE, MOVING, DOORS }

var idx := 0                        # índice do poço (0 = o da esquerda)
var y := 0.0                        # andar (float)
var prev_y := 0.0
var dir := 0
var st: int = St.IDLE
var target := 0
var door_t := 0.0
var door_open := false
var idle_t := 0.0
var riders: Array[Guest] = []
var rides := 0

func shaft_x() -> float:
	return Geo.shaft_x(idx)

func step(h: Hotel, dt: float) -> void:
	prev_y = y
	match st:
		St.IDLE:
			_idle(h, dt)
		St.MOVING:
			_move(h, dt)
		St.DOORS:
			door_t -= dt
			if door_t <= 0.0:
				door_open = false
				_choose_next(h)
	for g in riders:                    # quem está dentro acompanha a cabine
		g.floor_f = y
		g.x = shaft_x()

func _has_request_at(h: Hotel, f: int) -> bool:
	if f >= 0 and f < h.elev_queue.size():
		var q: Array = h.elev_queue[f]
		if not q.is_empty():
			return true
	for g in riders:
		if g.dest_floor == f:
			return true
	return false

## Outra cabine já está indo (e mais perto) atender este andar?
func _claimed_by_other(h: Hotel, f: int) -> bool:
	for e: Elevator in h.elevators:
		if e == self:
			continue
		if e.st == St.MOVING and e.target == f and absf(e.y - float(f)) <= absf(y - float(f)):
			return true
		if e.st == St.DOORS and roundi(e.y) == f:
			return true
	return false

## Próximo andar a atender, preferindo a direção `pdir`; -1 se não há pedidos.
func _pick(h: Hotel, cur: int, pdir: int) -> int:
	var best_up := 1000000
	var best_dn := -1000000
	for f in range(h.floors.size()):
		if f == cur:
			continue
		if not _has_request_at(h, f):
			continue
		if not _riders_want(f) and _claimed_by_other(h, f):
			continue
		if f > cur:
			best_up = mini(best_up, f)
		else:
			best_dn = maxi(best_dn, f)
	var has_up := best_up != 1000000
	var has_dn := best_dn != -1000000
	if pdir >= 0:
		if has_up:
			return best_up
		if has_dn:
			return best_dn
	else:
		if has_dn:
			return best_dn
		if has_up:
			return best_up
	return -1

func _riders_want(f: int) -> bool:
	for g in riders:
		if g.dest_floor == f:
			return true
	return false

func _idle(h: Hotel, dt: float) -> void:
	var cur := roundi(y)
	if _has_request_at(h, cur) and not _claimed_by_other(h, cur):
		_open(h, cur)
		return
	var t := _pick(h, cur, dir)
	if t != -1:
		target = t
		dir = signi(t - cur)
		st = St.MOVING
		idle_t = 0.0
		return
	idle_t += dt
	if idle_t > 4.0:                    # estaciona: cada cabine num ponto diferente da torre
		var park := roundi(float(h.floors.size() - 1) * float(idx) / float(maxi(1, h.elevators.size())))
		if cur != park:
			target = park
			dir = signi(park - cur)
			st = St.MOVING

func _move(h: Hotel, dt: float) -> void:
	var stp := RoomDB.elev("speed", h.elevator_level) * dt
	var remaining := absf(float(target) - y)
	if remaining <= stp:
		y = float(target)
		_open(h, target)
		return
	var old := y
	y += float(dir) * stp
	# parada oportunista ao cruzar um andar com pedido compatível
	var fc := -1
	if dir > 0:
		if floori(y) > floori(old):
			fc = floori(y)
	elif dir < 0:
		if ceili(y) < ceili(old):
			fc = ceili(y)
	if fc != -1 and fc != target and _should_stop(h, fc):
		y = float(fc)
		_open(h, fc)

func _should_stop(h: Hotel, f: int) -> bool:
	if _riders_want(f):
		return true
	if riders.size() >= int(RoomDB.elev("cap", h.elevator_level)):
		return false
	var q: Array = h.elev_queue[f]
	for g2 in q:
		if (g2 as Guest).dir == dir:
			return true
	return false

func _open(h: Hotel, f: int) -> void:
	st = St.DOORS
	door_open = true
	y = float(f)
	door_t = RoomDB.elev("door", h.elevator_level) * h.bellhop_door_mult()
	# desembarque
	var i := riders.size() - 1
	while i >= 0:
		var g: Guest = riders[i]
		if g.dest_floor == f:
			riders.remove_at(i)
			GuestAI.on_exit_elevator(h, g, f, shaft_x())
			door_t += 0.15
		i -= 1
	# embarque
	var q: Array = h.elev_queue[f]
	if q.is_empty():
		return
	var cap := int(RoomDB.elev("cap", h.elevator_level))
	if riders.is_empty():
		dir = (q[0] as Guest).dir
	var j := 0
	while j < q.size() and riders.size() < cap:
		var g2: Guest = q[j]
		if g2.dir == dir:
			q.remove_at(j)
			g2.state = Guest.S.RIDE
			g2.in_car = true
			g2.car_idx = idx
			g2.x = shaft_x()
			GuestAI.on_board(h, g2)
			riders.append(g2)
			rides += 1
			door_t += 0.15
		else:
			j += 1

func _choose_next(h: Hotel) -> void:
	var cur := roundi(y)
	var t := _pick(h, cur, dir)
	if t == -1:
		st = St.IDLE
		idle_t = 0.0
		if riders.is_empty():
			dir = 0
	else:
		target = t
		dir = signi(t - cur)
		st = St.MOVING
