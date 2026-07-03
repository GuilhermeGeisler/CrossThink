# Code Quality & Security Tools

Este documento descreve as ferramentas de verificação de código configuradas para máxima segurança no projeto CrossThink.

## Ferramentas Configuradas

### 1. clang-format (Formatação)
**Status:** ✅ Configurado e ativo

Garante formatação consistente em todo o código C++.

```bash
# Verificar formatação
./bin/clang-format-fix

# Ou manualmente
clang-format -i src/file.cpp
```

### 2. cppcheck (Análise Estática Básica)
**Status:** ✅ Configurado e ativo

Detecta bugs comuns, vazamentos de memória e problemas de performance.

```bash
# Rodar manualmente
cppcheck --enable=all --std=c++20 src/
```

### 3. clang-tidy (Análise Estática Profunda)
**Status:** ✅ Configurado e ativo

Análise profunda com foco em:
- **Memory safety** (buffer overflows, use-after-free)
- **Concurrency** (data races, deadlocks)
- **CERT C++** (security guidelines)
- **C++ Core Guidelines** (best practices)
- **Performance** (ineficiências)

```bash
# Verificar todos os arquivos
./scripts/run-clang-tidy.sh

# Verificar arquivo específico
./scripts/run-clang-tidy.sh src/file.cpp

# Auto-fix (cuidado: pode mudar código)
./scripts/run-clang-tidy.sh --fix
```

**Instalação:**
```bash
# Ubuntu/Debian
sudo apt install clang-tidy

# macOS
brew install llvm

# Arch Linux
sudo pacman -S clang
```

### 4. Sanitizers (Detecção Runtime)
**Status:** ✅ Configurado

Detectam erros em tempo de execução:

#### AddressSanitizer (ASan)
- Buffer overflows
- Use-after-free
- Memory leaks
- Double-free

#### UndefinedBehaviorSanitizer (UBSan)
- Integer overflow
- Null pointer dereference
- Invalid casts
- Signed overflow

#### ThreadSanitizer (TSan)
- Data races
- Deadlocks
- (Menos útil no ESP32-C3 single-core)

```bash
# Rodar todos os sanitizers
./scripts/run-sanitizers.sh

# Rodar apenas ASan
./scripts/run-sanitizers.sh asan

# Rodar apenas UBSan
./scripts/run-sanitizers.sh ubsan
```

**Como usar:**
1. O script compila o firmware com sanitizers habilitados
2. Flash para o device: `pio run -t upload`
3. Monitorar serial: `pio device monitor`
4. Exercitar o firmware (abrir livros, navegar menus)
5. Sanitizers reportam erros no serial output

## Git Hooks (Pre-Commit)

**Status:** ✅ Instalado

O hook pre-commit roda automaticamente antes de cada commit:

1. **clang-format** - verifica formatação
2. **cppcheck** - análise estática básica
3. **clang-tidy** - análise profunda (se instalado)

```bash
# Instalar hooks (já instalado)
./scripts/install-git-hooks.sh

# Bypass em emergência (não recomendado)
git commit --no-verify
```

## Workflow Recomendado

### Antes de cada commit:
```bash
# 1. Formatar código
./bin/clang-format-fix

# 2. Verificar com clang-tidy
./scripts/run-clang-tidy.sh

# 3. Commit (hook roda automaticamente)
git add .
git commit -m "feat: ..."
```

### Antes de cada release:
```bash
# 1. Rodar todos os sanitizers
./scripts/run-sanitizers.sh

# 2. Flash para device
pio run -t upload

# 3. Testar exaustivamente
pio device monitor

# 4. Verificar serial output para erros
```

### Análise manual profunda:
```bash
# clang-tidy com todas as verificações
./scripts/run-clang-tidy.sh

# cppcheck com todas as verificações
cppcheck --enable=all --std=c++20 --inconclusive src/

# Valgrind (se disponível no host)
valgrind --leak-check=full ./build/native/simulator
```

## Configuração do clang-tidy

Arquivo: `.clang-tidy`

**Checks habilitados:**
- `bugprone-*` - bugs comuns
- `cert-*` - CERT C++ security guidelines
- `clang-analyzer-*` - análise profunda do Clang
- `concurrency-*` - problemas de concorrência
- `cppcoreguidelines-*` - C++ Core Guidelines
- `hicpp-*` - High Integrity C++
- `misc-*` - miscellaneous
- `modernize-*` - modernização de código
- `performance-*` - problemas de performance
- `portability-*` - portabilidade
- `readability-*` - legibilidade

**Checks desabilitados:**
- `*-magic-numbers` - firmware usa muitos valores específicos
- `*-avoid-c-arrays` - ESP-IDF usa arrays C extensivamente
- `*-no-malloc` - firmware usa malloc controladamente
- `*-pro-type-reinterpret-cast` - necessário para hardware

## Interpretação de Resultados

### clang-tidy warnings

**Críticos (devem ser corrigidos):**
- `bugprone-use-after-move` - uso após move
- `bugprone-dangling-handle` - referência dangling
- `clang-analyzer-core.NullDereference` - null pointer
- `clang-analyzer-cplusplus.NewDeleteLeaks` - memory leak
- `cert-*` - violations de security guidelines

**Importantes (devem ser revisados):**
- `performance-*` - ineficiências
- `modernize-*` - código pode ser modernizado
- `readability-*` - legibilidade

**Informativos (opcionais):**
- `misc-*` - sugestões diversas

### Sanitizer errors

**AddressSanitizer:**
```
==12345==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...
READ of size 4 at 0x... thread T0
    #0 0x... in function_name file.cpp:42
```
→ Buffer overflow detectado. Verificar bounds checking.

**UndefinedBehaviorSanitizer:**
```
file.cpp:42:10: runtime error: signed integer overflow: 2147483647 + 1
```
→ Overflow de inteiro. Usar tipos maiores ou verificar antes.

## Integração com CI/CD

Para adicionar no GitHub Actions:

```yaml
# .github/workflows/code-quality.yml
name: Code Quality

on: [push, pull_request]

jobs:
  clang-tidy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install clang-tidy
        run: sudo apt install clang-tidy
      - name: Run clang-tidy
        run: ./scripts/run-clang-tidy.sh

  sanitizers:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup PlatformIO
        run: pip install platformio
      - name: Run sanitizers
        run: ./scripts/run-sanitizers.sh
```

## Recursos Adicionais

- [clang-tidy documentation](https://clang.llvm.org/extra/clang-tidy/)
- [AddressSanitizer](https://github.com/google/sanitizers/wiki/AddressSanitizer)
- [CERT C++ Coding Standard](https://wiki.sei.cmu.edu/confluence/display/cplusplus)
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/)

## Troubleshooting

### clang-tidy não encontra compile_commands.json
```bash
# Gerar com PlatformIO
pio run -t compiledb -e default
```

### Sanitizers não funcionam no ESP32-C3
Sanitizers são melhor suportados em x86/x64. No ESP32-C3, use o simulador nativo:
```bash
# Build para host com sanitizers
pio run -e simulator --project-option "build_flags=-fsanitize=address"

# Rodar
./.pio/build/simulator/program
```

### clang-tidy muito lento
```bash
# Verificar apenas arquivos modificados
git diff --name-only | grep -E '\.(cpp|h)$' | xargs ./scripts/run-clang-tidy.sh
```

### Falsos positivos
Adicionar comentários no código:
```cpp
// NOLINTNEXTLINE(clang-tidy-check-name)
problematic_code();
```

## Próximos Passos

1. ✅ Ferramentas configuradas
2. ⏳ Rodar clang-tidy em todo o código e corrigir warnings críticos
3. ⏳ Rodar sanitizers no simulador e device
4. ⏳ Integrar com CI/CD (GitHub Actions)
5. ⏳ Documentar padrões de código no CONTRIBUTING.md
