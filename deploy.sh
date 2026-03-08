#!/usr/bin/env bash
# Escritorio Virtual — Bootstrap de instalacao/atualizacao
#
# Uso (repo publico):
#   curl -fsSL https://raw.githubusercontent.com/fcs7/ubiquitous-carnival/master/deploy.sh | sudo bash
#
# Uso (repo privado ou local):
#   git clone https://github.com/fcs7/ubiquitous-carnival.git /opt/escritorio-virtual
#   sudo bash /opt/escritorio-virtual/deploy.sh
#
# Uso (ja instalado):
#   sudo bash /opt/escritorio-virtual/deploy.sh
set -eo pipefail

REPO_GIT="https://github.com/fcs7/ubiquitous-carnival.git"
INSTALL_DIR="/opt/escritorio-virtual"
SETUP_SCRIPT="scripts/setup.sh"
VERSION="1.0.0"

# Resolve diretorio do script (seguro para curl | bash onde BASH_SOURCE nao existe)
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]:-}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Caso 1: executado de dentro do repo clonado (deploy.sh local)
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$SETUP_SCRIPT" ]]; then
    exec bash "$SCRIPT_DIR/$SETUP_SCRIPT" "$@"
fi

# Caso 2: repo ja clonado no INSTALL_DIR
if [[ -f "$INSTALL_DIR/$SETUP_SCRIPT" ]]; then
    echo "Repositorio encontrado em $INSTALL_DIR, atualizando..."
    cd "$INSTALL_DIR"
    git pull origin master 2>/dev/null || true
    exec bash "$INSTALL_DIR/$SETUP_SCRIPT" "$@"
fi

# Caso 3: primeira instalacao — clona o repo
echo "Primeira instalacao — clonando repositorio..."

# Instala git se necessario
if ! command -v git &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1
fi

if git clone --branch master "$REPO_GIT" "$INSTALL_DIR" 2>/dev/null; then
    exec bash "$INSTALL_DIR/$SETUP_SCRIPT" "$@"
else
    echo ""
    echo "Erro: nao foi possivel clonar o repositorio." >&2
    echo "" >&2
    echo "Se o repositorio e privado, clone manualmente:" >&2
    echo "  git clone $REPO_GIT $INSTALL_DIR" >&2
    echo "  sudo bash $INSTALL_DIR/deploy.sh" >&2
    echo "" >&2
    echo "Ou use SSH:" >&2
    echo "  git clone git@github.com:fcs7/ubiquitous-carnival.git $INSTALL_DIR" >&2
    echo "  sudo bash $INSTALL_DIR/deploy.sh" >&2
    exit 1
fi
