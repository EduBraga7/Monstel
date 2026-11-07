class_name ReviewsSheet
extends Sheet
## Mural de avaliações dos hóspedes (o conteúdo "compartilhável" do jogo).

signal shared(text: String)

var _sig := ""

func build() -> void:
	title.text = Loc.t("sheet.reviews")
	_fill()

func _signature() -> String:
	if hotel.recent_reviews.is_empty():
		return "0"
	return "%d:%d" % [hotel.recent_reviews.size(), int((hotel.recent_reviews[0] as Dictionary).get("seed", 0))]

func update() -> void:
	var s := _signature()
	if s != _sig:
		_fill()

func _fill() -> void:
	_sig = _signature()
	for c in body.get_children():
		c.queue_free()
	if hotel.recent_reviews.is_empty():
		var e := UIKit.label(Loc.t("reviews.empty"), 30, UIKit.C_DIM, 500)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(e)
		return
	for i in range(mini(30, hotel.recent_reviews.size())):
		body.add_child(_card(hotel.recent_reviews[i] as Dictionary))

func _card(rv: Dictionary) -> Control:
	var species := StringName(str(rv.get("species", "ghost")))
	var stars := int(rv.get("stars", 3))
	var who := Loc.guest_name(str(species), int(rv.get("name_seed", 0)))
	var txt := Loc.review_text(rv)
	var c := Sheet.card()
	var h := UIKit.hbox(16)
	c.add_child(h)
	h.add_child(Sheet.avatar(species, 120.0))
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(10)
	var nm := UIKit.label(who + ("  VIP" if bool(rv.get("vip", false)) else ""), 32, UIKit.C_TEXT, 700)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	top.add_child(nm)
	top.add_child(Sheet.stars_row(stars, 5, 30.0))
	v.add_child(top)
	var t := UIKit.label(txt if txt != "" else "...", 30, UIKit.C_TEXT, 500)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(t)
	var bottom := UIKit.hbox(10)
	var meta := UIKit.label(Loc.t("reviews.meta", [Loc.t("species." + str(species)), int(rv.get("floor", 0)), int(rv.get("day", 1))]), 24, UIKit.C_DIM, 400)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(meta)
	var sb := UIKit.button(Loc.t("btn.share"), &"good", 26)
	sb.pressed.connect(func() -> void: _share(who, stars, txt))
	bottom.add_child(sb)
	v.add_child(bottom)
	h.add_child(v)
	return c

func _share(who: String, stars: int, txt: String) -> void:
	var line := "\"%s\" - %s %s\n%s #Monstel" % [txt, who, "*".repeat(stars), Loc.t("share.tag")]
	shared.emit(line)
