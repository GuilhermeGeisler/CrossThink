#!/bin/bash
#
# Install git hooks for CrossThink project
#
# This script installs pre-commit hooks that automatically run:
# - clang-format (code formatting)
# - cppcheck (static analysis)
# - clang-tidy (deep analysis)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Copy pre-commit hook from scripts/
cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "The hook will run clang-format, cppcheck, and clang-tidy on staged C++ files."
echo ""
echo "To bypass the hook (emergency only):"
echo "  git commit --no-verify"
echo ""
echo "To uninstall:"
echo "  rm .git/hooks/pre-commit"
