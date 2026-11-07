# Monstel — guia para o Claude

Jogo mobile de **gerenciamento** (hotel de monstros em corte transversal): Godot 4.7.2, GDScript tipado, 2D, retrato 1080×1920, renderer Compatibility. Plano aprovado: `docs/PLANO.md`. Visão geral, controles e resultados dos testes: `README.md`.

## Ambiente (máquina do usuário)
- Godot 4.7.2: `C:\Users\du-xb\OneDrive\Documentos\Godot\Godot_v4.7.2-stable_win64.exe` (GUI) e `..._console.exe` (CLI).
- Sem Blender, Python real, Git ou Node. Ferramentas internas = GDScript headless + `.bat`.
- Android já instalado (sem instalador, sem PATH): JDK 17 em `%LOCALAPPDATA%\Android\jdk-17`, SDK em `%LOCALAPPDATA%\Android\Sdk`
  (cmdline-tools, platform-tools, build-tools 35.0.1, android-35; sem NDK/CMake: não são necessários para APK sem Gradle),
  templates em `%APPDATA%\Godot\export_templates\4.7.2.stable` (Android + Windows), chave de debug em `%APPDATA%\Godot\keystores\debug.keystore`.
- A pasta está dentro do OneDrive: `.godot/` e `builds/` geram muitos arquivos.

## Comandos
- `tools\dev.bat import` → `--headless --import` (rode depois de criar/renomear scripts com `class_name`).
- `tools\dev.bat run` → abre o jogo. `Jogar.bat` / `Abrir-no-Editor.bat` na raiz.
- `tools\dev.bat script res://tests/econ_sim.gd --hours=3 --policy=greedy --seed=2` → bot de economia sem janela.
- `tools\build_apk.bat` → `builds\Monstel-debug.apk`. `tools\install_apk.bat` → instala por USB (adb).
- QA visual/automático (janela real): `Godot_console --path . -- --shots --scenario=<early|mid|late|menu|name|offline|taps|persist|stress|gallery> [--out=pasta] [--w=1080 --h=1920]`.
  Os testes imprimem `PASS`/`FAIL` e `FALHAS: n`. O ShotRunner usa `Save.test_mode` (não grava save) — mas `--autoplay` e o jogo normal GRAVAM em `user://`.

## Arquitetura
- `scripts/sim/` — simulação pura (`RefCounted`), **sem nós e sem autoloads**, passo fixo `Balance.DT`. Roda headless e sustenta o offline.
- `scripts/data/` — tabelas e constantes (balance, geometria, espécies, quartos, equipe, metas).
- `scripts/view/` — torre e monstros (`Node2D`, `_draw` procedural). `Baker` pré-renderiza andares e cenário em texturas (cache por chave, fila de 1 por vez; sem renderer/headless cai no desenho ao vivo). `scripts/ui/` — HUD e painéis em código, tema único (Fredoka).
- `scripts/autoload/` — Loc, Sfx, Haptics, Save (nessa ordem no project.godot).
- Texto de interface só via `Loc` (`data/i18n.json`, PT e EN com as mesmas chaves); avaliações em `data/reviews.json` (a sim guarda só ids/sementes, nunca texto).

## Regras e armadilhas
- Godot 4.7: linhas do `_draw` perderam o anti-aliasing → polígonos/círculos e traços ≥ 4 px. Sem MSAA 2D no Compatibility (por isso o atlas 2× dos monstros).
- `draw_set_transform` SUBSTITUI a transformação (não compõe). `:=` não infere de Variant (elemento de Dictionary/Array). `match` dentro de lambda multilinha quebra o parser → use `Callable.bind`.
- Modos `--script`/`--check-only` não enxergam os autoloads (`Loc`, `Save`...): teste pela cena principal ou pelo ShotRunner.
- Exportação: `.json` NÃO entra no pacote sem `include_filter="data/*.json"` (já está no `export_presets.cfg`). Android exige `textures/vram_compression/import_etc2_astc=true`.
- Android: `config/quit_on_go_back=false` (o jogo trata o botão Voltar) e `pointing/android/enable_pan_and_scale_gestures=true` (pinça).
- Estado do jogo mora em `Hotel` (sim), nunca em nós; save em JSON versionado com backup.
- Mexeu em balanceamento? Rode `tests/econ_sim.gd` e compare com os alvos de ritmo do plano.
- Mexeu na arte estática de um andar/cenário? Ela é pré-renderizada: a chave do cache (`FloorView._bake_key`) precisa incluir tudo que muda o desenho.
- Skills de referência em `.claude/skills` (origem em `SOURCES.md`). A pasta `.claude` tem `.gdignore`.
