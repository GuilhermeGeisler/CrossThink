#!/bin/bash
#
# Run clang-tidy static analysis on C++ files
#
# Usage:
#   ./scripts/run-clang-tidy.sh              # Check all C++ files
#   ./scripts/run-clang-tidy.sh src/file.cpp # Check specific file
#   ./scripts/run-clang-tidy.sh --fix        # Auto-fix issues
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if clang-tidy is available
if ! command -v clang-tidy &> /dev/null; then
  echo -e "${RED}✗ clang-tidy not found${NC}"
  echo ""
  echo "Install with:"
  echo "  Ubuntu/Debian: sudo apt install clang-tidy"
  echo "  macOS:         brew install llvm"
  echo "  Arch:          sudo pacman -S clang"
  exit 1
fi

# Parse arguments
FIX_FLAG=""
FILES=""

for arg in "$@"; do
  if [ "$arg" = "--fix" ]; then
    FIX_FLAG="-fix"
  else
    FILES="$FILES $arg"
  fi
done

# If no files specified, find all C++ files
if [ -z "$FILES" ]; then
  echo "Finding all C++ files..."
  FILES=$(find "$PROJECT_ROOT/src" "$PROJECT_ROOT/lib" \
    -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \
    | grep -v "/builtinFonts/" \
    | grep -v "/generated/" \
    | grep -v "/expat/" \
    | grep -v "/uzlib/" \
    || true)
fi

if [ -z "$FILES" ]; then
  echo -e "${GREEN}✓ No C++ files to check${NC}"
  exit 0
fi

FILE_COUNT=$(echo "$FILES" | wc -l)
echo "Checking $FILE_COUNT files with clang-tidy..."
echo ""

# Run clang-tidy
cd "$PROJECT_ROOT"

# Create compile_commands.json if it doesn't exist
if [ ! -f "compile_commands.json" ]; then
  echo -e "${YELLOW}⚠ compile_commands.json not found${NC}"
  echo "Generating with PlatformIO..."
  echo ""
  
  if command -v pio &> /dev/null; then
    pio run -t compiledb -e default 2>&1 | grep -E "(Compiling|Linking|error|warning)" || true
  else
    echo -e "${RED}✗ PlatformIO not found. Cannot generate compile_commands.json${NC}"
    echo "Install PlatformIO or generate manually:"
    echo "  pio run -t compiledb -e default"
    exit 1
  fi
fi

# Run clang-tidy
FAILED=false
CHECKED=0
ERRORS=0

for file in $FILES; do
  if [ ! -f "$file" ]; then
    continue
  fi
  
  CHECKED=$((CHECKED + 1))
  
  # Show progress
  printf "\rChecking: %s (%d/%d)" "$file" "$CHECKED" "$FILE_COUNT"
  
  # Run clang-tidy
  if ! clang-tidy "$file" $FIX_FLAG -p . 2>&1 | grep -v "^$" | grep -v "^Suppressed" | grep -v "^Use -header-filter"; then
    ERRORS=$((ERRORS + 1))
    FAILED=true
  fi
done

echo ""
echo ""

if [ "$FAILED" = true ]; then
  echo -e "${RED}✗ clang-tidy found issues in $ERRORS files${NC}"
  echo ""
  echo "Fix with:"
  echo "  ./scripts/run-clang-tidy.sh --fix"
  echo ""
  echo "Or fix manually and re-run."
  exit 1
else
  echo -e "${GREEN}✓ clang-tidy passed ($CHECKED files checked)${NC}"
  exit 0
fi
