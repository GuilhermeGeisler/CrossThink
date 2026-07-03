# CrossThink — Firmware Unificado para E-Readers ESP32-C3

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

CrossThink é um firmware open-source para e-readers baseados em ESP32-C3 (Xteink X4/X3), resultado da unificação de múltiplos forks do projeto CrossPoint Reader. Combina a experiência de leitura robusta do CrossPoint com ferramentas complementares, jogos leves e funcionalidades de produtividade — tudo otimizado para as restrições de hardware (380KB RAM, CPU single-core, display E-Ink 800x480).

![CrossPoint Reader](./docs/images/cover.jpg)

## 🎯 Visão do Projeto

**Fornecer uma experiência de leitura eficiente e personalizável, complementada por ferramentas úteis que não comprometam a estabilidade do dispositivo.**

Diferente do CrossPoint original (focado exclusivamente em leitura), o CrossThink aceita features além da leitura pura, mas mantém disciplina técnica: cada feature deve funcionar dentro das limitações de RAM e CPU, sem degradar a experiência principal.

## ✨ Features

### Leitura e Renderização
- **Formatos suportados:** EPUB 2/3, XTC, TXT, BMP
- **Renderização avançada:** Parser de CSS, hyphenation, kerning, footnotes
- **Fontes customizadas:** Builtin (Noto Serif/Sans, Ubuntu) + SD card (.cpfont)
- **E-Ink optimization:** Refresh modes (full/half/fast), grayscale support, ghosting management
- **Navegação:** Bookmarks, chapter selection, go-to-percent, auto page turn

### Conectividade
- **Transferência wireless:** Web server, OPDS browser, Calibre wireless connect
- **OTA updates:** Atualizações via GitHub releases
- **KOReader sync:** Sincronização de progresso de leitura

### Ferramentas Complementares
- **Flashcards SRS:** Sistema de repetição espaçada SM-2 para aprendizado
- **Calculadora:** Calculadora básica
- **Conversor de unidades:** Conversão entre unidades de medida
- **Pomodoro timer:** Timer para técnica Pomodoro
- **Relógio:** RTC dedicado (X3) ou NTP sync (X4)

### Jogos Leves
- **Board games:** Chess, Caro (Gomoku), Sudoku
- **Puzzle games:** Minesweeper, 2048, Wordle

### Customização
- **Themes:** Classic, Lyra, Lyra Extended, RoundedRaff
- **Sleep screen:** Modos configuráveis (dark, light, cover, custom)
- **Button remapping:** Remapeamento de botões frontais e laterais
- **Status bar:** Configuração de progresso, relógio, bateria
- **i18n:** 26 idiomas suportados

## 🚧 Estado Atual

**Este projeto está em fase de integração.** O código foi unificado de múltiplos forks, mas ainda precisa de:

- ✅ Compilação validada (`pio run`)
- ✅ Testes em hardware real (X4/X3)
- ✅ Submódulo `freeink-sdk` inicializado
- ⏳ Features planejadas (dicionário, stats simples)

Veja [DETAILED_STEPS.md](./DETAILED_STEPS.md) para o roadmap de integração e [SCOPE.md](./SCOPE.md) para decisões de escopo.

## 🔧 Hardware Suportado

| Device | CPU | RAM | Display | RTC |
|--------|-----|-----|---------|-----|
| **Xteink X4** | ESP32-C3 @ 160MHz | ~380KB | 800x480 E-Ink | Internal (drift) |
| **Xteink X3** | ESP32-C3 @ 160MHz | ~380KB | 800x480 E-Ink | DS3231 (accurate) |

### Limitações Críticas

- **RAM:** 380KB usable, sem PSRAM. Fragmentation mata, não total usage.
- **Flash:** 16MB total, 7.5MB por slot OTA. Espaço é crítico.
- **CPU:** Single-core. No background tasks pesados durante leitura.
- **Display:** Single buffer (48KB). No double-buffering.

## 📦 Instalação

### Pré-requisitos

- [PlatformIO](https://platformio.org/) ou VS Code + PlatformIO extension
- Python 3.8+
- `clang-format` 21
- Cabo USB-C com suporte a dados

### Setup

```bash
git clone --recursive https://github.com/GuilhermeGeisler/CrossThink.git
cd CrossThink

# Se clonou sem --recursive:
git submodule update --init --recursive
```

### Build e Flash

```bash
# Build (verifica compilação)
pio run

# Build + upload para o device
pio run --target upload

# Monitor serial output
pio device monitor
```

### Debugging

```bash
# Monitor com cores e formatação
python3 scripts/debugging_monitor.py

# Linux (detecta porta automaticamente)
python3 scripts/debugging_monitor.py

# macOS (especifica porta)
python3 scripts/debugging_monitor.py /dev/cu.usbmodem2101
```

## 🏗️ Arquitetura

### Estrutura de Diretórios

```
CrossThink/
├── src/
│   ├── activities/          # UI screens (Activity pattern)
│   │   ├── home/           # Home, FileBrowser, RecentBooks
│   │   ├── reader/         # EPUB/XTC/TXT readers
│   │   ├── settings/       # Settings screens
│   │   ├── games/          # Chess, Sudoku, Minesweeper, etc.
│   │   ├── flashcard/      # Flashcards SRS
│   │   └── apps/           # Tools menu (calculator, pomodoro, etc.)
│   ├── components/         # UI themes (UITheme, BaseTheme)
│   ├── network/            # Web server, OTA, WebDAV
│   └── util/               # Helpers (ButtonNavigator, StringUtils)
├── lib/
│   ├── hal/                # Hardware Abstraction Layer
│   ├── GfxRenderer/        # Rendering engine
│   ├── Epub/               # EPUB parser
│   ├── EpdFont/            # Font system (builtin + SD card)
│   ├── I18n/               # Internationalization (26 languages)
│   └── [outros libs]       # Serialization, Memory, Logging, etc.
├── freeink-sdk/            # SDK de hardware (submódulo git)
├── scripts/                # Build scripts, generators
└── docs/                   # Documentação
```

### Padrões de Design

- **Activity Lifecycle:** `onEnter()` aloca, `onExit()` libera. No leaks.
- **HAL (Hardware Abstraction Layer):** Todo acesso a hardware via `HalStorage`, `HalGPIO`, `HalDisplay`.
- **Singletons:** `SETTINGS`, `APP_STATE`, `GUI`, `Storage`, `I18N`.
- **Heap discipline:** `makeUniqueNoThrow` sempre. Null-check + `LOG_ERR` em toda alocação falível.

### Cache

O firmware faz cache agressivo no SD card para minimizar uso de RAM:

```
.crosspoint/
├── epub_<hash>/          # Cache por livro
│   ├── book.bin          # Metadata (title, author, spine)
│   ├── progress.bin      # Posição de leitura
│   ├── cover.bmp         # Cover gerada
│   └── sections/         # Layout por capítulo
├── settings.json         # Configurações do device
├── state.json            # Estado runtime
└── recent.json           # Livros recentes
```

## 📚 Documentação

- [SCOPE.md](./SCOPE.md) — Decisões de escopo (in-scope vs out-of-scope)
- [DETAILED_STEPS.md](./DETAILED_STEPS.md) — Roadmap de integração de features
- [USER_GUIDE.md](./USER_GUIDE.md) — Guia do usuário
- [docs/](./docs/) — Documentação técnica
  - [file-formats.md](./docs/file-formats.md) — Formatos de cache
  - [webserver.md](./docs/webserver.md) — Web server usage
  - [i18n.md](./docs/i18n.md) — Internacionalização
  - [simulator.md](./docs/simulator.md) — Simulador desktop

## 🤝 Contribuindo

Contribuições são bem-vindas! Antes de começar:

1. **Leia o SCOPE.md** — entenda o que é in-scope vs out-of-scope
2. **Abra uma Discussion** — se não tem certeza se sua ideia fits
3. **Inclua estimativas** — RAM/flash usage na proposta
4. **Teste em hardware** — se possível, antes de abrir PR

### Pre-PR Checklist

```bash
# Formatação
./bin/clang-format-fix

# Análise estática
pio check -e default

# Build
pio run -e default

# Simulador (opcional)
pio run -e simulator
```

## 📜 Licença

MIT License — veja [LICENSE](./LICENSE) para detalhes.

## 🙏 Agradecimentos

Este projeto é um merge de múltiplos forks do CrossPoint Reader:

| Fork | Contribuições |
|------|---------------|
| **[CrossPoint](https://github.com/crosspoint-reader/crosspoint-reader)** | Base: reader engine, HAL, settings, OPDS, WiFi, themes |
| **[CrossPet](https://github.com/trilwu/crosspet)** | Flashcards SRS, Pomodoro, menu Tools |
| **Shortbread** | Calculadora, conversor de unidades |
| **[CrossWordle](https://github.com/...)** | Jogo Wordle |
| **CrumBLE** | Dicionário StarDict (planejado) |
| **aalu** | Stats simples (planejado) |
| **[CrossInk](https://github.com/uxjulia/CrossInk)** | Inspiração para fontes alternativas |
| **[inx](https://github.com/obijuankenobiii/inx)** | Inspiração para JPEG/PNG viewer |

Agradecimento especial ao projeto [diy-esp32-epub-reader](https://github.com/atomic14/diy-esp32-epub-reader), que inspirou o CrossPoint original.

## ⚠️ Aviso Legal

**CrossThink NÃO é afiliado com Xteink ou qualquer fabricante de hardware.**

Alguns dispositivos Xteink comprados de terceiros (AliExpress) podem vir com USB flashing bloqueado. Use o [Xteink Unlocker](https://crosspointreader.com/#unlock-tool) apenas se necessário. Dispositivos comprados diretamente de xteink.com não são bloqueados.

**Apenas firmwares oficialmente suportados no unlock tool:** CrossPoint e CrossInk. Flashar outros firmwares em dispositivos bloqueados pode brickar permanentemente o device.

---

**Feito com ❤️ pela comunidade open-source**

[Reportar bug](https://github.com/GuilhermeGeisler/CrossThink/issues) · [Sugerir feature](https://github.com/GuilhermeGeisler/CrossThink/discussions) · [Documentação](./docs/)
