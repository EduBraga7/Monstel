class_name Hotel
extends RefCounted
## Estado e regras do hotel. Sem nós: roda headless, é salvo em JSON e sustenta o offline.
## Tempo em segundos de jogo; a tela chama step(Balance.DT) quantas vezes precisar.

signal coin_spawned(floor_idx: int, amount: float)
signal coins_collected(floor_idx: int, amount: float)
signal review_posted(review: Dictionary)
signal room_built(floor_idx: int)
signal room_upgraded(floor_idx: int)
signal level_up(new_level: int)
signal species_discovered(species: StringName)
signal day_ended(report: Dictionary)
signal guest_spawned(guest: Guest)
signal guest_balked(guest: Guest)
signal staff_changed()
signal rush_started()
signal goal_ready(goal_id: String)
signal goal_claimed(goal_id: String, reward: float)
signal vip_arrived(guest: Guest)
signal inspector_arrived(guest: Guest)
signal inspector_result(stars: int, bonus: float)

const SAVE_VERSION := 1
const MAX_REVIEWS := 60

var rng := RandomNumberGenerator.new()
var time := 0.0
var day := 1
var day_time := 0.0
var money := Balance.START_MONEY
var level := 1
var xp := 0.0
var rep := Balance.REP_START
var floors: Array[RoomState] = []
var elev_queue: Array = []              # um Array[Guest] por andar (compartilhada entre as cabines)
var elevators: Array[Elevator] = []
var elevator_level := 1
var guests: Array[Guest] = []
var reception_queue: Array[Guest] = []
var price_suite := 1                    # 0 barato, 1 justo, 2 luxo
var price_fac := 1
var staff_n: Dictionary = {}            # tipo -> quantidade
var staff_lvl: Dictionary = {}          # tipo -> nível de treino
var maids: Array[StaffMember] = []
var discovered: Dictionary = {}         # espécie -> true
var recent_reviews: Array = []
var stats: Dictionary = {}
var income_ema := 0.0                   # moedas/s (média móvel de ~60 s)
var wages_arrears := false
var rush_t := 0.0
var rush_charges := 1
var next_guest_id := 1
var goal_idx := 0
var goal_done := false                  # meta cumprida, esperando o jogador resgatar

var _vip_t := 480.0
var _insp_t := 900.0
var _goal_t := 0.0
var _arrival_t := 3.0
var _cashier_t := 0.0
var _rev_step := 0.0
var _day_rev := 0.0
var _day_guests := 0
var _day_stars := 0.0
var _day_missed := 0

func _init(seed_value: int = 0) -> void:
	new_game(seed_value)

func new_game(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	time = 0.0
	day = 1
	day_time = Balance.DAY_LEN * (Balance.START_HOUR - Balance.DAY_START_HOUR) / 24.0
	money = Balance.START_MONEY
	level = 1
	xp = 0.0
	rep = Balance.REP_START
	floors.clear()
	elev_queue.clear()
	guests.clear()
	reception_queue.clear()
	maids.clear()
	elevators.clear()
	elevators.append(Elevator.new())
	elevator_level = 1
	price_suite = 1
	price_fac = 1
	staff_n.clear()
	staff_lvl.clear()
	discovered.clear()
	recent_reviews.clear()
	stats.clear()
	income_ema = 0.0
	wages_arrears = false
	rush_t = 0.0
	rush_charges = 1
	next_guest_id = 1
	goal_idx = 0
	goal_done = false
	_vip_t = 480.0
	_insp_t = 900.0
	_goal_t = 0.0
	_arrival_t = 3.0
	_cashier_t = 0.0
	_day_rev = 0.0
	_day_guests = 0
	_day_stars = 0.0
	_day_missed = 0
	var lobby := RoomState.new()
	lobby.type = &"lobby"
	lobby.floor_idx = 0
	floors.append(lobby)
	var s := RoomState.new()
	s.type = &"suite"
	s.level = 1
	s.floor_idx = 1
	s.refresh_capacity()
	floors.append(s)
	_sync_floor_arrays()
	_refresh_desks()

# --- passo da simulação --------------------------------------------------------

func step(dt: float) -> void:
	time += dt
	day_time += dt
	_rev_step = 0.0
	rush_t = maxf(0.0, rush_t - dt)
	stats[&"missed_ema"] = float(stats.get(&"missed_ema", 0.0)) * (1.0 - dt / 60.0)
	_update_arrivals(dt)
	for g: Guest in guests:
		GuestAI.update(self, g, dt)
		_check_stuck(g)
	_update_reception(dt)
	_update_elevator_queues(dt)
	_update_facilities(dt)
	for e: Elevator in elevators:
		e.step(self, dt)
	_update_cleaning(dt)
	_update_cashier(dt)
	_update_events(dt)
	_update_goals(dt)
	_cull_dead()
	income_ema += (_rev_step / dt - income_ema) * (dt / 60.0)
	if day_time >= Balance.DAY_LEN:
		day_time -= Balance.DAY_LEN
		_end_day()

## Avança `seconds` de jogo em passos fixos.
func advance(seconds: float) -> void:
	var n := int(ceil(seconds / Balance.DT))
	for i in range(n):
		step(Balance.DT)

func _update_arrivals(dt: float) -> void:
	_arrival_t -= dt
	if _arrival_t > 0.0:
		return
	var mean_gap := 60.0 / maxf(0.2, arrival_rate_per_min())
	_arrival_t = clampf(-log(maxf(0.001, 1.0 - rng.randf())) * mean_gap, 0.8, 90.0)
	_spawn_guest()

func _spawn_guest(vip: bool = false, inspector: bool = false) -> void:
	var sp := _pick_species()
	var g := GuestAI.make_guest(self, sp)
	g.vip = vip
	g.inspector = inspector
	if not discovered.has(sp):
		discovered[sp] = true
		species_discovered.emit(sp)
	var incoming := _incoming_to_queue()
	var ok := (free_beds_count() - pipeline_count()) > 0 and reception_queue.size() + incoming < Balance.MAX_RECEPTION_QUEUE
	if ok:
		g.needs_bed = true
		GuestAI.walk(g, Geo.QUEUE_X0 + Geo.QUEUE_DX * float(reception_queue.size() + incoming), Guest.S.QUEUE)
	else:
		GuestAI.walk(g, Geo.DOOR_X + 60.0, Guest.S.BALK_STOP)
		g.emote = &"nobed"
		g.emote_t = 1.6
		register_miss(g)
	guests.append(g)
	guest_spawned.emit(g)
	if vip and ok:
		vip_arrived.emit(g)
	if inspector and ok:
		inspector_arrived.emit(g)

func _incoming_to_queue() -> int:
	var n := 0
	for g: Guest in guests:
		if g.state == Guest.S.WALK and g.after == Guest.S.QUEUE:
			n += 1
	return n

func _pick_species() -> StringName:
	var avail := available_species()
	var total := 0.0
	for id in avail:
		total += SpeciesDB.f(id, "weight")
	var r := rng.randf() * total
	for id2 in avail:
		r -= SpeciesDB.f(id2, "weight")
		if r <= 0.0:
			return id2
	return avail[0]

func register_miss(g: Guest) -> void:
	bump(&"missed")
	stats[&"missed_ema"] = float(stats.get(&"missed_ema", 0.0)) + 1.0
	_day_missed += 1
	guest_balked.emit(g)

func _update_reception(dt: float) -> void:
	var lobby: RoomState = floors[0]
	for i in range(reception_queue.size()):
		var g: Guest = reception_queue[i]
		g.tx = Geo.QUEUE_X0 + Geo.QUEUE_DX * float(i)
		GuestAI.step_x(g, dt)
		g.wait_clock += dt
	for di in range(lobby.stations.size()):
		var d: RoomState.Station = lobby.stations[di]
		if d.occupant != null:
			d.timer -= dt
			if d.timer <= 0.0:
				var done: Guest = d.occupant
				d.occupant = null
				GuestAI.finish_checkin(self, done)
		elif d.reserved == null and not reception_queue.is_empty():
			var front: Guest = reception_queue[0]
			if absf(front.x - front.tx) < 8.0:
				reception_queue.pop_front()
				d.reserved = front
				GuestAI.on_leave_reception_queue(self, front)
				GuestAI.walk(front, Geo.DESK_XS[di], Guest.S.CHECKIN)

func _update_elevator_queues(dt: float) -> void:
	var x0 := Geo.elev_wait_x0(elevators.size())
	for f in range(elev_queue.size()):
		var q: Array = elev_queue[f]
		for i in range(q.size()):
			var g: Guest = q[i]
			g.tx = x0 + Geo.ELEV_WAIT_DX * float(i)
			GuestAI.step_x(g, dt)
			g.wait_clock += dt

func _update_facilities(dt: float) -> void:
	for f in range(1, floors.size()):
		var r: RoomState = floors[f]
		if RoomDB.kind(r.type) != &"facility":
			continue
		for i in range(r.queue.size()):
			var g: Guest = r.queue[i]
			g.tx = Geo.FAC_WAIT_X0 + Geo.FAC_WAIT_DX * float(i)
			GuestAI.step_x(g, dt)
			g.wait_clock += dt
		for si in range(r.stations.size()):
			var st: RoomState.Station = r.stations[si]
			if st.occupant != null:
				st.timer -= dt
				if st.timer <= 0.0:
					var done: Guest = st.occupant
					st.occupant = null
					GuestAI.finish_service(self, done, r)
			elif st.reserved == null and not r.queue.is_empty():
				var front: Guest = r.queue[0]
				if absf(front.x - front.tx) < 8.0:
					r.queue.pop_front()
					st.reserved = front
					front.fac_seat = si
					GuestAI.on_leave_fac_queue(self, front)
					GuestAI.walk(front, Geo.SEAT_XS[si], Guest.S.USING_FAC)

func _update_cleaning(dt: float) -> void:
	if maids.is_empty():
		for f in range(1, floors.size()):
			var r: RoomState = floors[f]
			if r.type != &"suite":
				continue
			for b: RoomState.Bed in r.beds:
				if b.dirty:
					b.clean_t += dt
					if b.clean_t >= Balance.SELF_CLEAN_TIME * b.mess:
						b.dirty = false
	else:
		for m: StaffMember in maids:
			_update_maid(m, dt)
		for f2 in range(1, floors.size()):          # plano B lento para camas esquecidas
			var r2: RoomState = floors[f2]
			if r2.type != &"suite":
				continue
			for b2: RoomState.Bed in r2.beds:
				if b2.dirty and not b2.claimed:
					b2.clean_t += dt
					if b2.clean_t >= Balance.SELF_CLEAN_TIME * 2.5 * b2.mess:
						b2.dirty = false

func _find_dirty_bed(m: StaffMember) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1000000.0
	for f in range(1, floors.size()):
		var r: RoomState = floors[f]
		if r.type != &"suite":
			continue
		for bi in range(r.beds.size()):
			var b: RoomState.Bed = r.beds[bi]
			if b.dirty and not b.claimed:
				var d := absf(float(f) - m.floor_f)
				if d < best_d:
					best_d = d
					best = Vector2i(f, bi)
	return best

func _update_maid(m: StaffMember, dt: float) -> void:
	m.prev_floor = m.floor_f
	match m.st:
		StaffMember.St.IDLE:
			var t := _find_dirty_bed(m)
			if t.x >= 0:
				m.target_floor = t.x
				m.target_bed = t.y
				var bed: RoomState.Bed = (floors[t.x] as RoomState).beds[t.y]
				bed.claimed = true
				m.st = StaffMember.St.TRAVEL
		StaffMember.St.TRAVEL:
			m.floor_f = move_toward(m.floor_f, float(m.target_floor), Balance.MAID_TRAVEL_SPEED * dt)
			if is_equal_approx(m.floor_f, float(m.target_floor)):
				var bed2: RoomState.Bed = (floors[m.target_floor] as RoomState).beds[m.target_bed]
				m.st = StaffMember.St.CLEAN
				m.timer = Balance.MAID_CLEAN_TIME * bed2.mess / (StaffDB.at(&"maid", "speed", staff_level(&"maid")) * staff_morale())
		StaffMember.St.CLEAN:
			m.timer -= dt
			if m.timer <= 0.0:
				var bed3: RoomState.Bed = (floors[m.target_floor] as RoomState).beds[m.target_bed]
				bed3.dirty = false
				bed3.claimed = false
				bed3.clean_t = 0.0
				m.st = StaffMember.St.IDLE
				m.target_floor = -1
				m.target_bed = -1

func _update_cashier(dt: float) -> void:
	if staff_count(&"cashier") <= 0:
		return
	_cashier_t -= dt
	if _cashier_t <= 0.0:
		_cashier_t = StaffDB.at(&"cashier", "interval", staff_level(&"cashier")) / staff_morale()
		collect_all(false)

# --- eventos: VIP e inspetor secreto --------------------------------------------------

func _door_has_room() -> bool:
	return (free_beds_count() - pipeline_count()) > 0 and reception_queue.size() + _incoming_to_queue() < Balance.MAX_RECEPTION_QUEUE

func _update_events(dt: float) -> void:
	if level >= 3:
		_vip_t -= dt
		if _vip_t <= 0.0:
			if _door_has_room():
				_vip_t = rng.randf_range(Balance.VIP_GAP_MIN, Balance.VIP_GAP_MAX)
				_spawn_guest(true, false)
			else:
				_vip_t = 25.0
	if level >= 4:
		_insp_t -= dt
		if _insp_t <= 0.0:
			if _door_has_room():
				_insp_t = rng.randf_range(Balance.INSP_GAP_MIN, Balance.INSP_GAP_MAX)
				_spawn_guest(false, true)
			else:
				_insp_t = 25.0

## O jogador cumprimenta o VIP no saguão: ele fica mais satisfeito.
func greet(g: Guest) -> bool:
	if not g.vip or g.greeted or g.state == Guest.S.DEAD:
		return false
	g.greeted = true
	g.add_factor(&"vip", 0.8)
	g.emote = &"star"
	g.emote_t = 2.5
	bump(&"greeted")
	return true

# --- metas ------------------------------------------------------------------------------

func goal_current() -> Dictionary:
	return GoalDB.get_goal(goal_idx)

func goals_finished() -> bool:
	return goal_idx >= GoalDB.count()

func goal_target() -> float:
	var g := goal_current()
	match str(g["kind"]):
		"rep":
			return float(g["v"])
		_:
			return float(g.get("n", 1))

func goal_value() -> float:
	var g := goal_current()
	match str(g["kind"]):
		"taps":
			return stat(&"taps")
		"served":
			return stat(&"served")
		"upgrades":
			return stat(&"upgrades")
		"rep":
			return rep
		"level":
			return float(level)
		"build_type":
			return float(count_rooms(StringName(str(g["t"]))))
		"staff":
			return float(staff_count(StringName(str(g["t"]))))
		"suite_level":
			var best := 0
			for r: RoomState in floors:
				if r.type == &"suite":
					best = maxi(best, r.level)
			return float(best)
		"shafts":
			return float(elevators.size())
		"rush":
			return stat(&"rush_used")
		"floors":
			return float(built_count())
	return 0.0

## Recompensa: 35 s da renda atual (com piso crescente), para valer a pena em qualquer fase.
func goal_reward() -> float:
	var base := 40.0 * pow(1.13, float(goal_idx))
	return roundf(maxf(base, income_ema * 35.0))

func _update_goals(dt: float) -> void:
	if goal_done or goals_finished():
		return
	_goal_t -= dt
	if _goal_t > 0.0:
		return
	_goal_t = 0.5
	if goal_value() >= goal_target():
		goal_done = true
		goal_ready.emit(str(goal_current()["id"]))

func claim_goal() -> float:
	if not goal_done or goals_finished():
		return 0.0
	var id := str(goal_current()["id"])
	var reward := goal_reward()
	money += reward
	add_xp(2.0 + float(goal_idx) * 0.4)
	if goal_idx % 6 == 5:
		rush_charges = mini(3, rush_charges + 1)
	goal_idx += 1
	goal_done = false
	_goal_t = 0.5
	goal_claimed.emit(id, reward)
	return reward

func _cull_dead() -> void:
	var i := guests.size() - 1
	while i >= 0:
		if guests[i].state == Guest.S.DEAD:
			guests.remove_at(i)
		i -= 1

func _check_stuck(g: Guest) -> void:
	if g.stuck_flag:
		return
	var lim := 150.0
	match g.state:
		Guest.S.QUEUE, Guest.S.CHECKIN:
			lim = 120.0
		Guest.S.WAIT_ELEV:
			lim = Balance.ELEV_GIVEUP + 30.0
		Guest.S.WAIT_ROOM:
			lim = Balance.ROOM_WAIT_MAX + 30.0
		Guest.S.IN_BED:
			lim = g.stay_total + 60.0
		Guest.S.RIDE:
			lim = 120.0
		Guest.S.PAYING:
			lim = 20.0
		Guest.S.QUEUE_FAC, Guest.S.USING_FAC:
			lim = 180.0
	if g.state_t > lim:
		g.stuck_flag = true
		bump(&"stuck")

func _end_day() -> void:
	var due := wage_per_day()
	var paid := minf(money, due)
	money -= paid
	wages_arrears = paid < due - 0.01
	var report := {
		"day": day,
		"revenue": _day_rev,
		"wages": paid,
		"arrears": wages_arrears,
		"guests": _day_guests,
		"avg_stars": (_day_stars / float(_day_guests)) if _day_guests > 0 else 0.0,
		"missed": _day_missed,
		"rep": rep,
		"money": money,
	}
	day += 1
	_day_rev = 0.0
	_day_guests = 0
	_day_stars = 0.0
	_day_missed = 0
	day_ended.emit(report)

# --- contabilidade ---------------------------------------------------------------

func add_revenue(f: int, amt: float) -> void:
	var r: RoomState = floors[f]
	r.pending += amt
	r.pending_n += 1
	r.total_earned += amt
	_rev_step += amt
	_day_rev += amt
	_stat_add(&"revenue_total", amt)
	coin_spawned.emit(f, amt)

func complete_stay(g: Guest) -> void:
	var sat := clampf(Balance.SAT_BASE + g.sat_delta + rng.randf_range(-0.3, 0.3) + bellhop_sat(), 0.5, 5.4)
	var stars := clampi(roundi(sat), 1, 5)
	var tip := g.room_rate * Balance.TIP_RATE * maxf(0.0, sat - 3.5) * SpeciesDB.f(g.species, "tip")
	var pay := g.room_rate + tip
	g.paid += pay
	add_revenue(g.bed_floor, pay)
	var w := 5.0 if g.inspector else (3.0 if g.vip else 1.0)
	rep = clampf(rep + (float(stars) - rep) * minf(0.6, Balance.REP_ALPHA * w), 1.0, 5.0)
	if g.inspector:
		var bonus := 0.0
		if stars >= 4:
			bonus = roundf(maxf(60.0, income_ema * 240.0))
			money += bonus
		inspector_result.emit(stars, bonus)
	var gain := 1.0 + maxf(0.0, float(stars) - 3.0) * 0.5
	if g.vip:
		gain *= 8.0
	add_xp(gain)
	_stat_add(&"served", 1.0)
	_stat_add(&"stars_sum", float(stars))
	_day_guests += 1
	_day_stars += float(stars)
	var rv := ReviewGen.make(self, g, stars)
	recent_reviews.push_front(rv)
	if recent_reviews.size() > MAX_REVIEWS:
		recent_reviews.pop_back()
	g.mood = 1 if stars >= 4 else (2 if stars <= 2 else 0)
	g.emote = &"heart" if stars >= 4 else (&"angry" if stars <= 2 else &"")
	g.emote_t = 2.5
	review_posted.emit(rv)

func xp_needed(l: int) -> float:
	return roundf(Balance.XP_BASE * pow(Balance.XP_GROWTH, float(l - 1)))

func add_xp(x: float) -> void:
	xp += x
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		level_up.emit(level)

func bump(key: StringName) -> void:
	_stat_add(key, 1.0)

func _stat_add(key: StringName, v: float) -> void:
	stats[key] = float(stats.get(key, 0.0)) + v

func stat(key: StringName) -> float:
	return float(stats.get(key, 0.0))

func note_wait(key: StringName, w: float) -> void:
	stats[key] = lerpf(float(stats.get(key, 0.0)), w, 0.12)

# --- consultas -------------------------------------------------------------------

func floor_count() -> int:
	return floors.size()

func built_count() -> int:
	return floors.size() - 1

func hour() -> float:
	return fmod(Balance.DAY_START_HOUR + day_time / Balance.DAY_LEN * 24.0, 24.0)

func is_night() -> bool:
	var h := hour()
	return h >= Balance.NIGHT_START or h < Balance.NIGHT_END

func tod_mult() -> float:
	var h := hour()
	if is_night():
		return Balance.NIGHT_ARRIVAL_MULT
	if h >= 9.0 and h < 17.0:
		return Balance.DAY_ARRIVAL_MULT
	return 1.0

func rep_mult() -> float:
	return Balance.REP_MULT_MIN + Balance.REP_MULT_SLOPE * (rep - 1.0)

func marketing_mult() -> float:
	var r := get_room(&"marketing")
	if r == null:
		return 1.0
	return RoomDB.at(&"marketing", "arrival", r.level)

func arrival_rate_per_min() -> float:
	var base := Balance.ARRIVAL_BASE_PER_MIN + Balance.ARRIVAL_PER_LEVEL_PER_MIN * float(level - 1) \
		+ Balance.ARRIVAL_PER_BED_PER_MIN * float(total_beds())
	var m := rep_mult() * marketing_mult() * float(Balance.PRICE_DEMAND[price_suite]) * tod_mult()
	if rush_t > 0.0:
		m *= Balance.RUSH_MULT
	return base * m

func total_beds() -> int:
	var n := 0
	for r: RoomState in floors:
		if r.type == &"suite":
			n += r.beds.size()
	return n

func free_beds_count() -> int:
	var n := 0
	for r: RoomState in floors:
		if r.type != &"suite":
			continue
		for b: RoomState.Bed in r.beds:
			if b.occupant == null and b.reserved == null:
				n += 1
	return n

func pipeline_count() -> int:
	var n := 0
	for g: Guest in guests:
		if g.needs_bed:
			n += 1
	return n

func dirty_ratio() -> float:
	var total := 0
	var dirty := 0
	for r: RoomState in floors:
		if r.type != &"suite":
			continue
		for b: RoomState.Bed in r.beds:
			total += 1
			if b.dirty:
				dirty += 1
	return float(dirty) / float(maxi(1, total))

func get_room(t: StringName) -> RoomState:
	for r: RoomState in floors:
		if r.type == t:
			return r
	return null

func count_rooms(t: StringName) -> int:
	var n := 0
	for r: RoomState in floors:
		if r.type == t:
			n += 1
	return n

func has_room(t: StringName) -> bool:
	return get_room(t) != null

func built_facility_types() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: RoomState in floors:
		if RoomDB.kind(r.type) == &"facility" and not out.has(r.type):
			out.append(r.type)
	return out

func available_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in SpeciesDB.ORDER:
		if level < SpeciesDB.i(id, "unlock"):
			continue
		var need: StringName = SpeciesDB.s(id, "needs")
		if need != &"" and not has_room(need):
			continue
		out.append(id)
	return out

func pick_facility(t: StringName) -> int:
	var best := -1
	var best_score := 1000000.0
	for r: RoomState in floors:
		if r.type != t:
			continue
		var score := float(r.queue.size()) * 3.0 + float(r.floor_idx) * 0.15 + rng.randf() * 0.5
		if score < best_score:
			best_score = score
			best = r.floor_idx
	return best

func desk_count() -> int:
	return mini(3, 1 + staff_count(&"receptionist"))

func desk_service_time(di: int) -> float:
	var spd := Balance.MANAGER_DESK_SPEED
	if di > 0:
		spd = StaffDB.at(&"receptionist", "speed", staff_level(&"receptionist")) * staff_morale()
	return Balance.CHECKIN_BASE / spd

func facility_service_time(r: RoomState) -> float:
	return RoomDB.at(r.type, "service", r.level) * rng.randf_range(0.9, 1.1)

func facility_fee(r: RoomState, g: Guest) -> float:
	return RoomDB.at(r.type, "fee", r.level) * float(Balance.PRICE_REVENUE[price_fac]) * (0.5 + 0.5 * SpeciesDB.f(g.species, "budget"))

func staff_morale() -> float:
	return Balance.ARREARS_SPEED if wages_arrears else 1.0

func bellhop_door_mult() -> float:
	var n := staff_count(&"bellhop")
	if n <= 0:
		return 1.0
	return maxf(0.35, pow(StaffDB.at(&"bellhop", "door", staff_level(&"bellhop")), float(n)))

func bellhop_sat() -> float:
	return 0.12 * float(staff_count(&"bellhop"))

func wage_per_day() -> float:
	var total := 0.0
	for t in StaffDB.ORDER:
		var n := staff_count(t)
		if n > 0:
			total += float(n) * StaffDB.wage(t) * (1.0 + Balance.WAGE_LEVEL_STEP * float(staff_level(t) - 1))
	return total * (1.0 + Balance.WAGE_FLOOR_STEP * float(built_count()))

## Diagnóstico de gargalos (usado pela tela e pelos bots).
func bottlenecks() -> Dictionary:
	return {
		"reception_wait": float(stats.get(&"reception_wait_avg", 0.0)),
		"elev_wait": float(stats.get(&"elev_wait_avg", 0.0)),
		"fac_wait": float(stats.get(&"fac_wait_avg", 0.0)),
		"dirty_ratio": dirty_ratio(),
		"missed_ema": float(stats.get(&"missed_ema", 0.0)),
		"free_beds": free_beds_count(),
		"queue_len": reception_queue.size(),
	}

# --- ações do jogador ---------------------------------------------------------------

func build_cost(t: StringName) -> float:
	return RoomDB.build_cost(t, floors.size() - 1)

## Motivo pelo qual não dá para construir ("" = pode): level, max_floors, max_type, money.
func block_reason_build(t: StringName) -> StringName:
	if level < RoomDB.unlock_level(t):
		return &"level"
	if floors.size() >= Balance.MAX_FLOORS:
		return &"max_floors"
	if count_rooms(t) >= int(Balance.MAX_PER_TYPE[t]):
		return &"max_type"
	if money < build_cost(t):
		return &"money"
	return &""

func build(t: StringName) -> bool:
	if block_reason_build(t) != &"":
		return false
	money -= build_cost(t)
	var r := RoomState.new()
	r.type = t
	r.level = 1
	r.floor_idx = floors.size()
	r.refresh_capacity()
	floors.append(r)
	_sync_floor_arrays()
	room_built.emit(r.floor_idx)
	return true

func upgrade_cost(f: int) -> float:
	var r: RoomState = floors[f]
	return RoomDB.upgrade_cost(r.type, r.level)

func block_reason_upgrade(f: int) -> StringName:
	var r: RoomState = floors[f]
	var c := RoomDB.upgrade_cost(r.type, r.level)
	if c < 0.0:
		return &"max"
	if money < c:
		return &"money"
	return &""

func upgrade_room(f: int) -> bool:
	if block_reason_upgrade(f) != &"":
		return false
	var r: RoomState = floors[f]
	money -= RoomDB.upgrade_cost(r.type, r.level)
	r.level += 1
	r.refresh_capacity()
	_stat_add(&"upgrades", 1.0)
	room_upgraded.emit(f)
	return true

func elevator_upgrade_cost() -> float:
	return RoomDB.elev_upgrade_cost(elevator_level)

func upgrade_elevator() -> bool:
	var c := elevator_upgrade_cost()
	if c < 0.0 or money < c:
		return false
	money -= c
	elevator_level += 1
	staff_changed.emit()
	return true

func shaft_cost() -> float:
	if elevators.size() >= int(RoomDB.SHAFTS["max"]):
		return -1.0
	var arr: Array = RoomDB.SHAFTS["cost"]
	return float(arr[elevators.size() - 1])

func block_reason_shaft() -> StringName:
	var c := shaft_cost()
	if c < 0.0:
		return &"max"
	var unlock: Array = RoomDB.SHAFTS["unlock"]
	if level < int(unlock[elevators.size() - 1]):
		return &"level"
	if money < c:
		return &"money"
	return &""

func build_shaft() -> bool:
	if block_reason_shaft() != &"":
		return false
	money -= shaft_cost()
	var e := Elevator.new()
	e.idx = elevators.size()
	e.y = elevators[0].y
	elevators.append(e)
	staff_changed.emit()
	return true

func set_price(kind: StringName, v: int) -> void:
	v = clampi(v, 0, 2)
	if kind == &"suite":
		price_suite = v
	else:
		price_fac = v

func staff_count(t: StringName) -> int:
	return int(staff_n.get(t, 0))

func staff_level(t: StringName) -> int:
	return int(staff_lvl.get(t, 1))

func staff_cap(t: StringName) -> int:
	if t == &"maid":
		var hk := get_room(&"housekeeping")
		if hk == null:
			return 0
		return int(RoomDB.at(&"housekeeping", "maids", hk.level))
	return StaffDB.cap(t)

func hire_cost(t: StringName) -> float:
	return StaffDB.hire_cost(t, staff_count(t))

func block_reason_hire(t: StringName) -> StringName:
	if level < StaffDB.unlock_level(t):
		return &"level"
	if t == &"maid" and not has_room(&"housekeeping"):
		return &"need_room"
	if staff_count(t) >= staff_cap(t):
		return &"cap"
	var c := hire_cost(t)
	if c < 0.0:
		return &"cap"
	if money < c:
		return &"money"
	return &""

func hire(t: StringName) -> bool:
	if block_reason_hire(t) != &"":
		return false
	money -= hire_cost(t)
	staff_n[t] = staff_count(t) + 1
	if not staff_lvl.has(t):
		staff_lvl[t] = 1
	if t == &"maid":
		maids.append(StaffMember.new())
	_refresh_desks()
	staff_changed.emit()
	return true

func train_cost(t: StringName) -> float:
	return StaffDB.train_cost(t, staff_level(t))

func block_reason_train(t: StringName) -> StringName:
	if staff_count(t) <= 0:
		return &"nobody"
	var c := train_cost(t)
	if c < 0.0:
		return &"max"
	if money < c:
		return &"money"
	return &""

func train(t: StringName) -> bool:
	if block_reason_train(t) != &"":
		return false
	money -= train_cost(t)
	staff_lvl[t] = staff_level(t) + 1
	staff_changed.emit()
	return true

func collect(f: int, manual: bool = true) -> float:
	var r: RoomState = floors[f]
	if r.pending <= 0.0:
		return 0.0
	var amt := r.pending
	r.pending = 0.0
	r.pending_n = 0
	money += amt
	_stat_add(&"collected_total", amt)
	if manual:
		_stat_add(&"taps", 1.0)
	coins_collected.emit(f, amt)
	return amt

func collect_all(manual: bool = true) -> float:
	var total := 0.0
	var any := false
	for f in range(floors.size()):
		var a := collect(f, false)
		if a > 0.0:
			any = true
			total += a
	if any and manual:
		_stat_add(&"taps", 1.0)
	return total

func pending_total() -> float:
	var total := 0.0
	for r: RoomState in floors:
		total += r.pending
	return total

func activate_rush() -> bool:
	if rush_charges <= 0 or rush_t > 0.0:
		return false
	rush_charges -= 1
	rush_t = Balance.RUSH_LEN
	_stat_add(&"rush_used", 1.0)
	rush_started.emit()
	return true

## Ganho estimado por `seconds` fora do jogo (limitado e com eficiência reduzida).
func offline_gain(seconds: float) -> float:
	var cap := Balance.OFFLINE_CAP_H * 3600.0
	var net_rate := maxf(0.0, income_ema - wage_per_day() / Balance.DAY_LEN)
	return net_rate * minf(maxf(0.0, seconds), cap) * Balance.OFFLINE_EFFICIENCY

## Aplica o ganho offline como um baú de moedas no saguão; devolve o valor.
func apply_offline(seconds: float) -> float:
	var gain := offline_gain(seconds)
	if gain >= 1.0:
		var lobby: RoomState = floors[0]
		lobby.pending += gain
		lobby.pending_n += 1
		coin_spawned.emit(0, gain)
	return gain

# --- estrutura ----------------------------------------------------------------

func _sync_floor_arrays() -> void:
	while elev_queue.size() < floors.size():
		elev_queue.append([])

func _refresh_desks() -> void:
	var lobby: RoomState = floors[0]
	while lobby.stations.size() < desk_count():
		lobby.stations.append(RoomState.Station.new())

# --- persistência ----------------------------------------------------------------

func to_dict() -> Dictionary:
	var fl: Array = []
	for r: RoomState in floors:
		fl.append({"type": str(r.type), "level": r.level, "pending": r.pending, "earned": r.total_earned})
	var st := {}
	for k in stats:
		st[str(k)] = stats[k]
	var disc: Array = []
	for k in discovered:
		disc.append(str(k))
	var sn := {}
	for k in staff_n:
		sn[str(k)] = staff_n[k]
	var sl := {}
	for k in staff_lvl:
		sl[str(k)] = staff_lvl[k]
	var revs: Array = []
	for rv in recent_reviews.slice(0, 40):
		var c := {}
		for k in rv:
			c[str(k)] = str(rv[k]) if rv[k] is StringName else rv[k]
		revs.append(c)
	return {
		"version": SAVE_VERSION, "time": time, "day": day, "day_time": day_time, "money": money,
		"level": level, "xp": xp, "rep": rep, "floors": fl, "elevator_level": elevator_level,
		"shafts": elevators.size(),
		"price_suite": price_suite, "price_fac": price_fac, "staff_n": sn, "staff_lvl": sl,
		"discovered": disc, "stats": st, "reviews": revs, "income_ema": income_ema,
		"rush_charges": rush_charges, "wages_arrears": wages_arrears,
		"goal_idx": goal_idx, "goal_done": goal_done,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "next_guest_id": next_guest_id,
	}

## Restaura de um dicionário salvo, validando tudo (o arquivo pode ter sido editado).
func from_dict(d: Dictionary) -> bool:
	if not d.has("floors") or int(d.get("version", 0)) < 1:
		return false
	new_game(1)
	floors.clear()
	elev_queue.clear()
	for fd in d["floors"]:
		var t := StringName(str(fd.get("type", "suite")))
		if not RoomDB.DATA.has(t):
			continue
		var r := RoomState.new()
		r.type = t
		r.level = clampi(int(fd.get("level", 1)), 1, RoomDB.max_level(t))
		r.floor_idx = floors.size()
		r.pending = maxf(0.0, float(fd.get("pending", 0.0)))
		r.total_earned = maxf(0.0, float(fd.get("earned", 0.0)))
		r.refresh_capacity()
		floors.append(r)
	if floors.is_empty() or floors[0].type != &"lobby":
		new_game(1)
		return false
	_sync_floor_arrays()
	time = float(d.get("time", 0.0))
	day = maxi(1, int(d.get("day", 1)))
	day_time = clampf(float(d.get("day_time", 0.0)), 0.0, Balance.DAY_LEN)
	money = maxf(0.0, float(d.get("money", 0.0)))
	level = maxi(1, int(d.get("level", 1)))
	xp = maxf(0.0, float(d.get("xp", 0.0)))
	rep = clampf(float(d.get("rep", Balance.REP_START)), 1.0, 5.0)
	elevator_level = clampi(int(d.get("elevator_level", 1)), 1, int(RoomDB.ELEVATOR["max_level"]))
	elevators.clear()
	for si in range(clampi(int(d.get("shafts", 1)), 1, int(RoomDB.SHAFTS["max"]))):
		var ev := Elevator.new()
		ev.idx = si
		elevators.append(ev)
	price_suite = clampi(int(d.get("price_suite", 1)), 0, 2)
	price_fac = clampi(int(d.get("price_fac", 1)), 0, 2)
	income_ema = maxf(0.0, float(d.get("income_ema", 0.0)))
	rush_charges = clampi(int(d.get("rush_charges", 1)), 0, 9)
	wages_arrears = bool(d.get("wages_arrears", false))
	next_guest_id = maxi(1, int(d.get("next_guest_id", 1)))
	goal_idx = clampi(int(d.get("goal_idx", 0)), 0, GoalDB.count())
	goal_done = bool(d.get("goal_done", false)) and goal_idx < GoalDB.count()
	for k in d.get("stats", {}):
		stats[StringName(str(k))] = float(d["stats"][k])
	for k in d.get("discovered", []):
		discovered[StringName(str(k))] = true
	staff_n.clear()
	staff_lvl.clear()
	for t2 in StaffDB.ORDER:
		var n := clampi(int(d.get("staff_n", {}).get(str(t2), 0)), 0, staff_cap(t2))   # camareiras: limite da Governança
		if n > 0:
			staff_n[t2] = n
			staff_lvl[t2] = clampi(int(d.get("staff_lvl", {}).get(str(t2), 1)), 1, StaffDB.MAX_LEVEL)
	maids.clear()
	for i in range(staff_count(&"maid")):
		maids.append(StaffMember.new())
	recent_reviews.clear()
	for rv in d.get("reviews", []):
		var c := {}
		for k in rv:
			c[StringName(str(k))] = rv[k]
		c[&"species"] = StringName(str(c.get(&"species", "ghost")))
		c[&"factor"] = StringName(str(c.get(&"factor", "generic")))
		recent_reviews.append(c)
	rng.seed = int(str(d.get("rng_seed", "1")))
	rng.state = int(str(d.get("rng_state", str(rng.state))))
	_refresh_desks()
	return true
