extends Node
## Vibração (autoload "Haptics"). Só age em aparelhos móveis e quando está ligada nas configurações.

var enabled := true

func tap(ms: int = 15) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
