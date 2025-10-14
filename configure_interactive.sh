#!/bin/bash
# Interactive Configuration Tool Launcher for Kliver Smart Contracts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ██╗  ██╗██╗     ██╗██╗   ██╗███████╗██████╗          ║
║     ██║ ██╔╝██║     ██║██║   ██║██╔════╝██╔══██╗         ║
║     █████╔╝ ██║     ██║██║   ██║█████╗  ██████╔╝         ║
║     ██╔═██╗ ██║     ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗         ║
║     ██║  ██╗███████╗██║ ╚████╔╝ ███████╗██║  ██║         ║
║     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝         ║
║                                                           ║
║          Smart Contract Deployment Platform               ║
║            Interactive Configuration Tool                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

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

# Check if configure_interactive.py exists
if [ ! -f "configure_interactive.py" ]; then
    echo -e "${RED}❌ configure_interactive.py not found${NC}"
    exit 1
fi

# Install dependencies if needed
echo -e "${YELLOW}📦 Checking dependencies...${NC}"
poetry install --no-root --quiet

# Launch interactive configuration tool
echo -e "${GREEN}⚙️  Launching interactive configuration tool...${NC}"
echo ""

exec poetry run python configure_interactive.py
