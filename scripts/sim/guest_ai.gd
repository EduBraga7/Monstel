class_name GuestAI
extends RefCounted
## Máquina de estados dos hóspedes (funções estáticas sobre Hotel/Guest).
## Fluxo: fila da recepção -> balcão -> cama (elevador) -> estadia (+ visita a uma facilidade)
## -> check-out -> pagamento -> rua.

static func make_guest(h: Hotel, species: StringName) -> Guest:
	var g := Guest.new()
	g.id = h.next_guest_id
	h.next_guest_id += 1
	g.species = species
	g.name_seed = h.rng.randi()
	g.x = Geo.STREET_X + 70.0 + h.rng.randf() * 60.0
	g.prev_x = g.x
	g.stay_total = Balance.STAY_BASE * SpeciesDB.f(species, "stay") * h.rng.randf_range(0.8, 1.25)
	g.stay_left = g.stay_total
	return g

# --- movimento ---------------------------------------------------------------

static func walk(g: Guest, tx: float, after: int) -> void:
	g.tx = tx
	g.after = after
	g.state = Guest.S.WALK
	g.state_t = 0.0
	g.speed = Geo.WALK_SPEED * SpeciesDB.f(g.species, "speed")
	if absf(tx - g.x) > 0.5:
		g.facing = signf(tx - g.x)

## Anda em direção a g.tx; devolve true ao chegar.
static func step_x(g: Guest, dt: float) -> bool:
	var dx := g.tx - g.x
	var stp := g.speed * dt
	if absf(dx) <= stp:
		g.x = g.tx
		return true
	g.x += signf(dx) * stp
	g.facing = signf(dx)
	return false

## Leva o hóspede até (dest, goal_x); ao chegar entra em goal_state.
static func route(h: Hotel, g: Guest, dest: int, goal_x: float, goal_state: int) -> void:
	g.goal_x = goal_x
	g.goal_state = goal_state
	g.dest_floor = dest
	var cur := roundi(g.floor_f)
	if cur == dest:
		walk(g, goal_x, goal_state)
	elif SpeciesDB.b(g.species, "flies"):
		g.state = Guest.S.FLY
		g.state_t = 0.0
		g.tx = goal_x
		g.speed = Geo.WALK_SPEED * SpeciesDB.f(g.species, "speed")
	else:
		g.dir = 1 if dest > cur else -1
		var q: Array = h.elev_queue[cur]
		walk(g, Geo.elev_wait_x0(h.elevators.size()) + Geo.ELEV_WAIT_DX * float(q.size()), Guest.S.WAIT_ELEV)

# --- atualização por passo ---------------------------------------------------------

static func update(h: Hotel, g: Guest, dt: float) -> void:
	if g.state == Guest.S.DEAD:
		return
	g.prev_x = g.x
	g.prev_floor = g.floor_f
	g.state_t += dt
	if g.emote_t > 0.0:
		g.emote_t -= dt
		if g.emote_t <= 0.0:
			g.emote = &""
	if g.has_bed:
		g.stay_left -= dt            # a estadia corre também durante visitas
	match g.state:
		Guest.S.WALK:
			if step_x(g, dt):
				arrived(h, g, g.after)
		Guest.S.FLY:
			var dy := float(g.dest_floor) - g.floor_f
			var stp_y := Balance.FLY_SPEED * dt
			var done_y := absf(dy) <= stp_y
			if done_y:
				g.floor_f = float(g.dest_floor)
			else:
				g.floor_f += signf(dy) * stp_y
			var done_x := step_x(g, dt)
			if done_y and done_x:
				arrived(h, g, g.goal_state)
		Guest.S.WAIT_ELEV:
			if g.state_t > Balance.ELEV_GIVEUP:
				give_up_elevator(h, g)
		Guest.S.WAIT_ROOM:
			wait_room(h, g)
		Guest.S.IN_BED:
			in_bed(h, g)
		Guest.S.PAYING:
			if g.state_t >= Balance.PAY_TIME:
				h.complete_stay(g)
				walk(g, Geo.STREET_X + 150.0, Guest.S.DEAD)
		Guest.S.BALK_STOP:
			if g.state_t > 1.5:
				walk(g, Geo.STREET_X + 150.0, Guest.S.DEAD)
		_:
			pass

static func arrived(h: Hotel, g: Guest, st: int) -> void:
	g.state_t = 0.0
	match st:
		Guest.S.QUEUE:
			g.state = Guest.S.QUEUE
			g.wait_clock = 0.0
			h.reception_queue.append(g)
		Guest.S.CHECKIN:
			g.state = Guest.S.CHECKIN
			var lobby: RoomState = h.floors[0]
			for di in range(lobby.stations.size()):
				var d: RoomState.Station = lobby.stations[di]
				if d.reserved == g:
					d.reserved = null
					d.occupant = g
					d.timer = h.desk_service_time(di)
					return
			g.state = Guest.S.QUEUE                 # balcão sumiu: volta para a fila
			h.reception_queue.append(g)
		Guest.S.WAIT_ELEV:
			g.state = Guest.S.WAIT_ELEV
			g.wait_clock = 0.0
			var q: Array = h.elev_queue[roundi(g.floor_f)]
			q.append(g)
		Guest.S.IN_BED:
			enter_bed(h, g)
		Guest.S.QUEUE_FAC:
			g.state = Guest.S.QUEUE_FAC
			g.wait_clock = 0.0
			var fr: RoomState = h.floors[g.fac_floor]
			fr.queue.append(g)
		Guest.S.USING_FAC:
			g.state = Guest.S.USING_FAC
			var r: RoomState = h.floors[g.fac_floor]
			if g.fac_seat >= 0 and g.fac_seat < r.stations.size():
				var s: RoomState.Station = r.stations[g.fac_seat]
				s.reserved = null
				s.occupant = g
				s.timer = h.facility_service_time(r)
		_:
			g.state = st

# --- recepção -----------------------------------------------------------------

static func on_leave_reception_queue(h: Hotel, g: Guest) -> void:
	var tol := Balance.RECEPTION_TOL * SpeciesDB.f(g.species, "patience")
	var w := g.wait_clock
	h.note_wait(&"reception_wait_avg", w)
	if w > tol:
		g.add_factor(&"reception", -clampf((w - tol) / 12.0 * 0.5, 0.0, 1.4))
	elif w < tol * 0.35:
		g.add_factor(&"reception", 0.1)

static func finish_checkin(h: Hotel, g: Guest) -> void:
	if assign_bed(h, g):
		route(h, g, g.bed_floor, Geo.BED_XS[g.bed_idx], Guest.S.IN_BED)
	else:
		walk(g, Geo.WAIT_ROOM_X, Guest.S.WAIT_ROOM)

static func wait_room(h: Hotel, g: Guest) -> void:
	if assign_bed(h, g):
		g.add_factor(&"clean", -0.4)
		route(h, g, g.bed_floor, Geo.BED_XS[g.bed_idx], Guest.S.IN_BED)
	elif g.state_t > Balance.ROOM_WAIT_MAX:
		g.needs_bed = false
		h.register_miss(g)
		g.emote = &"angry"
		g.emote_t = 2.0
		walk(g, Geo.STREET_X + 150.0, Guest.S.DEAD)

## Reserva uma cama. Prefere o menor conforto que satisfaz a espécie (poupa os quartos de luxo),
## e, se nenhum satisfaz, usa o maior conforto disponível (com penalidade).
static func assign_bed(h: Hotel, g: Guest) -> bool:
	var min_c := SpeciesDB.i(g.species, "min_comfort") + (1 if g.vip else 0)
	var best_f := -1
	var best_b := -1
	var best_key := 1000000.0
	var fb_f := -1
	var fb_b := -1
	var fb_c := -1
	for f in range(1, h.floors.size()):
		var r: RoomState = h.floors[f]
		if r.type != &"suite":
			continue
		var comfort := int(RoomDB.at(&"suite", "comfort", r.level))
		for bi in range(r.beds.size()):
			var b: RoomState.Bed = r.beds[bi]
			if not b.is_free():
				continue
			if comfort >= min_c:
				var key := float(comfort) * 100.0 + float(f)
				if key < best_key:
					best_key = key
					best_f = f
					best_b = bi
			elif comfort > fb_c:
				fb_c = comfort
				fb_f = f
				fb_b = bi
	if best_f == -1:
		best_f = fb_f
		best_b = fb_b
	if best_f == -1:
		return false
	var room: RoomState = h.floors[best_f]
	var bed: RoomState.Bed = room.beds[best_b]
	bed.reserved = g
	g.bed_floor = best_f
	g.bed_idx = best_b
	g.needs_bed = false
	var comfort_got := int(RoomDB.at(&"suite", "comfort", room.level))
	g.add_factor(&"comfort", clampf(float(comfort_got - min_c) * Balance.COMFORT_SAT_STEP, -1.2, 1.2))
	var ps := float(Balance.PRICE_SAT[h.price_suite])
	if h.price_suite == 2:
		ps += 0.12 * float(comfort_got - 1)
		if h.rep < 3.5:
			ps -= 0.3
	if absf(ps) > 0.001:
		g.add_factor(&"price", ps)
	var tod := SpeciesDB.f(g.species, "night") if h.is_night() else SpeciesDB.f(g.species, "day")
	var stay_mult := 0.6 + 0.4 * (g.stay_total / Balance.STAY_BASE)
	g.room_rate = RoomDB.at(&"suite", "rate", room.level) * float(Balance.PRICE_REVENUE[h.price_suite]) \
		* SpeciesDB.f(g.species, "budget") * tod * stay_mult
	if g.vip:
		g.room_rate *= Balance.VIP_RATE_MULT
	_plan_facility(h, g)
	return true

static func _plan_facility(h: Hotel, g: Guest) -> void:
	var types := h.built_facility_types()
	if types.is_empty():
		return
	var use := float(Balance.PRICE_FAC_USE[h.price_fac])
	var fav: StringName = SpeciesDB.s(g.species, "fav")
	var pick: StringName = &""
	if g.vip:                                   # VIP sempre quer o serviço favorito (ou algum)
		pick = fav if (fav != &"" and types.has(fav)) else types[0]
	elif fav != &"" and types.has(fav) and h.rng.randf() < Balance.FAC_USE_FAV * use:
		pick = fav
	elif h.rng.randf() < Balance.FAC_USE_OTHER * use:
		pick = types[h.rng.randi() % types.size()]
	if pick != &"":
		g.fac_type = pick
		g.fac_time = g.stay_total * h.rng.randf_range(0.25, 0.55)

# --- elevador ----------------------------------------------------------------

static func on_board(h: Hotel, g: Guest) -> void:
	var tol := Balance.ELEVATOR_TOL * SpeciesDB.f(g.species, "patience")
	var w := g.wait_clock
	h.note_wait(&"elev_wait_avg", w)
	if w > tol:
		var cur := float(g.factors.get(&"elevator", 0.0))
		if cur > -1.6:
			g.add_factor(&"elevator", -clampf((w - tol) / 14.0 * 0.5, 0.0, 1.0))
	elif w < tol * 0.4:
		g.add_factor(&"elevator", 0.05)

static func on_exit_elevator(_h: Hotel, g: Guest, f: int, sx: float) -> void:
	g.in_car = false
	g.floor_f = float(f)
	g.prev_floor = g.floor_f
	g.x = sx
	g.prev_x = g.x
	walk(g, g.goal_x, g.goal_state)

static func give_up_elevator(h: Hotel, g: Guest) -> void:
	var f := roundi(g.floor_f)
	var q: Array = h.elev_queue[f]
	q.erase(g)
	g.add_factor(&"stairs", -0.9)
	h.bump(&"gave_up")
	g.emote = &"angry"
	g.emote_t = 2.0
	g.floor_f = float(g.dest_floor)
	g.prev_floor = g.floor_f
	g.x = Geo.shaft_x(0)
	g.prev_x = g.x
	walk(g, g.goal_x, g.goal_state)

# --- estadia -----------------------------------------------------------------

static func enter_bed(h: Hotel, g: Guest) -> void:
	var r: RoomState = h.floors[g.bed_floor]
	var b: RoomState.Bed = r.beds[g.bed_idx]
	b.reserved = null
	b.occupant = g
	g.state = Guest.S.IN_BED
	g.has_bed = true

static func in_bed(h: Hotel, g: Guest) -> void:
	if g.stay_left <= 0.0:
		begin_checkout(h, g)
		return
	if not g.fac_done and g.fac_type != &"":
		var elapsed := g.stay_total - g.stay_left
		if elapsed >= g.fac_time:
			g.fac_done = true
			var fl := h.pick_facility(g.fac_type)
			if fl >= 0:
				g.fac_floor = fl
				route(h, g, fl, Geo.FAC_WAIT_X0, Guest.S.QUEUE_FAC)

static func on_leave_fac_queue(h: Hotel, g: Guest) -> void:
	var tol := Balance.FAC_TOL * SpeciesDB.f(g.species, "patience")
	h.note_wait(&"fac_wait_avg", g.wait_clock)
	if g.wait_clock > tol:
		g.add_factor(&"facility", -clampf((g.wait_clock - tol) / 12.0 * 0.5, 0.0, 0.8))

static func finish_service(h: Hotel, g: Guest, r: RoomState) -> void:
	var fee := h.facility_fee(r, g)
	h.add_revenue(r.floor_idx, fee)
	g.paid += fee
	var fav: StringName = SpeciesDB.s(g.species, "fav")
	g.add_factor(&"facility", 0.65 if r.type == fav else 0.35)
	g.fac_visits += 1
	g.emote = &"heart"
	g.emote_t = 1.6
	route(h, g, g.bed_floor, Geo.BED_XS[g.bed_idx], Guest.S.IN_BED)

static func begin_checkout(h: Hotel, g: Guest) -> void:
	var r: RoomState = h.floors[g.bed_floor]
	var b: RoomState.Bed = r.beds[g.bed_idx]
	b.occupant = null
	b.dirty = true
	b.claimed = false
	b.clean_t = 0.0
	b.mess = SpeciesDB.f(g.species, "mess")
	g.has_bed = false
	route(h, g, 0, Geo.PAY_X, Guest.S.PAYING)
