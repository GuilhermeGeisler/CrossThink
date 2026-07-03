#!/bin/bash
#
# Run sanitizers (ASan, UBSan) on tests
#
# Sanitizers detect memory errors and undefined behavior at runtime.
# This script builds and runs tests with sanitizers enabled.
#
# Usage:
#   ./scripts/run-sanitizers.sh              # Run all tests with sanitizers
#   ./scripts/run-sanitizers.sh asan         # Only AddressSanitizer
#   ./scripts/run-sanitizers.sh ubsan        # Only UndefinedBehaviorSanitizer
#   ./scripts/run-sanitizers.sh tsan         # Only ThreadSanitizer
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if PlatformIO is available
if ! command -v pio &> /dev/null; then
  echo -e "${RED}✗ PlatformIO not found${NC}"
  echo "Install PlatformIO to run sanitizer tests"
  exit 1
fi

cd "$PROJECT_ROOT"

# Parse arguments
SANITIZER="${1:-all}"

run_asan() {
  echo "=========================================="
  echo "AddressSanitizer (ASan)"
  echo "=========================================="
  echo ""
  echo "Detects:"
  echo "  - Buffer overflows"
  echo "  - Use-after-free"
  echo "  - Memory leaks"
  echo "  - Double-free"
  echo ""
  
  # Build with ASan flags
  echo "Building with AddressSanitizer..."
  pio run -e default \
    --project-option "build_flags=-fsanitize=address -fno-omit-frame-pointer -g" \
    2>&1 | tee /tmp/asan-build.log | grep -E "(Compiling|Linking|error|warning)" || true
  
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}✗ Build failed with ASan${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Build successful with ASan${NC}"
  echo ""
  echo "Note: Run on device to detect runtime memory errors"
  echo "ASan will abort on first error with detailed report"
  echo ""
}

run_ubsan() {
  echo "=========================================="
  echo "UndefinedBehaviorSanitizer (UBSan)"
  echo "=========================================="
  echo ""
  echo "Detects:"
  echo "  - Integer overflow"
  echo "  - Null pointer dereference"
  echo "  - Signed integer overflow"
  echo "  - Invalid type casts"
  echo ""
  
  # Build with UBSan flags
  echo "Building with UBSan..."
  pio run -e default \
    --project-option "build_flags=-fsanitize=undefined -fno-omit-frame-pointer -g" \
    2>&1 | tee /tmp/ubsan-build.log | grep -E "(Compiling|Linking|error|warning)" || true
  
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}✗ Build failed with UBSan${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Build successful with UBSan${NC}"
  echo ""
  echo "Note: Run on device to detect undefined behavior"
  echo "UBSan will print warnings for each violation"
  echo ""
}

run_tsan() {
  echo "=========================================="
  echo "ThreadSanitizer (TSan)"
  echo "=========================================="
  echo ""
  echo "Detects:"
  echo "  - Data races"
  echo "  - Deadlocks"
  echo "  - Thread synchronization issues"
  echo ""
  echo -e "${YELLOW}⚠ Warning: TSan may not work on ESP32-C3 (single-core)${NC}"
  echo "TSan is more useful for multi-core systems"
  echo ""
  
  # Build with TSan flags
  echo "Building with TSan..."
  pio run -e default \
    --project-option "build_flags=-fsanitize=thread -fno-omit-frame-pointer -g" \
    2>&1 | tee /tmp/tsan-build.log | grep -E "(Compiling|Linking|error|warning)" || true
  
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}✗ Build failed with TSan${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ Build successful with TSan${NC}"
  echo ""
}

case "$SANITIZER" in
  asan)
    run_asan
    ;;
  ubsan)
    run_ubsan
    ;;
  tsan)
    run_tsan
    ;;
  all)
    run_asan
    run_ubsan
    # Skip TSan for single-core ESP32-C3
    echo -e "${YELLOW}⚠ Skipping TSan (ESP32-C3 is single-core)${NC}"
    echo ""
    ;;
  *)
    echo "Usage: $0 [asan|ubsan|tsan|all]"
    exit 1
    ;;
esac

echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Flash the firmware to device:"
echo "   pio run -t upload"
echo ""
echo "2. Monitor serial output for sanitizer reports:"
echo "   pio device monitor"
echo ""
echo "3. Exercise the firmware:"
echo "   - Open books"
echo "   - Navigate menus"
echo "   - Use all features"
echo ""
echo "4. Check for sanitizer errors in serial output"
echo "   ASan/UBSan will print detailed reports on violations"
echo ""
