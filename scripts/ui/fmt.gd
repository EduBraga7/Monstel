class_name Fmt
extends RefCounted
## Formatação de números e tempos para a interface.

const UNITS: Array[String] = ["K", "M", "B", "T", "Qa", "Qi"]

## 1234 -> "1.23K"; números pequenos saem inteiros.
static func coins(v: float) -> String:
	var a := absf(v)
	if a < 1000.0:
		return str(int(v))
	var x := a
	var i := -1
	while x >= 1000.0 and i < UNITS.size() - 1:
		x /= 1000.0
		i += 1
	var s := ""
	if x < 10.0:
		s = "%.2f" % x
	elif x < 100.0:
		s = "%.1f" % x
	else:
		s = "%d" % int(x)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return ("-" if v < 0.0 else "") + s + UNITS[i]

## Hora do jogo (0..24) -> "21:40".
static func clock(hour: float) -> String:
	var hh := int(hour) % 24
	var mm := int((hour - floorf(hour)) * 60.0)
	return "%02d:%02d" % [hh, mm]

## Segundos -> "1h 05m" / "4m 12s".
static func duration(sec: float) -> String:
	var s := int(maxf(0.0, sec))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm %02ds" % [s / 60, s % 60]
	return "%ds" % s

## Estrelas como texto "4.3".
static func stars(v: float) -> String:
	return "%.1f" % v
