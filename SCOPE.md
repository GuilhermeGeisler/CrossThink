# Project Vision & Scope: CrossPoint Reader (CrossThink)

CrossPoint Reader é um firmware open-source para e-readers baseados em ESP32-C3 (Xteink X4/X3). Originalmente focado exclusivamente em leitura, o projeto evoluiu para incluir ferramentas complementares, jogos leves, gamificação de hábito de leitura e funcionalidades de produtividade — tudo otimizado para as restrições de hardware (~380KB RAM, CPU single-core, display E-Ink).

## 1. Core Mission

**Fornecer uma experiência de leitura eficiente e personalizável, complementada por ferramentas úteis que não comprometam a estabilidade do dispositivo.**

O projeto aceita features além da leitura pura (jogos, calculadora, flashcards, stats de leitura, coleções), mas mantém disciplina técnica: cada feature deve funcionar dentro das limitações de RAM e CPU, sem degradar a experiência principal de leitura.

## 2. Scope

### In-Scope

*Features implementadas ou planejadas que se alinham com a missão do projeto.*

#### Leitura e Renderização
* **User Experience:** Interfaces intuitivas, mapeamento de botões, navegação em livros, bookmarks, footnotes.
* **Document Rendering:** Suporte a EPUB 2/3, XTC, TXT, BMP. Parser de CSS, hyphenation, kerning.
* **Typography & Legibility:** Fontes customizadas (builtin + SD card), incluindo as famílias adicionais **ChareInk, Lexend Deca, Bitter e Inter** portadas do CrossInk. Hyphenation engines, line spacing ajustável, focus reading.
* **E-Ink Driver Refinement:** Gerenciamento de ghosting, refresh modes (full/half/fast), grayscale support.
* **Library Management:** File browser, recent books, cache management, hidden files toggle.
* **Coleções + Bookshelf em grid:** Sistema de coleções (Favorites, Recently Added, All Books, Finished, Unopened + coleções custom) com agrupamento automático por série (`collapseSeries`), portado do CrumBLE. Ver `DETAILED_STEPS.md` item 3 para plano de integração — inicialmente como tela adicional na Home, não substituindo a tela padrão.

#### Conectividade e Transferência
* **Local Transfer:** Web server para upload/download de livros, OPDS browser, Calibre wireless connect.
* **OTA Updates:** Atualizações via GitHub releases.
* **KOReader Sync:** Sincronização de progresso de leitura com KOReader.

#### Ferramentas Complementares
* **Dictionary Lookup:** Dicionário local StarDict, portado do CrumBLE (sem a lógica de auto-disable de BLE, que não se aplica mais — ver seção 5).
* **Clock Display:** Relógio com RTC dedicado (X3) ou NTP sync (X4).
* **Flashcards SRS:** Sistema de repetição espaçada SM-2 para aprendizado. ✅ Implementado.
* **Calculadora:** Calculadora básica. ✅ Implementado.
* **Conversor de Unidades:** Conversão entre unidades de medida. ✅ Implementado.
* **Pomodoro Timer:** Timer para técnica Pomodoro. ✅ Implementado.
* **Reading Stats + Pet Virtual:** Sistema de estatísticas de leitura (streaks, heatmap, badges, "Wrapped" anual) e pet virtual que evolui com o hábito de leitura, portado do aalu. Ver `DETAILED_STEPS.md` item 5.

#### Jogos Leves
*Jogos simples que não exigem renderização em tempo real nem comprometem a RAM.*
* **Board Games:** Chess, Caro (Gomoku), Sudoku. ✅ Implementado.
* **Puzzle Games:** Minesweeper, 2048, Wordle. ✅ Implementado.

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
* **EPUB Optimizer / pré-cache client-side:** Otimização de performance (indexação pré-calculada no navegador), não uma feature visível. Baixa prioridade, avaliar depois dos itens acima estarem estáveis — ver `DETAILED_STEPS.md` item 4.
* **JPEG/PNG Native Viewer standalone:** Visualizador de imagens fora do contexto EPUB (wallpapers custom, etc). Base já suporta JPEG/PNG dentro de EPUBs. Baixa prioridade — ver `DETAILED_STEPS.md` item 7.

### In-Scope — Technically Unsupported

*Features que se alinham com objetivos mas são impraticáveis no hardware atual.*

* **BLE Page Turner:** Controle remoto via Bluetooth. Testes do CrumBLE (upstream) mostraram que NimBLE consome ~58KB de heap, causando crashes em operações de dicionário e parsing de EPUB quando ligado simultaneamente. **Removido do projeto** — decisão confirmada, não é candidato a retorno.

## 3. Hardware Constraints

O ESP32-C3 impõe limites rígidos que guiam todas as decisões de design:

| Recurso | Limite | Impacto |
|---------|--------|---------|
| **RAM** | ~380KB usable | Fragmentation mata, não total usage. Cada feature deve justificar alocações. |
| **CPU** | Single-core RISC-V @ 160MHz | No background tasks pesados. WiFi + rendering simultâneo = crash. |
| **Flash** | 16MB (7.5MB por slot OTA, ver `partitions.csv`) | Fontes builtin + jogos + dicionário + stats + coleções = espaço a monitorar, mas não é motivo pra excluir features de antemão — é motivo pra medir o binário final e ajustar build flags/variantes se necessário (ver `docs/font-build-variants.md` do CrossInk como referência de solução). |
| **Display** | 800x480 E-Ink, single buffer | No double-buffering. Grayscale requer técnicas especiais. |

### Regras de Design

1. **Heap discipline:** `makeUniqueNoThrow` sempre. Null-check + `LOG_ERR` em toda alocação falível.
2. **No background tasks:** WiFi desliga durante rendering pesado.
3. **Cache aggressively:** `.crosspoint/` no SD card para metadata, layout, covers. RAM é preciosa.
4. **Single responsibility:** Cada Activity aloca em `onEnter()`, libera em `onExit()`. No leaks.

## 4. Idea Evaluation

Novas features são avaliadas por:

1. **Cabe na RAM?** Se a feature exige >20KB de heap steady-state ou alocações grandes em hot path, precisa de plano de mitigação explícito antes de entrar em scope — não é descarte automático.
2. **Não quebra a leitura?** Se a feature pode causar crashes durante leitura (heap fragmentation, watchdog timeout), precisa resolver isso antes de ser considerada pronta (não antes de ser considerada in-scope).
3. **Cabe na flash?** Medir o binário real depois de portada. Se exceder o slot OTA, ajustar build variants antes de cortar a feature.
4. **Usuários querem?** Features devem resolver problemas reais, não ser "nice to have".

### Critério Final

> **Uma feature é in-scope se melhora a experiência de leitura OU fornece utilidade complementar, com um plano crível de caber nas limitações de RAM/flash.** Decisões de cortar uma feature por limitação de hardware são tomadas com base em medição real (heap profiling, tamanho de binário), não em estimativa a priori — e são decisão do mantenedor do projeto, não do agente que estiver ajudando a codar.

> **Note to Contributors (incluindo agentes de IA):** Não remova ou reclassifique itens deste documento por conta própria com base em estimativa de risco. Se identificar um risco técnico real (ex: heap insuficiente medido em teste), documente o achado com números concretos e proponha a mudança — não aplique a mudança direto no `SCOPE.md`.

## 5. Project History

Este projeto é um merge de múltiplos forks do CrossPoint Reader:

| Fork | Features Portadas | Status |
|------|-------------------|--------|
| **CrossPoint** (base) | Reader engine, HAL, settings, OPDS, WiFi, themes | ✅ Base |
| **CrossPet** | Flashcards SRS, Pomodoro, Clock, jogos (Chess/Caro/Sudoku/Minesweeper/2048), menu Tools com toggles | ✅ Implementado |
| **Shortbread** | Calculadora, conversor de unidades | ✅ Implementado |
| **CrossWordle** | Jogo Wordle | ✅ Implementado |
| **CrumBLE** | Dicionário StarDict, Coleções + Bookshelf (com agrupamento por série nativo) | 🔲 Planejado — ver `DETAILED_STEPS.md` itens 1 e 3 |
| **CrumBLE** | BLE (page-turner remoto) | ❌ Removido — inviável por heap (ver seção 2, "Technically Unsupported") |
| **aalu** | Stats de leitura (heatmap, badges, "Wrapped") + Pet virtual | 🔲 Planejado — ver `DETAILED_STEPS.md` item 5 |
| **CrossInk** | Fontes ChareInk, Lexend Deca, Bitter, Inter + build variants por tamanho de flash | 🔲 Planejado — ver `DETAILED_STEPS.md` item 6 |
| **inx** | Visualizador JPEG/PNG standalone | 🔲 Backlog, baixa prioridade — ver `DETAILED_STEPS.md` item 7 |

Roteiro técnico completo (arquivos-fonte, pontos de integração, riscos) de cada item pendente está em `DETAILED_STEPS.md`.