#!/bin/bash
# Interactive Configuration Tool Launcher

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if poetry is available
if ! command -v poetry &> /dev/null; then
    echo -e "${RED}❌ Poetry not found. Please install poetry first.${NC}"
    echo "   Visit: https://python-poetry.org/docs/#installation"
    exit 1
fi

# Change to deploy directory if needed
if [ -f "$SCRIPT_DIR/deploy/pyproject.toml" ]; then
    cd "$SCRIPT_DIR/deploy"
elif [ -f "$SCRIPT_DIR/pyproject.toml" ]; then
    cd "$SCRIPT_DIR"
else
    echo -e "${RED}❌ Cannot find deploy directory${NC}"
    exit 1
fi

# Launch interactive configuration tool
exec poetry run python configure_interactive.py
