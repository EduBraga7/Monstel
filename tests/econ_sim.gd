extends SceneTree
## Simulação headless de economia. Uso:
##   tools\dev.bat script res://tests/econ_sim.gd --hours=2 --policy=greedy --seed=1 --tap=15 --dt=0.1
## Políticas: greedy (fecha gargalos e compra o melhor retorno) | idle (nunca compra nada).
## Imprime marcos de ritmo, uma linha por 15 min de jogo e um resumo final.

var h: Hotel
var policy := "greedy"
var tap := 15.0
var milestones: Dictionary = {}
var violations := 0
var verbose := false

func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			s = s.substr(2)
			var eq := s.find("=")
			if eq >= 0:
				out[s.substr(0, eq)] = s.substr(eq + 1)
			else:
				out[s] = "1"
	return out

func _init() -> void:
	var args := _parse_args()
	var hours := float(args.get("hours", "2"))
	policy = str(args.get("policy", "greedy"))
	var seed_value := int(args.get("seed", "1"))
	tap = float(args.get("tap", "15"))
	var dt := float(args.get("dt", "0.1"))
	verbose = args.has("verbose")
	h = Hotel.new(seed_value)
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	var total := hours * 3600.0
	var next_tap := tap
	var next_decide := 1.0
	var next_report := 900.0
	while t < total:
		h.step(dt)
		t += dt
		if policy != "idle":
			if tap > 0.0 and t >= next_tap:
				h.collect_all()
				next_tap += tap
			if t >= next_decide:
				_decide(t)
				next_decide += 1.0
		_check_milestones(t)
		_check_invariants(t)
		if t >= next_report:
			_report_line(t)
			next_report += 900.0
	var wall := float(Time.get_ticks_msec() - t0) / 1000.0
	_summary(total, wall)
	quit(0)

func _fmt(sec: float) -> String:
	return "%d:%02d" % [int(sec / 3600.0), int(fmod(sec, 3600.0) / 60.0)]

func _mark(name: String, t: float) -> void:
	if not milestones.has(name):
		milestones[name] = t

func _check_milestones(t: float) -> void:
	for n in [3, 5, 8, 10, 15, 20, 24]:
		if h.built_count() >= n:
			_mark("andares>=%d" % n, t)
	for l in [2, 3, 5, 8, 10, 15]:
		if h.level >= l:
			_mark("nivel>=%d" % l, t)
	if h.rep >= 4.0:
		_mark("rep>=4.0", t)
	if h.rep >= 4.5:
		_mark("rep>=4.5", t)
	for sp in h.discovered:
		_mark("especie:%s" % str(sp), t)

func _check_invariants(t: float) -> void:
	var bad := false
	if is_nan(h.money) or h.money < -0.001:
		bad = true
	if h.rep < 1.0 or h.rep > 5.0 or is_nan(h.rep):
		bad = true
	if h.guests.size() > 250:
		bad = true
	if bad:
		violations += 1
		if violations <= 5:
			print("INVARIANTE violada em ", _fmt(t), " money=", h.money, " rep=", h.rep, " guests=", h.guests.size())

func _report_line(t: float) -> void:
	var b := h.bottlenecks()
	print("%s  andares=%d camas=%d nivel=%d rep=%.2f $=%d renda=%.2f/s servidos=%d perdidos=%d travados=%d esperaRecep=%.1f esperaElev=%.1f convidados=%d" % [
		_fmt(t), h.built_count(), h.total_beds(), h.level, h.rep, int(h.money), h.income_ema,
		int(h.stat(&"served")), int(h.stat(&"missed")), int(h.stat(&"stuck")),
		float(b["reception_wait"]), float(b["elev_wait"]), h.guests.size()])

func _summary(total: float, wall: float) -> void:
	print("--- resumo (%s, politica=%s) ---" % [_fmt(total), policy])
	for k in milestones.keys():
		print("  marco %-18s %s" % [k, _fmt(milestones[k])])
	print("  andares=%d camas=%d nivel=%d rep=%.2f dinheiro=%d renda=%.2f/s" % [h.built_count(), h.total_beds(), h.level, h.rep, int(h.money), h.income_ema])
	print("  servidos=%d perdidos=%d desistiram_elev=%d travados=%d violacoes=%d" % [int(h.stat(&"served")), int(h.stat(&"missed")), int(h.stat(&"gave_up")), int(h.stat(&"stuck")), violations])
	print("  equipe: ", h.staff_n, " elevador=nivel", h.elevator_level, " x", h.elevators.size(), " poços, salario/dia=", int(h.wage_per_day()))
	print("  tempo real: %.1fs  (%.0fx tempo de jogo)" % [wall, total / maxf(0.001, wall)])

# --- política "greedy" ---------------------------------------------------------

func _buy_hire(t: StringName) -> bool:
	return h.hire(t)

func _facility_gain(t: StringName, lvl: int) -> float:
	var fee := RoomDB.at(t, "fee", lvl)
	var seats := RoomDB.at(t, "seats", lvl)
	var svc := RoomDB.at(t, "service", lvl)
	var cap_rate := seats / svc
	var use_rate := float(h.total_beds()) / 70.0 * 0.45
	var share := use_rate / float(h.count_rooms(t) + 1)
	return minf(cap_rate, share) * fee * 0.9

func _decide(t: float) -> void:
	if h.goal_done:
		h.claim_goal()                                # o jogador resgata a meta
	if h.rush_charges > 0 and h.rush_t <= 0.0 and h.free_beds_count() > 2 and h.level >= 3:
		h.activate_rush()
	var b := h.bottlenecks()
	if h.level >= 2 and h.staff_count(&"receptionist") < 2 and float(b["reception_wait"]) > 9.0:
		if h.hire(&"receptionist"):
			return
	if float(b["elev_wait"]) > 12.0:
		var up_cost := h.elevator_upgrade_cost()
		var sh_cost := h.shaft_cost()
		if h.block_reason_shaft() == &"" and (up_cost < 0.0 or sh_cost <= up_cost * 1.2):
			if h.build_shaft():
				return
		if h.elevator_level < 5 and h.upgrade_elevator():
			return
		if h.build_shaft():
			return
	if h.has_room(&"housekeeping") and float(b["dirty_ratio"]) > 0.18 and h.staff_count(&"maid") < h.staff_cap(&"maid"):
		if h.hire(&"maid"):
			return
	if h.level >= 3 and h.money > 500.0 and h.staff_count(&"cashier") == 0:
		if h.hire(&"cashier"):
			return
	if float(b["reception_wait"]) > 10.0 and h.staff_count(&"receptionist") >= 1 and h.block_reason_train(&"receptionist") == &"":
		if h.train(&"receptionist"):
			return
	if float(b["dirty_ratio"]) > 0.25 and h.staff_count(&"maid") >= 1 and h.block_reason_train(&"maid") == &"":
		if h.train(&"maid"):
			return
	var opts: Array = []
	var unmet := h.free_beds_count() == 0 or float(b["missed_ema"]) > 0.5
	var rate1 := RoomDB.at(&"suite", "rate", 1)
	var br := h.block_reason_build(&"suite")
	if br == &"" or br == &"money":
		opts.append({"cost": h.build_cost(&"suite"), "gain": 2.0 * rate1 * 0.9 / 70.0 * (1.0 if unmet else 0.35), "act": "build", "t": &"suite", "f": 0})
	for tt in RoomDB.BUILDABLE:
		if tt == &"suite":
			continue
		var brt := h.block_reason_build(tt)
		if brt != &"" and brt != &"money":
			continue
		var gain := 0.0
		match RoomDB.kind(tt):
			&"facility":
				gain = _facility_gain(tt, 1)
				if h.count_rooms(tt) == 0:
					gain *= 1.25                      # atrai a espécie favorita
			&"support":
				if tt == &"housekeeping":
					gain = maxf(0.02, float(b["dirty_ratio"]) * h.income_ema * 0.5)
				else:
					gain = h.income_ema * 0.07
		opts.append({"cost": h.build_cost(tt), "gain": gain, "act": "build", "t": tt, "f": 0})
	for f in range(1, h.floors.size()):
		var brf := h.block_reason_upgrade(f)
		if brf != &"" and brf != &"money":
			continue
		var r: RoomState = h.floors[f]
		var g2 := 0.0
		match RoomDB.kind(r.type):
			&"suite":
				var cur := RoomDB.at(&"suite", "rate", r.level) * RoomDB.at(&"suite", "beds", r.level)
				var nxt := RoomDB.at(&"suite", "rate", r.level + 1) * RoomDB.at(&"suite", "beds", r.level + 1)
				g2 = (nxt - cur) * 0.85 / 70.0
			&"facility":
				g2 = _facility_gain(r.type, r.level + 1) - _facility_gain(r.type, r.level)
			&"support":
				g2 = h.income_ema * 0.04
		opts.append({"cost": h.upgrade_cost(f), "gain": maxf(0.001, g2), "act": "upgrade", "t": r.type, "f": f})
	opts.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["gain"]) / float(a["cost"]) > float(c["gain"]) / float(c["cost"]))
	if opts.is_empty():
		return
	var best_ratio := float(opts[0]["gain"]) / float(opts[0]["cost"])
	for i in range(opts.size()):
		var o: Dictionary = opts[i]
		var cost := float(o["cost"])
		if float(o["gain"]) / cost < best_ratio * 0.3:
			break                                        # não vale gastar nisso
		if h.money < cost and h.money + h.pending_total() >= cost:
			h.collect_all()                              # o jogador toca para coletar antes de comprar
		if h.money >= cost:
			var ok := false
			if o["act"] == "build":
				ok = h.build(o["t"])
			else:
				ok = h.upgrade_room(int(o["f"]))
			if ok:
				if verbose:
					print(_fmt(t), " comprou ", o["act"], " ", o["t"], " por ", int(cost))
				return
