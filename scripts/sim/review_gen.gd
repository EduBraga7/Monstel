class_name ReviewGen
extends RefCounted
## Monta o registro (sem texto) de uma avaliação. O texto final vem de data/reviews.json,
## escolhido pela interface a partir de espécie, estrelas, fator dominante e semente.

static func make(h: Hotel, g: Guest, stars: int) -> Dictionary:
	var dom: StringName = &"generic"
	var best := 0.0
	for k in g.factors:
		var v := absf(float(g.factors[k]))
		if v > best + 0.0001:
			best = v
			dom = k
	var positive := float(g.factors.get(dom, 0.0)) >= 0.0
	return {
		"species": g.species,
		"stars": stars,
		"factor": dom,
		"positive": positive,
		"seed": h.rng.randi(),
		"name_seed": g.name_seed,
		"day": h.day,
		"floor": g.bed_floor,
		"vip": g.vip,
		"inspector": g.inspector,
		"paid": g.paid,
	}
