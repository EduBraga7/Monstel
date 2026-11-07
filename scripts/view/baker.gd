class_name Baker
extends RefCounted
## Pré-renderiza arte estática (andares, cenário) em texturas com mipmaps.
## Um andar desenhado "ao vivo" gera ~100 draw calls por quadro; já pintado numa textura vira 1.
## Os pedidos são atendidos em fila (um por vez) e as texturas ficam num cache por chave,
## então andares iguais (mesmo tipo, nível e poços) dividem a mesma imagem.
## Sem renderer (modo headless) não faz nada e quem pediu continua desenhando ao vivo.

static var cache: Dictionary = {}          # chave -> ImageTexture
static var _jobs: Array = []
static var _waiting: Dictionary = {}       # chave -> Array[Callable]
static var _running := false
static var _premult: CanvasItemMaterial = null

static func available() -> bool:
	return DisplayServer.get_name() != "headless"

## Nenhum trabalho pendente (usado pelas capturas de QA para esperar o fim).
static func idle() -> bool:
	return _jobs.is_empty() and not _running

## Material para desenhar imagens que têm partes translúcidas (o SubViewport entrega cor já multiplicada pelo alfa).
static func premult_material() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult

## Solta tudo (ao fechar o jogo).
static func release() -> void:
	cache.clear()
	_jobs.clear()
	_waiting.clear()
	_premult = null

## Pede a textura da `key`. Se já existe, chama `done(textura)` na hora; senão enfileira o trabalho.
## `make` devolve o nó "pintor" (Node2D que desenha a arte; seu 0,0 vira o canto da imagem).
## `size` é o tamanho da arte em unidades de mundo; `scale` = texels por unidade.
static func request(key: String, size: Vector2, scale: float, make: Callable, done: Callable) -> void:
	if not available():
		return
	if cache.has(key):
		done.call(cache[key])
		return
	if _waiting.has(key):
		(_waiting[key] as Array).append(done)
		return
	_waiting[key] = [done]
	_jobs.append({"key": key, "size": size, "scale": scale, "make": make})
	_pump()

static func _pump() -> void:
	if _running:
		return
	_running = true
	var tree := Engine.get_main_loop() as SceneTree
	while not _jobs.is_empty():
		var job: Dictionary = _jobs.pop_front()
		var size: Vector2 = job["size"]
		var sc: float = job["scale"]
		var sv := SubViewport.new()
		sv.size = Vector2i(ceili(size.x * sc), ceili(size.y * sc))
		sv.transparent_bg = true
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		var holder := Node2D.new()
		holder.scale = Vector2(sc, sc)
		sv.add_child(holder)
		holder.add_child((job["make"] as Callable).call())
		tree.root.add_child(sv)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		sv.queue_free()
		var key: String = job["key"]
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			var tex := ImageTexture.create_from_image(img)
			cache[key] = tex
			for cb in _waiting.get(key, []):
				var c: Callable = cb
				if c.is_valid():                  # quem pediu pode ter sido liberado (troca de tela)
					c.call(tex)
		_waiting.erase(key)
	_running = false
