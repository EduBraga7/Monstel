# Origem das skills

Baixadas em 2026-11-07 de repositórios públicos do GitHub (API/raw, sem `npx`). Antes de instalar, todos os arquivos passaram por varredura (comandos de rede/execução, links externos, frases de injeção de prompt) e cada `SKILL.md` teve o cabeçalho lido. O resultado foi limpo: os links são só de docs.godotengine.org e github.com, e as menções a `OS.execute` aparecem apenas em exemplos de script de editor.

**Não foram instalados scripts executáveis** (`.ps1`, `.sh`, `.py`, `.yml`): 7 arquivos da skill `godot-export-builds` ficaram de fora, então alguns links dentro do `SKILL.md` dela apontam para arquivos que não existem aqui. Os exemplos `.gd` ficam inertes: esta pasta tem `.gdignore` (o Godot não a carrega) e não entra no export.

| Skill | Origem | Commit | Licença |
|---|---|---|---|
| godot-gdscript-patterns | github.com/wshobson/agents — `plugins/game-development/skills/godot-gdscript-patterns` | 4bde3168b43c0655c4d00ea2726e631719908a6d (2026-11-05) | MIT |
| godot-project-foundations | github.com/thedivergentai/Game-Dev-Agentic-Skills — `skills/godot-project-foundations` | db004d74c40686ca2f7a35fe067b119a9cda593e (2026-10-16) | LGPL-3.0 |
| godot-save-load-systems | idem — `skills/godot-save-load-systems` | idem | LGPL-3.0 |
| godot-input-handling | idem — `skills/godot-input-handling` | idem | LGPL-3.0 |
| godot-ui-containers | idem — `skills/godot-ui-containers` | idem | LGPL-3.0 |
| godot-audio-systems | idem — `skills/godot-audio-systems` | idem | LGPL-3.0 |
| godot-tweening | idem — `skills/godot-tweening` | idem | LGPL-3.0 |
| godot-platform-mobile | idem — `skills/godot-platform-mobile` | idem | LGPL-3.0 |
| godot-export-builds | idem — `skills/godot-export-builds` (sem os 7 scripts executáveis) | idem | LGPL-3.0 |

Textos das licenças em `_licenses/`.
