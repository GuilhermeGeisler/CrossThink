# DETAILED_STEPS.md — Roteiro completo de integração

Substitui o `MERGE_PLAN.md` anterior — esta versão é baseada em leitura real
do código-fonte de cada repositório (não só dos READMEs), incluindo duas
correções importantes descobertas nessa investigação (ver seção 0).

Módulos "simples" já portados e funcionando: ver `README_MERGE_STATUS.md`.
Este documento cobre os 7 módulos complexos restantes.

---

## 0. Duas correções em relação ao plano anterior

### 0.1 — Partição de flash: JÁ APLICADA
`partitions.csv` já foi atualizado nesta entrega, copiando a solução do
CrumBLE (reaproveitar a partição `spiffs`, não usada, pra dar 7.5MB por slot
OTA em vez de 6.25MB). Não precisa refazer esse passo.

### 0.2 — Conflito "Coleções vs Séries" na Home: RESOLVIDO, não é mais conflito
Investigação mais funda mostrou que o `CollectionsStore` do CrumBLE **já tem
agrupamento por série nativo**: cada `Collection` tem um campo
`collapseSeries` (default `true`), e o método que popula os
`ShelfEntry`/`SeriesGroup` já existe em `CollectionsStore.cpp` (função em
torno da linha 675), com um guard de segurança
(`heapTooTightForCollapse`) que desativa o agrupamento se a RAM estiver
baixa. Ou seja: **não precisamos portar `SeriesGrouping.h/.cpp` nem
`BookshelfActivity` do aalu** — o sistema do CrumBLE já é um superset. Do
aalu, só vamos portar o sistema de **Stats + Pet** (seção 5), que é
independente da Home.

Isso simplifica a ordem de execução: os itens 3 (Coleções) e 5 (Stats/Pet) do
plano anterior não competem mais pela mesma tela.

---

## 1. Dicionário (StarDict) — origem: CrumBLE

### 1.1 Arquivos a copiar (drop-in, sem modificação)
```
src/util/Dictionary.h
src/util/Dictionary.cpp
src/activities/reader/DictionaryDefinitionActivity.h/.cpp
src/activities/reader/DictionarySuggestionsActivity.h/.cpp
src/activities/reader/DictionaryWordSelectActivity.h/.cpp
src/activities/reader/DictionaryIndexBuildActivity.h/.cpp
```

### 1.2 Interface de `Dictionary` (para referência ao integrar)
Classe 100% estática, sem estado de instância exceto cache interno:
- `Dictionary::exists()` — checa se os arquivos StarDict (`.ifo/.idx/.dict`)
  estão em `/dict/` no SD
- `Dictionary::isIndexReady()` / `hasCachedIndex()` / `loadIndex(...)` /
  `loadCachedIndex()` — gate explícito de consentimento antes do scan inicial
  (~10s na primeira vez; depois fica em cache em
  `/.crosspoint/dict_idx.cache`)
- `Dictionary::lookup(word, onProgress, shouldCancel)` — retorna a definição
- `Dictionary::findSimilar(word, maxResults)` — sugestões por distância de
  Levenshtein

### 1.3 Ponto de integração no menu do leitor
Nosso `EpubReaderMenuActivity` (base) tem este enum, mais simples que o do
CrumBLE:
```cpp
enum class MenuAction {
  SELECT_CHAPTER, FOOTNOTES, GO_TO_PERCENT, AUTO_PAGE_TURN, ROTATE_SCREEN,
  BOOKMARKS, TOGGLE_BOOKMARK, SCREENSHOT, DISPLAY_QR, GO_HOME, SYNC, DELETE_CACHE
};
```
Passos:
1. Adicionar `LOOKUP` ao enum `MenuAction`
2. Adicionar `bool hasDictionary` e `bool hasLookupHistory` ao construtor de
   `EpubReaderMenuActivity` (o CrumBLE já fez exatamente isso — usar a
   assinatura dele como referência em
   `CrumBLE/src/activities/reader/EpubReaderMenuActivity.h` linha ~85)
3. Em `buildMenuItems()`, adicionar a entrada `{MenuAction::LOOKUP, StrId::STR_LOOKUP}`
   condicionada a `hasDictionary`

### 1.4 ⚠️ Ponto crítico: acoplamento com BLE (heap)
O CrumBLE documenta (com comentários extensos de "war story") que **BLE
ligado durante o Lookup derruba o firmware** — NimBLE segura ~58KB de heap, o
que impede `DictionaryWordSelectActivity::extractWords` de alocar seu vetor
de `WordInfo`, resultando em `bad_alloc` → reboot. A solução deles (copiar
quase literalmente, os números importam):

```cpp
// No handler de MenuAction::LOOKUP em EpubReaderActivity.cpp:
if (!Dictionary::exists()) {
  // mostra tela "instale o dicionário" e sai — evita rodar toda a
  // sequência de desligar BT + checar heap pra algo que vai falhar de qualquer jeito
}

auto& btMgr = BluetoothHIDManager::getInstance();
const bool bleWasOnForLookup = btMgr.isEnabled();

// Gate ANTES de desligar o BT: o próprio processo de desligar o NimBLE
// (ble_hs_stop) aloca transitoriamente ~5-10KB. Heap fragmentado abaixo
// disso -> heap_caps_free aborta com "free() target outside heap areas".
constexpr uint32_t LOOKUP_PRE_DISABLE_MIN_MAX_ALLOC = 12000;
if (bleWasOnForLookup && ESP.getMaxAllocHeap() < LOOKUP_PRE_DISABLE_MIN_MAX_ALLOC) {
  // silent-restart com uma ação pendente "abrir Lookup" pós-boot,
  // pra rodar com heap frio (~115KB) e BT já desligado
}

if (bleWasOnForLookup) btMgr.disable();

// Gate DEPOIS de desligar o BT: mesmo sem NimBLE, heap fragmentado de
// sessão longa pode não sobrar o suficiente pro WordInfo.
constexpr uint32_t LOOKUP_MIN_MAX_ALLOC = 32000;
if (ESP.getMaxAllocHeap() < LOOKUP_MIN_MAX_ALLOC) {
  // mesma lógica de silent-restart, ou alerta de "memória baixa" se
  // já tentou o restart e continua baixo
}

// ... prossegue pra DictionaryWordSelectActivity ...

// Em TODO caminho de saída do fluxo de dicionário, reagendar:
if (bleWasOnForLookup) BluetoothHIDManager::getInstance().requestEnableLater();
```

**Fonte exata para copiar:** `CrumBLE/src/activities/reader/EpubReaderActivity.cpp`,
método que trata `case EpubReaderMenuActivity::MenuAction::LOOKUP:` (por volta
da linha 2191-2400). A arquitetura de `Page`/`Section`/`RenderLock` do CrumBLE
é a mesma da nossa base (ambos descendem do crosspoint-reader oficial), então
essa parte deve colar quase sem adaptação.

### 1.5 Passo prático de teste
Depois de portar, teste **primeiro sem BLE habilitado** pra validar a lógica
de lookup isoladamente, e só depois ligue o BLE (seção 3) pra testar a
interação dos dois. Não tente integrar os dois módulos no mesmo dia de
trabalho.

---

## 2. BLE (page-turner remoto) — origem: CrumBLE

### 2.1 Arquivos a copiar
```
lib/hal/BluetoothHIDManager.h/.cpp
src/activities/settings/BluetoothSettingsActivity.h/.cpp
src/simulator/sim_stubs/BluetoothHIDManager.h   (stub p/ build de simulador desktop, opcional)
```

### 2.2 Interface chave
- `BluetoothHIDManager::getInstance()`
- `.isEnabled()` / `.disable()` / `.enable()` / `.requestEnableLater()` —
  este último é o que deve ser usado em vez de `.enable()` direto em código
  chamado a partir de dentro de outro fluxo de UI, porque `enable()` síncrono
  dentro de um handler de evento pode competir com a alocação em andamento
  daquele handler. `requestEnableLater()` deixa o religamento pro próximo
  tick do loop principal, que é o lugar seguro.

### 2.3 Pontos de integração
1. Registrar `BluetoothSettingsActivity` no menu de Settings da base
   (`src/activities/settings/SettingsActivity.cpp` — mesmo padrão de
   `menuEntries.push_back` que já usamos no `ToolsActivity`)
2. Adicionar toggle "BT Quick Connect" no `EpubReaderMenuActivity` (mesmo
   arquivo que já vamos mexer pro item 1 — fazer os dois juntos)
3. **Repetir a lógica de auto-disable/re-enable em TODO fluxo que aloca heap
   pesado**, não só no Lookup: pré-cache de EPUB, geração de thumbnail,
   parsing de capítulo grande. Buscar no CrumBLE por
   `requestEnableLater\(\)` pra listar todos os pontos onde isso é chamado —
   é mais que só o Lookup.

### 2.4 Risco e ordem de teste
Este é o módulo de maior risco do plano inteiro porque a superfície de
interação com heap é ampla (qualquer alocação grande enquanto BLE está
conectado é um crash em potencial). **Recomendo, nessa ordem:**
1. Portar só a infra de pareamento/HID (sem nenhuma integração automática de
   disable) e testar o page-turner funcionando com o device parado na Home
2. Testar abrir/fechar livros com BLE conectado, observando `ESP.getFreeHeap()`
   via serial em cada transição
3. Só então portar as chamadas de auto-disable dentro do Lookup e do
   otimizador de EPUB, testando cada uma isoladamente

---

## 3. Coleções + Bookshelf em grid — origem: CrumBLE

### 3.1 Arquivos a copiar
```
src/CollectionsStore.h/.cpp
src/activities/home/RearrangeCollectionsActivity.h/.cpp
src/activities/home/AddBooksToCollectionActivity.h/.cpp
src/activities/home/CollectionPickerActivity.h/.cpp
```

### 3.2 Decisão já tomada (ver seção 0.2)
Este sistema substitui a `HomeActivity` atual por uma visão de grid baseada
em coleções, com séries colapsadas automaticamente. **Como isso é uma mudança
grande de UI**, sugiro portar como uma segunda tela acessível a partir da Home
atual primeiro (ex: um item novo "Coleções" no menu, ao lado de "Browse
Files" e "Recents"), validar que funciona, e só depois — se você gostar do
resultado — promovê-la a tela inicial padrão (mudando o que `BootActivity`
abre por default).

### 3.3 Coleções padrão do sistema (já vêm prontas)
`Favorites`, `Recently Added`, `All Books`, `Finished`, `Unopened` — IDs e
nomes constantes em `CollectionsStore.h` (`FAVORITES_ID`, `RECENTLY_ADDED_ID`
etc.), sem precisar recriar.

### 3.4 Persistência
`SETTINGS.seriesDetectionEnabled` precisa existir em `CrossPointSettings` —
checar se a base já tem esse campo; se não, adicionar (bool, default true).
Formato do arquivo de coleções: serializado via ArduinoJson em
`CollectionsStore.cpp` (`saveToFile`/`loadFromFile` — inspecionar essas duas
funções pra saber o path exato, não documentado no README).

---

## 4. Otimizador de EPUB + pré-cache — origem: CrumBLE

### 4.1 Natureza do módulo
Ao contrário dos outros, a maior parte da lógica roda no **navegador**
(`src/network/html/js/optimizer.js`), durante o upload via WebSocket — o
device recebe um EPUB já com layout pré-calculado ("baked") em vez de ter que
indexar do zero na primeira abertura.

### 4.2 O que portar no firmware
No lado do device, é preciso que `EpubReaderActivity`/`Epub.cpp` reconheçam
quando um cache "baked" já veio junto do upload e pulem a etapa de indexação.
Buscar no CrumBLE pela função que checa a presença desse cache antes de
chamar o parser (grep por `baked` ou `precache` em `lib/Epub/Epub.cpp` do
CrumBLE).

### 4.3 Prioridade
Baixa — é otimização de performance, não uma feature nova visível. Deixar por
último, e só se sobrar espaço de flash depois dos módulos 1, 2, 3 e 5.

---

## 5. Stats + Pet Virtual — origem: aalu

### 5.1 Arquivos a copiar (em bloco — ver nota abaixo)
```
src/stats/StatsTypes.h
src/stats/ReadingStatsManager.h/.cpp
src/activities/stats/StatsActivity.h/.cpp
src/activities/stats/DetailedStatsActivity.h/.cpp
```
**Não portar** `SeriesGrouping.h/.cpp` nem `SeriesViewerActivity` nem
`BookshelfActivity` — cobertos pelo item 3 (ver seção 0.2).

### 5.2 Nota importante sobre o pet
Diferente do crosspet (que tem `PetManager`/`PetState`/`PetEvolution` como
classes separadas em `src/pet/`), no aalu **o pet não tem arquivos próprios**
— toda a lógica (evolução, sprites, renderização) está embutida dentro de
`StatsActivity.cpp`:
- Tabela de estágios: `kPetStageThresholds[]` em `StatsTypes.h` (10 estágios,
  de 300 a 30000 XP)
- Funções puras `petStageForXp()`, `petLevelForXp()` — já em `StatsTypes.h`,
  portáveis sem alteração
- Tabela de sprites `kPetVisuals[]` e método `renderPet()` — dentro de
  `StatsActivity.cpp` (linha ~604-640)

Como estamos portando o `StatsActivity.cpp` inteiro de qualquer forma (é o
mesmo arquivo que dá o heatmap, badges, "Wrapped" anual etc.), **não precisa
extrair nada** — é um bloco único. `viewMode` cicla entre 6 telas: `0=Reading,
1=Finished, 2=Badges, 3=Pet, 4=Calendar, 5=Wrapped`.

### 5.3 Campo de estado a adicionar
Único campo novo necessário em `src/CrossPointState.h`:
```cpp
uint8_t lastShownPetStage = UINT8_MAX;
```
(usado para detectar quando o pet evoluiu de estágio e mostrar a animação de
celebração)

### 5.4 Pontos de integração no leitor
Em `EpubReaderActivity.h/.cpp`, dois hooks:
```cpp
// onEnter(), depois de abrir o epub:
StatsManager.beginSession(
    epub->getCachePath().c_str(), epub->getTitle().c_str(),
    epub->getAuthor().c_str(), epub->getPath().c_str(),
    epub->getThumbBmpPath().c_str(),
    static_cast<uint8_t>(epub->progressPercent(currentSpineIndex, nextPageNumber, cachedChapterTotalPageCount)));

// onExit(), antes de Activity::onExit():
const uint8_t prog = static_cast<uint8_t>(epub->progressPercent(currentSpineIndex, currentPage, pageCount));
StatsManager.endSession(prog, sessionPagesTurned);
```
Precisa adicionar um contador `sessionPagesTurned` na classe se a base ainda
não tiver um (incrementar a cada page turn).

Em `BootActivity.cpp`, carregar a lista de livros com stats:
```cpp
const uint8_t count = StatsManager.getBookCount();
// StatsManager.getBook(i) para cada entrada
```

### 5.5 Registro no menu
Adicionar entrada no `ToolsActivity` que já criamos:
```cpp
menuEntries.push_back({StrId::STR_READING_STATS, [this] {
  activityManager.pushActivity(std::make_unique<StatsActivity>(renderer, mappedInput));
}});
```
Vai precisar adicionar `STR_READING_STATS` ao `english.yaml` e rodar
`gen_i18n.py` de novo (mesmo processo que já fizemos pros módulos simples).

### 5.6 Persistência
`STATS_FILE_PATH = "/.crosspoint/stats.bin"`, sessão mínima de 3 minutos
(`STATS_MIN_SESSION_MS`) antes de contar como leitura válida — evita contar
aberturas acidentais.

---

## 6. Fontes CrossInk (ChareInk, Lexend Deca, Bitter, Inter) — origem: CrossInk

### 6.1 Confirmação: são famílias 100% novas
Comparei os arquivos de fonte da base contra o CrossInk — **nenhuma das 4
famílias existe na base** (ChareInk, Lexend Deca, Bitter, Inter), ~50 arquivos
`.h` cada uma (8 tamanhos × 4 variantes de peso/itálico), num total de ~180
arquivos novos em `lib/EpdFont/builtinFonts/`.

### 6.2 Passos
1. Copiar os arquivos `bitter_*.h`, `charein_*.h`, `lexenddeca_*.h`,
   `inter_*.h` de `CrossInk/lib/EpdFont/builtinFonts/` pra mesma pasta na base
2. Registrar as novas famílias em `lib/EpdFont/builtinFonts/all.h` (mesmo
   arquivo que já lista as fontes existentes — seguir o padrão)
3. **Antes de compilar com tudo:** ler `CrossInk/docs/font-build-variants.md`
   — eles já resolveram o mesmo problema de espaço que vamos ter (com jogos +
   BLE + dicionário + stats + essas fontes tudo junto). O padrão deles é 3
   `[env]` no `platformio.ini` (`teensy`/`tiny`/`xlarge`), cada um incluindo
   só um subconjunto de tamanhos de fonte. Copiar essa estrutura de
   `platformio.ini` do CrossInk (seções `[env:teensy]`, `[env:tiny]`,
   `[env:xlarge]`) e adaptar os `build_flags` pro nosso conjunto de módulos.

### 6.3 Ordem
Fazer isso **cedo**, junto com a checagem de `partitions.csv` (já feita) —
sem isso, você só vai descobrir que o firmware não cabe depois de já ter
portado tudo.

---

## 7. Imagens JPEG/PNG nativas (fora do EPUB) — origem: inx

### 7.1 O que já existe na base (não confundir)
A base **já suporta** JPEG/PNG **dentro de EPUBs** via
`lib/JpegToBmpConverter/`, `lib/PngToBmpConverter/`, e
`lib/Epub/Epub/converters/{Jpeg,Png}ToFramebufferConverter.*`. Isso **não**
precisa ser portado, já funciona.

### 7.2 O que o inx adiciona de fato: `ImageRender`
Módulo novo e separado, pra renderizar JPEG/PNG **fora** do contexto de EPUB
— usado pra wallpapers de sleep screen e visualizador de imagem standalone
(equivalente ao `BmpViewerActivity` da base, mas aceitando mais formatos):
```
lib/toojpeg/toojpeg.h/.cpp          (encoder JPEG — provavelmente usado p/ screenshots)
lib/picojpeg/picojpeg.h              (decoder JPEG leve)
lib/GfxRenderer/JpegRender.h/.cpp
lib/GfxRenderer/PngRender.h/.cpp
lib/GfxRenderer/ImageRender.cpp      (unifica os dois: getDimensions() + render())
```

### 7.3 Integração
`BmpViewerActivity` da base (`src/activities/util/BmpViewerActivity.h/.cpp`)
hoje só abre `.bmp`. Ajustar pra despachar pra `ImageRender` quando a
extensão for `.jpg/.jpeg/.png`, seguindo o padrão de
`inx/lib/GfxRenderer/ImageRender.cpp` (linhas ~40-90: `getDimensions()` faz
o dispatch por extensão, depois instancia `JpegRender`/`PngRender` conforme o
caso).

### 7.4 Prioridade e risco
Baixa/baixo — módulo autocontido, não compete por heap com BLE (decodifica e
descarta, não mantém estado entre chamadas). Bom candidato pra fazer em
paralelo com as fontes (item 6) enquanto o item 2 (BLE) é testado em
hardware.

---

## Ordem de execução final (atualizada)

1. ~~Partições de flash~~ — já feito
2. **Dicionário** (item 1) — sozinho primeiro, sem BLE
3. **Stats + Pet** (item 5) — independente, pode rodar em paralelo com o item 1
4. **Fontes** (item 6) — cedo, por causa do espaço de flash
5. **Imagens** (item 7) — paralelo com o item 6, baixo risco
6. **BLE** (item 2) — sozinho primeiro (sem auto-disable), testar em hardware
7. **Reintegrar BLE + Dicionário** — juntar a lógica de auto-disable da
   seção 1.4, testar em hardware de novo
8. **Coleções** (item 3) — como tela adicional, não substituindo a Home ainda
9. **Otimizador de EPUB** (item 4) — opcional, só se sobrar espaço/tempo

## Checklist de i18n a cada módulo
Sempre que uma activity nova referenciar uma `StrId::STR_*` nova:
```bash
grep -rhoE "STR_[A-Z0-9_]+" src/<pasta-nova> | sort -u > /tmp/needed.txt
grep -oE "^STR_[A-Z0-9_]+" lib/I18n/translations/english.yaml | sort -u > /tmp/have.txt
comm -23 /tmp/needed.txt /tmp/have.txt   # o que falta adicionar
# adicionar as faltantes em english.yaml, depois:
python3 scripts/gen_i18n.py lib/I18n/translations lib/I18n/
```
(mesmo processo que já usamos pros módulos simples — funcionou bem, o script
avisa se sobrar alguma chave usada no código mas ausente do yaml)
