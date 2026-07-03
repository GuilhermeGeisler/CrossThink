#!/bin/bash
#
# Script de instalação de ferramentas de desenvolvimento para CrossThink
#
# Execute este script para instalar todas as ferramentas necessárias:
#   ./scripts/install-dev-tools.sh
#

set -e

echo "=========================================="
echo "Instalando ferramentas de desenvolvimento"
echo "=========================================="
echo ""

# Verificar se é Ubuntu/Debian
if [ ! -f /etc/debian_version ]; then
  echo "⚠ Este script é para Ubuntu/Debian"
  echo "Para outros sistemas, instale manualmente:"
  echo "  - clang-format"
  echo "  - clang-tidy"
  echo "  - cppcheck"
  echo "  - python3-pip"
  echo "  - platformio"
  exit 1
fi

echo "1. Atualizando repositórios..."
sudo apt update

echo ""
echo "2. Instalando ferramentas de análise de código..."
sudo apt install -y \
  clang-format \
  clang-tidy \
  cppcheck \
  python3-pip \
  python3-venv

echo ""
echo "3. Instalando PlatformIO..."
# Instalar PlatformIO via pip (não usar apt, versão desatualizada)
python3 -m pip install --user platformio

# Adicionar ao PATH se necessário
if ! command -v pio &> /dev/null; then
  echo ""
  echo "⚠ PlatformIO instalado em ~/.local/bin"
  echo "Adicione ao seu ~/.bashrc ou ~/.zshrc:"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
  echo "Depois execute: source ~/.bashrc (ou source ~/.zshrc)"
fi

echo ""
echo "4. Verificando instalações..."
echo ""

check_tool() {
  if command -v "$1" &> /dev/null; then
    echo "✅ $1: $(command -v $1)"
    return 0
  else
    echo "❌ $1: não encontrado"
    return 1
  fi
}

check_tool clang-format
check_tool clang-tidy
check_tool cppcheck
check_tool pio || echo "  (pode estar em ~/.local/bin - adicione ao PATH)"
check_tool python3

echo ""
echo "=========================================="
echo "Instalação concluída!"
echo "=========================================="
echo ""
echo "Próximos passos:"
echo ""
echo "1. Se PlatformIO não foi encontrado, adicione ao PATH:"
echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "   source ~/.bashrc"
echo ""
echo "2. Inicialize o submódulo freeink-sdk:"
echo "   cd /home/geisler/CrossThink"
echo "   git submodule update --init --recursive"
echo ""
echo "3. Teste o build:"
echo "   pio run -e default"
echo ""
echo "4. Aplique clang-format:"
echo "   ./bin/clang-format-fix"
echo ""
echo "5. Rode análise estática:"
echo "   ./scripts/run-clang-tidy.sh"
echo ""
