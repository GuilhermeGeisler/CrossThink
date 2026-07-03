# xteink-merged-firmware — Status da mesclagem

## O que já está pronto e integrado (testável, mas não compilado em hardware)

Base: fork limpo do `crosspoint-reader` oficial.

✅ **Jogos** (portados do `crosspet`, mesmo padrão de Activity da base):
   Xadrez, Caro, Sudoku, Minesweeper, 2048

✅ **Wordle** (portado do `CrossWordle`, com `wordles.json`/`nonwordles.json`)

✅ **Calculadora e Conversor de Unidades** (portados do `shortbread`)

✅ **Flashcards com repetição espaçada SM-2** (portados do `crosspet`, sistema
   completo: deck picker, review, SRS, settings)

✅ **Relógio e Pomodoro** (portados do `crosspet`)

✅ **i18n**: todas as strings novas foram adicionadas a `english.yaml` e
   regeneradas com `scripts/gen_i18n.py` — 487 chaves, 26 idiomas, herda
   fallback automático pro inglês onde a tradução ainda não existe.

✅ **Menu "Tools"**: nova entrada na Home (`src/activities/apps/ToolsActivity.*`)
   que reúne tudo isso, com toggles individuais via `CrossPetSettings`
   (portado do crosspet — `appGames`, `appFlashcard`, `appClock`, etc.)

### Como validar essa parte

```bash
cd xteink-merged
git init && git add -A && git commit -m "base + módulos simples mesclados"

# Precisa do submódulo freeink-sdk:
git submodule add <url-do-freeink-sdk> freeink-sdk  # ver .gitmodules original do crosspoint-reader

pio run                  # build
pio run --target upload  # flash (com o X4 conectado via USB-C)
```

Eu não consegui compilar de verdade aqui — meu ambiente não tem o PlatformIO
nem o toolchain RISC-V do ESP32-C3 (e não tenho acesso de rede aos servidores
da Espressif pra baixar). Tudo foi validado por **inspeção estática**: todo
`#include` referenciado por um arquivo novo existe em algum lugar do repo, e
o gerador de i18n rodou sem erros. Ainda assim, a primeira coisa a fazer no
OpenCode é rodar `pio run` e corrigir o que o compilador reclamar — é
esperado que existam pequenos ajustes (nomes de método que mudaram entre
versões do CrossPoint, etc.)

## O que falta (módulos complexos) — ver `MERGE_PLAN.md`

❌ BLE (page-turner) — do CrumBLE
❌ Dicionário StarDict — do CrumBLE
❌ Coleções + Bookshelf — do CrumBLE
❌ Otimizador de EPUB — do CrumBLE
❌ Stats + Séries + Pet virtual — do aalu
❌ Fontes CrossInk (ChareInk, Lexend Deca, Bitter)
❌ Imagens JPEG/PNG nativas — do inx

O `MERGE_PLAN.md` tem o caminho de cada arquivo-fonte, os pontos de
integração exatos, e um aviso importante: **os itens "Coleções" e "Séries"
mexem na mesma tela (Home) e precisam de uma decisão de arquitetura antes de
começar** (ver seção final do plano).

## Ordem sugerida pro OpenCode

1. Checar `partitions.csv` (tamanho de flash) antes de tudo
2. Dicionário (baixo risco)
3. Stats + Séries + Pet (prioridade alta pra você)
4. BLE (maior risco, precisa testar em hardware real)
5. Coleções (decidir arquitetura de Home junto com o item 3)
6. Fontes + Imagens (baixo risco, podem ir em paralelo)
7. Otimizador de EPUB (opcional)
