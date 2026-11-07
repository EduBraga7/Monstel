# MONSTEL — plano do jogo de gerenciamento (Godot 4.7.2 · mobile · 2D)

## Contexto

Você pediu um jogo mobile viral, divertido e viciante (nada de roguelite), em Godot 4.7, entregue **jogável**, com skills de Godot baixadas para `C:\Users\du-xb\OneDrive\Documentos\jogos\<nome do jogo>`. A primeira versão do plano era um puzzle de física; você corrigiu: quer um **jogo de gerenciamento**, tema livre. **Este plano substitui o anterior.**

**Suas respostas anteriores continuam valendo:** skills = "só o essencial" (9) · build extra = **APK Android de debug** (mais um `Jogar.bat` para rodar no PC sem baixar nada). Mudança de uma skill: `godot-2d-physics` sai e `godot-save-load-systems` entra, porque o novo jogo não usa física e depende muito de save.

**O que o PC tem** (exploração só de leitura):

| Item | Estado |
|---|---|
| Godot | **4.7.2 stable**, edição padrão (GDScript): `C:\Users\du-xb\OneDrive\Documentos\Godot\Godot_v4.7.2-stable_win64.exe` (+ `_console.exe`) |
| Pasta `jogos` | existe e está vazia |
| Blender | **não encontrado** (Program Files, Steam, Microsoft Store, registro, Downloads, D:\). Não faz falta: arte 2D gerada por código/shader |
| Export templates, JDK, Android SDK | nenhum → precisam ser baixados para o APK |
| Python / Git / Node | Python é só o atalho da Loja; sem Git nem Node → ferramentas em GDScript (Godot headless) + `.bat` |
| GPU | Radeon RX 550 → renderer *Compatibility* e capturas de tela funcionam |

## O jogo

**MONSTEL** — *"Gerencie o hotel mais assombrosamente fofo do mundo."*

Nome = monstro + hotel. Busquei na web: nenhum jogo com esse nome ("Monster Hotel" é genérico e já usado; o gênero "hotel idle" está cheio de apps iguais). O que evita ser mais um é o que está abaixo: corte transversal fofo, simulação de hóspedes com gargalos de verdade e avaliações absurdas.

**Visual:** corte transversal ("formigueiro") de uma torre assombrada em retrato. Você vê todos os andares ao mesmo tempo e os monstrinhos vivendo suas vidas. Roxo-noite, menta e abóbora, rostos expressivos, luz quente nas janelas, ciclo dia/noite.

### Como se joga
1. Hóspedes (monstros) chegam ao saguão, fazem check-in, pegam o elevador, ficam na suíte, usam facilidades (bar, buffet, spa…) e fazem check-out pagando. **Cada um deixa uma avaliação.**
2. As moedas ficam em balões sobre os quartos: **toque para coletar** (depois a equipe automatiza).
3. Com as moedas você **constrói andares**, **melhora quartos**, **contrata equipe**, **regula preços** e **melhora elevador e recepção**.
4. A **reputação (★)**, calculada das avaliações, controla quantos hóspedes chegam e quanto gastam.
5. **Metas** encadeadas sempre visíveis guiam o próximo passo (e fazem o papel de tutorial). O **nível do hotel** destrava andares, espécies e recursos.
6. Eventos: **VIP** (hóspede famoso com exigência), **Hora do Rush** (booster ativo, bom para clipes) e **Inspetor secreto**.
7. A cada "dia" (~2,5 min) sai um relatório rápido: receita, despesas, melhores avaliações.
8. **Offline:** até 8 h a 50% da renda, com "Bem-vindo de volta, gerente!" e chuva de moedas. Nunca há game over: má gestão só desacelera.

### Decisões de gerenciamento (o que faz isso ser mais que um clicker)
- **Gargalos reais:** recepção, elevador (andares altos demoram), camareiras (quarto sujo não aluga), capacidade das facilidades. O jogo mostra o gargalo ("fila na recepção!") e a solução custa dinheiro.
- **Preços:** dois controles (Suítes e Facilidades) com três posições (Barato / Justo / Luxo): demanda × reputação × lucro.
- **Equipe com salário diário:** velocidade × custo (recepcionista, camareira, mensageiro, caixa que coleta sozinho).
- **Mix de espécies com traços:** Fantasma atravessa paredes (não usa elevador, paga pouco), Zumbi é lento e paciente, Vampiro paga mais à noite, Bruxa dá gorjeta, Múmia ama spa, Lobisomem suja mais o quarto.
- **Ordem de construção:** facilidades perto do saguão encurtam viagens; o elevador vira o limite natural da torre.

### Por que vicia e por que se espalha
- Sempre há algo acessível: 2º andar em ≤ 60 s; a torre cresce visivelmente; metas com barras de progresso parciais.
- Coletar moedas é tátil (arco até o HUD, som que sobe de tom em sequência); construir, subir de nível e descobrir espécie nova têm cerimônia própria.
- Coleção: Monstrodex (espécies), avaliações favoritas, ~12 conquistas.
- Volta fácil: offline, recompensa diária com streak, 3 missões diárias, booster de Hora do Rush.
- **Motor de viralização = avaliações absurdas:** cada hóspede escreve uma review coerente com o que aconteceu na estadia (fila, sujeira, preço, espécie), em PT-BR e EN. Ex.: *"Esperei tanto no elevador que virei esqueleto. ★★"*. Cartão de avaliação com botão de compartilhar.
- Cenas fofas (fantasma atravessando parede, zumbi dormindo no buffet) rendem clipes; **Modo Foto** com o nome do seu hotel e estatísticas.
- **Não é roguelite:** um hotel persistente; sem runs, perks aleatórios ou resets. Sem anúncios, sem compras, sem internet.

### Conteúdo
- **Obrigatório (MVP):** saguão + poço de elevador; Suíte (3 níveis); 5 facilidades (Bar de Sangue, Buffet de Cérebros, Spa das Múmias, Boutique da Bruxa, Academia do Lobo); 2 de apoio (Governança, Marketing); 6 espécies; 4 funções de equipe; ~70 textos de avaliação por idioma; ~40 metas; eventos VIP/Rush/Inspetor; relatório de dia; offline; save; tutorial; Monstrodex; configurações; Modo Foto; PT-BR/EN.
- **Se der tempo:** trocar andares de lugar, 2º poço de elevador, +2 espécies (Esqueleto, Slime), papéis de parede, chuva/clima.
- **Alvos de ritmo** (a simulação de balanceamento mira nisto): 5 andares ≈ 10 min; nível 3 + 1º VIP ≈ 15 min; ~10 andares e 4★ em ~1 h; ~15 andares no fim do dia 1; ~30 andares e quase tudo no dia 7 (com offline). Custo de andar cresce ×1,3–1,5.

## Arquitetura técnica

Projeto em `C:\Users\du-xb\OneDrive\Documentos\jogos\Monstel\`. GDScript tipado, renderer **Compatibility**, retrato 1080×1920 (`canvas_items` + `expand`, safe-area), `emulate_touch_from_mouse` (mouse = toque no PC). Sem física.

```
Monstel/
  project.godot  export_presets.cfg  icon.svg  Jogar.bat  Abrir-no-Editor.bat
  README.md  CLAUDE.md  .gitignore
  .claude/skills/<9 skills> + SOURCES.md + .gdignore
  assets/fonts (Fredoka)   assets/audio (SFX e trilha gerados)
  shaders/            céu · brilho de janela · vinheta
  scripts/data/       rooms · species · staff · upgrades · goals · achievements
  scripts/sim/        state · hotel · guest · staff · room · elevator · economy
                      reputation · reviews · events · goals · offline   (sem nós)
  scripts/view/       tower_view · floor_view · monster_art · monster_view · coin_view · fx · camera_rig
  scripts/ui/         theme · hud · sheets (construir/quarto/equipe/hotel) · reviews · monstrodex
                      goals · settings · popups · tutorial · photo_mode
  scripts/autoload/   app · save · loc · audio · haptics · share
  data/               i18n.json · reviews.json
  tools/              gen_audio.gd · gen_icon.gd · dev.bat
  tests/              econ_sim.gd · stress.gd · shots.gd
  builds/             Monstel-debug.apk
```

Decisões-chave:
- **Simulação separada da tela:** `scripts/sim/` é GDScript puro (sem nós), passo fixo, semente própria. Roda headless e muito mais rápido que o tempo real, é testável por bots e sustenta o offline (que usa a taxa de renda medida, sem re-simular horas).
- **Entidades simples e à prova de trava:** Guest e Staff são máquinas de estado com *tempo-limite de segurança* (hóspede preso é reencaminhado e registrado); elevador estilo SCAN com capacidade, velocidade e fila por andar.
- **Tela leve:** andares estáticos desenhados uma vez (`_draw` só quando mudam); monstros animados a ~20 fps, ≤ ~60 ativos; câmera vertical com inércia e zoom por botões.
- **Arte 100% por código:** formas arredondadas, rostos e adereços por espécie, shaders de céu/vinheta/brilho. No 4.7 as linhas do `_draw` perderam o anti-aliasing (notas de migração 4.6→4.7), então uso polígonos/círculos e traços ≥ 4 px.
- **UI em código** com tema único (Fredoka variável), *bottom sheets* animadas, safe-area; textos via `Loc`; avaliações em `data/reviews.json` (fácil de editar).
- **Save:** JSON versionado, escrita atômica + backup; autosave a cada 15 s e ao pausar/perder foco.
- **Áudio** sintetizado offline por `tools/gen_audio.gd` (moeda que sobe de tom, "ding" do elevador, construção, fanfarras, música ambiente fofa-sombria); vibração em coletas e eventos.
- **Android:** permissão VIBRATE, share de texto via `JavaClassWrapper` (alternativa: copiar), botão Voltar fecha painel/pausa, APK só arm64-v8a.
- **Orçamento:** 60 FPS, < 300 draw calls, sem alocação por frame nos caminhos quentes.

**As 9 skills** (em `Monstel\.claude\skills\`, com `SOURCES.md` de origem/commit/licença): `godot-gdscript-patterns` (wshobson/agents, MIT) e, de thedivergentai/Game-Dev-Agentic-Skills (LGPL-3.0), `godot-project-foundations`, `godot-save-load-systems`, `godot-input-handling`, `godot-ui-containers`, `godot-audio-systems`, `godot-tweening`, `godot-platform-mobile`, `godot-export-builds`.

## Marcos, verificação e plano B

| # | Entrega | Verificação / portão |
|---|---|---|
| M0 | Pasta `Monstel` (via `change_directory`), 9 skills baixadas → revisadas → instaladas, fonte, `CLAUDE.md`, `.bat`s | `Godot --headless --path . --import` sem erros |
| M1 | **Simulação headless:** quartos, hóspedes, elevador, economia, reputação, reviews | Portão: bot "ROI guloso" por 10 h simuladas sem hóspede preso, dinheiro e reputação sempre válidos, marcos de ritmo dentro de ±30% dos alvos; bot inativo por 2 h sem erro nem dívida. **Se o elevador/filas travarem:** simplifico para fluxo analítico (a tela continua igual) |
| M2 | **Fatia jogável:** torre na tela, câmera, coletar moedas, construir e melhorar, HUD | Capturas de tela + entrada simulada por 5 min |
| M3 | Equipe, preços, VIP/Rush/Inspetor, metas e tutorial, relatório de dia | Sims + capturas |
| M4 | Arte e juice finais, dia/noite, áudio, haptics | Capturas revisadas por mim |
| M5 | Casca: nome do hotel, Monstrodex, avaliações + share, Modo Foto, conquistas, diário, config, i18n, offline | Testes de save e offline; navegação por capturas |
| M6 | Balanceamento e QA | Sims de ritmo; estresse com ~60 monstros; 3 proporções de tela |
| M7 | **APK debug** | instalar JDK/SDK/templates; **parar e pedir sua confirmação das licenças do Android SDK** antes de aceitá-las; keystore de debug local; preset Android (retrato, VIBRATE, ícone gerado); `--export-debug`; `apksigner verify`. Se você plugar um celular com depuração USB, instalo e abro por `adb` |
| M8 | Entrega: README PT-BR, árvore final, resumo do que foi e do que não foi testado | `Jogar.bat` abre o jogo; 60 s de jogo com log limpo |

**Linha de corte:** se o prazo apertar, caem primeiro os itens de "se der tempo". M1–M5 são o núcleo e não negociam.

## Downloads e instalações (aprovar este plano autoriza exatamente estes)

| O quê | Fonte oficial | Tamanho | Destino |
|---|---|---|---|
| 9 skills (markdown + exemplos `.gd`; nada executável será instalado) | `github.com/thedivergentai/Game-Dev-Agentic-Skills` e `github.com/wshobson/agents`, só as pastas das 9 skills (API/raw do GitHub, sem `npx`) | < 1 MB | quarentena em pasta temporária; só depois de eu ler tudo vão para `Monstel\.claude\skills\` |
| Fonte Fredoka + `OFL.txt` | `github.com/google/fonts` (`ofl/fredoka`) | 155 KB | `Monstel\assets\fonts\` |
| Export templates do Godot 4.7.2 | `downloads.godotengine.org` (link da página oficial 4.7.2-stable) | ~1 GB (a página não informa) | `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| JDK 17 (zip, sem instalador) | Eclipse Temurin (`adoptium.net`) | ~190 MB | `%LOCALAPPDATA%\Android\jdk-17` |
| Android command-line tools + pacotes via `sdkmanager` (platform-tools, build-tools 35.0.1, platform android-35, CMake 3.10.2.4988404, NDK 28.1.13356709: confirmo as versões na doc 4.7) | `dl.google.com` | ~2–3 GB | `%LOCALAPPDATA%\Android\Sdk` |

Sem instalador, sem admin, sem mexer no PATH nem em configurações do Windows. Só gravo os caminhos do JDK/SDK nas configurações do editor Godot (`editor_settings-4.7.tres`).

## Verificação ponta a ponta

1. `Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` e rodada curta com `--quit-after`: log sem erro nem aviso de script.
2. `tests/econ_sim.gd` headless: bot guloso e bot inativo, várias sementes → JSON (andares/hora, renda, reputação, hóspedes presos, dívida). `tests/stress.gd`: torre cheia, ms por passo e nós ao fim.
3. Save → recarregar → estado idêntico; offline de N horas bate com a simulação dentro de tolerância.
4. Capturas de tela com janela real (`tests/shots.gd`): saguão vazio, torre média, torre cheia em hora do rush, painéis, avaliações, Modo Foto, em 1080×1920, 1080×2400 e 1536×2048; eu abro e reviso.
5. APK: export + `apksigner verify` (+ `adb install` se houver aparelho).
6. Fechamento: abrir pelo `Jogar.bat`, jogar 60 s, conferir o log.

## Riscos e limites

- **Escopo grande** (gênero pesado em UI e conteúdo): fatias verticais, conteúdo em tabelas de dados, componentes de UI reutilizáveis e linha de corte definida.
- **Balanceamento sem playtest humano:** mirado por simulação; todas as constantes ficam em `scripts/data/` para ajuste fácil.
- **Humor depende de texto:** escrevo PT-BR e EN; você ajusta `data/reviews.json`.
- **Não consigo ouvir o áudio nem sentir o game feel no celular;** o APK não será testado em aparelho (a menos que você plugue um). Peço seu feedback depois de jogar.
- A pasta está dentro do OneDrive: `.godot/` e `builds/` geram muitos arquivos; se a sincronização atrapalhar, pause o OneDrive enquanto eu trabalho (não movo nada sem você pedir).
- iOS é impossível sem um Mac. Blender não foi encontrado, mas não faz falta.
- **Tema trocável:** espécies, quartos e textos são dados. Se preferir outro tema (café de gatos, onsen de capivaras…), a engine é a mesma.

## Primeiras ações depois da aprovação

1. `change_directory` para `C:\Users\du-xb\OneDrive\Documentos\jogos` (você aprova a pasta) e criar `Monstel\`.
2. Salvar na memória: caminho do Godot 4.7.2, pasta `jogos`, e que o Blender não está instalado.
3. M0 → M1 (portão da simulação) → M2 … M8, atualizando a lista de tarefas a cada marco.
