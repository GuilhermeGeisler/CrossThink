#!/bin/bash
#
# Install git hooks for CrossThink project
#
# This script installs pre-commit hooks that automatically run:
# - clang-format (code formatting)
# - cppcheck (static analysis)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Copy pre-commit hook from project root
cp "$PROJECT_ROOT/.git/hooks/pre-commit" "$HOOKS_DIR/pre-commit" 2>/dev/null || \
  echo "Pre-commit hook already installed"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "The hook will run clang-format and cppcheck on staged C++ files before each commit."
echo ""
echo "To bypass the hook (emergency only):"
echo "  git commit --no-verify"
echo ""
echo "To uninstall:"
echo "  rm .git/hooks/pre-commit"
