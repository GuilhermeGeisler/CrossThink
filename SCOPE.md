# Project Vision & Scope: CrossPoint Reader

CrossPoint Reader é um firmware open-source para e-readers baseados em ESP32-C3 (Xteink X4/X3). Originalmente focado exclusivamente em leitura, o projeto evoluiu para incluir ferramentas complementares, jogos leves e funcionalidades de produtividade — tudo otimizado para as restrições de hardware (380KB RAM, CPU single-core, display E-Ink).

## 1. Core Mission

**Fornecer uma experiência de leitura eficiente e personalizável, complementada por ferramentas úteis que não comprometam a estabilidade do dispositivo.**

O projeto aceita features além da leitura pura (jogos, calculadora, flashcards), mas mantém disciplina técnica: cada feature deve funcionar dentro das limitações de RAM e CPU, sem degradar a experiência principal de leitura.

## 2. Scope

### In-Scope

*Features implementadas ou planejadas que se alinham com a missão do projeto.*

#### Leitura e Renderização
* **User Experience:** Interfaces intuitivas, mapeamento de botões, navegação em livros, bookmarks, footnotes.
* **Document Rendering:** Suporte a EPUB 2/3, XTC, TXT, BMP. Parser de CSS, hyphenation, kerning.
* **Typography & Legibility:** Fontes customizadas (builtin + SD card), hyphenation engines, line spacing ajustável, focus reading.
* **E-Ink Driver Refinement:** Gerenciamento de ghosting, refresh modes (full/half/fast), grayscale support.
* **Library Management:** File browser, recent books, cache management, hidden files toggle.

#### Conectividade e Transferência
* **Local Transfer:** Web server para upload/download de livros, OPDS browser, Calibre wireless connect.
* **OTA Updates:** Atualizações via GitHub releases.
* **KOReader Sync:** Sincronização de progresso de leitura com KOReader.

#### Ferramentas Complementares
* **Dictionary Lookup:** Dicionário local StarDict (planejado).
* **Clock Display:** Relógio com RTC dedicado (X3) ou NTP sync (X4).
* **Flashcards SRS:** Sistema de repetição espaçada SM-2 para aprendizado.
* **Calculadora:** Calculadora básica.
* **Conversor de Unidades:** Conversão entre unidades de medida.
* **Pomodoro Timer:** Timer para técnica Pomodoro.

#### Jogos Leves
*Jogos simples que não exigem renderização em tempo real nem comprometem a RAM.*
* **Board Games:** Chess, Caro (Gomoku), Sudoku.
* **Puzzle Games:** Minesweeper, 2048, Wordle.

#### Customização
* **Themes:** Múltiplos temas visuais (Classic, Lyra, RoundedRaff).
* **Sleep Screen:** Modos configuráveis (dark, light, cover, custom).
* **Button Remapping:** Remapeamento de botões frontais e laterais.
* **Status Bar:** Configuração de barra de status (progresso, relógio, bateria).
* **i18n:** Suporte a 26 idiomas.

### Out-of-Scope

*Features rejeitadas por comprometerem estabilidade, performance ou missão do projeto.*

* **Active Connectivity:** RSS readers, news aggregators, web browsers. Background Wi-Fi tasks drenam bateria e complicam execução em CPU single-core.
* **Media Playback:** Audio players, audiobooks. Hardware não suporta áudio.
* **Complex Annotation:** Notas digitadas. Melhor suited para dispositivos com input capabilities superiores.
* **PDF Rendering:** PDFs são fixed-layout, requerem panning/zooming constante — UX pobre em E-Ink.
* **Virtual Pet:** Sistema de pet virtual com evolução (considerado muito complexo para RAM disponível).
* **Reading Stats Avançadas:** Heatmaps, badges, "Wrapped" anual. Sistema de stats simples pode ser considerado, mas features avançadas são out-of-scope.
* **Collections/Bookshelf:** Sistema de coleções com grid view e series collapsing. Substituiria a Home atual — mudança muito grande de UX.
* **EPUB Optimizer:** Pré-cache de layout via navegador. Otimização de performance, não feature visível.

### In-Scope — Technically Unsupported

*Features que se alinham com objetivos mas são impraticáveis no hardware atual.*

* **BLE Page Turner:** Controle remoto via Bluetooth. Testes mostraram que NimBLE consome ~58KB de heap, causando crashes em operações de dicionário e parsing de EPUB. Removido do projeto.
* **Multiple Font Families (CrossInk):** Fontes ChareInk, Lexend Deca, Bitter, Inter. ~180 arquivos de fonte adicionais excederiam espaço de flash disponível (7.5MB por slot OTA).
* **JPEG/PNG Native Viewer:** Visualizador de imagens standalone fora do contexto EPUB. Base já suporta JPEG/PNG dentro de EPUBs; viewer standalone é low priority.

## 3. Hardware Constraints

O ESP32-C3 impõe limites rígidos que guiam todas as decisões de design:

| Recurso | Limite | Impacto |
|---------|--------|---------|
| **RAM** | ~380KB usable | Fragmentation mata, não total usage. Cada feature deve justificar alocações. |
| **CPU** | Single-core RISC-V @ 160MHz | No background tasks pesados. WiFi + rendering simultâneo = crash. |
| **Flash** | 16MB (7.5MB por slot OTA) | Fontes builtin + jogos + dicionário + features = espaço crítico. |
| **Display** | 800x480 E-Ink, single buffer | No double-buffering. Grayscale requer técnicas especiais. |

### Regras de Design

1. **Heap discipline:** `makeUniqueNoThrow` sempre. Null-check + `LOG_ERR` em toda alocação falível.
2. **No background tasks:** WiFi desliga durante rendering pesado. BLE removido por conflito de heap.
3. **Cache aggressively:** `.crosspoint/` no SD card para metadata, layout, covers. RAM é preciosa.
4. **Single responsibility:** Cada Activity aloca em `onEnter()`, libera em `onExit()`. No leaks.

## 4. Idea Evaluation

Novas features são avaliadas por:

1. **Cabe na RAM?** Se a feature exige >20KB de heap steady-state ou alocações grandes em hot path, é out-of-scope.
2. **Não quebra a leitura?** Se a feature pode causar crashes durante leitura (heap fragmentation, watchdog timeout), é out-of-scope.
3. **Cabe na flash?** Se adicionar a feature excede 7.5MB de firmware, é out-of-scope.
4. **Usuários querem?** Features devem resolver problemas reais, não ser "nice to have".

### Critério Final

> **Uma feature é in-scope se melhora a experiência de leitura OU fornece utilidade complementar sem comprometer estabilidade, performance ou espaço.**

Jogos leves, calculadora e flashcards são in-scope porque:
- Usam <10KB de heap steady-state
- Não rodam em background durante leitura
- São opt-in (toggles no menu Tools)
- Não degradam a experiência principal

> **Note to Contributors:** Se não tem certeza se sua ideia fits no scope, abra uma **Discussion** antes de codificar. Inclua estimativa de RAM/flash usage na proposta.

## 5. Project History

Este projeto é um merge de múltiplos forks do CrossPoint Reader:

| Fork | Features Portadas |
|------|-------------------|
| **CrossPoint** (base) | Reader engine, HAL, settings, OPDS, WiFi, themes |
| **CrossPet** | Flashcards SRS, Pomodoro, menu Tools com toggles |
| **Shortbread** | Calculadora, conversor de unidades |
| **CrossWordle** | Jogo Wordle |
| **CrumBLE** | (parcial) Dicionário StarDict planejado; BLE removido |
| **aalu** | (parcial) Stats simples planejado; pet virtual out-of-scope |
| **CrossInk** | (não portado) Fontes alternativas out-of-scope por flash |
| **inx** | (não portado) JPEG/PNG viewer out-of-scope |

Features não portadas estão documentadas em `DETAILED_STEPS.md` com rationale de exclusão.
