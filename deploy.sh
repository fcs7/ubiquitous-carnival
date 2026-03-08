#!/usr/bin/env bash
# Escritorio Virtual — Bootstrap de instalacao/atualizacao
# Uso: curl -fsSL https://raw.githubusercontent.com/fcs7/ubiquitous-carnival/master/deploy.sh | bash
#   ou: bash deploy.sh [--help] [--version] [--non-interactive] [--config <file>]
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/fcs7/ubiquitous-carnival/master"
SETUP_SCRIPT="scripts/setup.sh"
VERSION="1.0.0"

# Resolve diretorio do script (funciona com ./ e caminhos absolutos)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Se ja estamos dentro do repo clonado, executa local
if [[ -f "$SCRIPT_DIR/$SETUP_SCRIPT" ]]; then
    exec bash "$SCRIPT_DIR/$SETUP_SCRIPT" "$@"
fi

# Senao, baixa o setup.sh do GitHub
TMPFILE=""
cleanup() { [[ -n "$TMPFILE" && -f "$TMPFILE" ]] && rm -f "$TMPFILE"; }
trap cleanup EXIT

TMPFILE=$(mktemp /tmp/ev-setup.XXXXXX.sh)

if command -v curl &>/dev/null; then
    curl -fsSL "$REPO_RAW/$SETUP_SCRIPT" -o "$TMPFILE"
elif command -v wget &>/dev/null; then
    wget -qO "$TMPFILE" "$REPO_RAW/$SETUP_SCRIPT"
else
    echo "Erro: curl ou wget necessario para download." >&2
    exit 1
fi

chmod +x "$TMPFILE"
exec bash "$TMPFILE" "$@"
