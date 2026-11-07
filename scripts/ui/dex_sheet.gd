class_name DexSheet
extends Sheet
## Monstrodex: as espécies de hóspedes, o que cada uma gosta e como atraí-las.

func build() -> void:
	title.text = Loc.t("sheet.dex")
	var seen := 0
	for sp in SpeciesDB.ORDER:
		if hotel.discovered.has(sp):
			seen += 1
	body.add_child(UIKit.label(Loc.t("dex.seen", [seen, SpeciesDB.ORDER.size()]), 32, UIKit.C_MINT, 700))
	for sp in SpeciesDB.ORDER:
		var known := hotel.discovered.has(sp)
		var c := Sheet.card()
		var h := UIKit.hbox(16)
		c.add_child(h)
		h.add_child(Sheet.avatar(sp, 150.0, not known))
		var v := UIKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loc.t("species." + str(sp)) if known else Loc.t("dex.locked"), 38, UIKit.C_TEXT if known else UIKit.C_DIM, 700))
		var d := UIKit.label(Loc.t("dex.trait." + str(sp)) if known else _how_to(sp), 26, UIKit.C_DIM, 400)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(d)
		h.add_child(v)
		body.add_child(c)

func _how_to(sp: StringName) -> String:
	var need: StringName = SpeciesDB.s(sp, "needs")
	var parts: Array[String] = []
	if need != &"":
		parts.append(Loc.t("dex.need", [Loc.t("room." + str(need))]))
	var lv := SpeciesDB.i(sp, "unlock")
	if lv > 1:
		parts.append(Loc.t("dex.level", [lv]))
	return " · ".join(parts) if not parts.is_empty() else "..."
