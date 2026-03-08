#!/usr/bin/env bash
# Escritorio Virtual — Bootstrap de instalacao/atualizacao
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/fcs7/ubiquitous-carnival/master/deploy.sh | sudo bash
#   sudo bash deploy.sh
set -eo pipefail

REPO_GIT="https://github.com/fcs7/ubiquitous-carnival.git"
INSTALL_DIR="/opt/escritorio-virtual"
SETUP_SCRIPT="scripts/setup.sh"

# Resolve diretorio do script (seguro para curl | bash)
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]:-}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Caso 1: executado de dentro do repo clonado (bash deploy.sh local)
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$SETUP_SCRIPT" ]]; then
    exec bash "$SCRIPT_DIR/$SETUP_SCRIPT" "$@"
fi

# Caso 2: repo ja clonado no INSTALL_DIR
if [[ -f "$INSTALL_DIR/$SETUP_SCRIPT" ]]; then
    exec bash "$INSTALL_DIR/$SETUP_SCRIPT" "$@"
fi

# Caso 3: primeira instalacao via curl | bash
echo "Primeira instalacao — clonando repositorio..."

if ! command -v git &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1
fi

# Limpa diretorio se existe mas nao e um repo valido
if [[ -d "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
    rm -rf "$INSTALL_DIR"
fi

if git clone --branch master "$REPO_GIT" "$INSTALL_DIR"; then
    exec bash "$INSTALL_DIR/$SETUP_SCRIPT" "$@"
else
    echo "" >&2
    echo "Erro: nao foi possivel clonar o repositorio." >&2
    echo "Clone manualmente:" >&2
    echo "  git clone $REPO_GIT $INSTALL_DIR" >&2
    echo "  sudo bash $INSTALL_DIR/deploy.sh" >&2
    exit 1
fi
